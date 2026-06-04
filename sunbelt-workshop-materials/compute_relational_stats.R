compute_relational_stats <- function(event_log,
                                     stats                    = c("sender_outdegree", "receiver_indegree",
                                                                  "reciprocity", "recency"),
                                     half_life                = NULL,
                                     sort                     = TRUE,
                                     additional_previous_events = NULL,
                                     history_log              = NULL)
{
  if (!is.data.frame(event_log)) {
    stop("`event_log` must be a data.frame.")
  }
  required_cols <- c("sender", "receiver", "time")
  missing_cols <- setdiff(required_cols, names(event_log))
  if (length(missing_cols)) {
    stop("Event log is missing required column(s): ", paste(missing_cols,
                                                            collapse = ", "))
  }
  # validate additional_previous_events
  if (!is.null(additional_previous_events)) {
    if (!is.data.frame(additional_previous_events)) {
      stop("`additional_previous_events` must be a data.frame or NULL.")
    }
    ape_missing <- setdiff(c("sender", "receiver"), names(additional_previous_events))
    if (length(ape_missing)) {
      stop("`additional_previous_events` is missing required column(s): ",
           paste(ape_missing, collapse = ", "))
    }
  }
  # validate history_log
  if (!is.null(history_log)) {
    if (!is.data.frame(history_log)) {
      stop("`history_log` must be a data.frame or NULL.")
    }
    hl_missing <- setdiff(c("sender", "receiver", "time"), names(history_log))
    if (length(hl_missing)) {
      stop("`history_log` is missing required column(s): ",
           paste(hl_missing, collapse = ", "))
    }
  }
  allowed <- c("sender_outdegree", "receiver_indegree", "recency",
               "reciprocity", "reciprocity_binary", "reciprocity_count",
               "reciprocity_exp_decay", "reciprocity_time_recent",
               "reciprocity_time_first", "reciprocity_binary_interrupted",
               "reciprocity_count_interrupted", "reciprocity_exp_decay_interrupted",
               "reciprocity_time_recent_interrupted", "reciprocity_time_first_interrupted",
               "transitivity_binary", "transitivity_count", "transitivity_binary_ordered",
               "transitivity_count_ordered", "transitivity_exp_decay",
               "transitivity_exp_decay_ordered", "transitivity_time_recent",
               "transitivity_time_first", "transitivity_time_recent_ordered",
               "transitivity_time_first_ordered", "transitivity_time_recent_interrupted",
               "transitivity_time_first_interrupted", "transitivity_count_interrupted",
               "transitivity_binary_interrupted", "transitivity_exp_decay_interrupted",
               "cyclic_binary", "cyclic_count", "cyclic_time_recent",
               "cyclic_time_first", "cyclic_exp_decay", "cyclic_binary_ordered",
               "cyclic_count_ordered", "cyclic_exp_decay_ordered",
               "cyclic_time_recent_ordered", "cyclic_time_first_ordered",
               "cyclic_time_recent_interrupted", "cyclic_time_first_interrupted",
               "cyclic_count_interrupted", "cyclic_binary_interrupted",
               "cyclic_exp_decay_interrupted", "sending_balance_binary",
               "sending_balance_count", "sending_balance_time_recent",
               "sending_balance_time_first", "sending_balance_exp_decay",
               "sending_balance_binary_ordered", "sending_balance_count_ordered",
               "sending_balance_exp_decay_ordered", "sending_balance_time_recent_ordered",
               "sending_balance_time_first_ordered", "sending_balance_time_recent_interrupted",
               "sending_balance_time_first_interrupted", "sending_balance_count_interrupted",
               "sending_balance_binary_interrupted", "sending_balance_exp_decay_interrupted",
               "receiving_balance_binary", "receiving_balance_count",
               "receiving_balance_time_recent", "receiving_balance_time_first",
               "receiving_balance_exp_decay", "receiving_balance_binary_ordered",
               "receiving_balance_count_ordered", "receiving_balance_exp_decay_ordered",
               "receiving_balance_time_recent_ordered", "receiving_balance_time_first_ordered",
               "receiving_balance_time_recent_interrupted", "receiving_balance_time_first_interrupted",
               "receiving_balance_count_interrupted", "receiving_balance_binary_interrupted",
               "receiving_balance_exp_decay_interrupted",
               "out_sender")
  bad <- setdiff(stats, allowed)
  if (length(bad)) {
    stop("Unsupported statistics requested: ", paste(bad,
                                                     collapse = ", "))
  }
  if (!length(stats)) {
    stop("At least one statistic must be requested.")
  }
  exp_decay_stats <- c("reciprocity_exp_decay", "transitivity_exp_decay",
                       "transitivity_exp_decay_ordered", "reciprocity_exp_decay_interrupted",
                       "transitivity_exp_decay_interrupted", "cyclic_exp_decay",
                       "cyclic_exp_decay_ordered", "cyclic_exp_decay_interrupted",
                       "sending_balance_exp_decay", "sending_balance_exp_decay_ordered",
                       "sending_balance_exp_decay_interrupted", "receiving_balance_exp_decay",
                       "receiving_balance_exp_decay_ordered", "receiving_balance_exp_decay_interrupted")
  if (any(exp_decay_stats %in% stats) && (is.null(half_life) ||
                                          !is.numeric(half_life) || half_life <= 0)) {
    stop("`half_life` must be a positive number when ",
         "exponential-decay statistics are requested.")
  }
  log_df <- event_log
  if (sort && nrow(log_df)) {
    ord <- order(log_df$time, seq_len(nrow(log_df)))
    log_df <- log_df[ord, , drop = FALSE]
  }
  
  # Build a lookup set of history rows (sender, receiver, time) for fast membership
  # testing in do_write(). When history_log is NULL, all rows update the state
  # (original behaviour). When history_log is supplied, only rows whose
  # (sender, receiver, time) triple appears in history_log update the state.
  if (!is.null(history_log)) {
    history_keys <- paste(as.character(history_log$sender),
                          as.character(history_log$receiver),
                          as.numeric(history_log$time),
                          sep = "\r")
  } else {
    history_keys <- NULL
  }
  
  # out_sender cannot be handled by the C++ path (returns list column),
  # so fall through to the R loop whenever it is requested.
  # Also fall through when additional_previous_events or history_log is supplied.
  cpp_ok_stats <- if (exists("cpp_supported_stats", mode = "function")) {
    cpp_supported_stats()
  } else {
    character(0)
  }
  stats_for_cpp <- setdiff(stats, "out_sender")
  use_cpp <- nrow(log_df) > 0L &&
    length(stats_for_cpp) > 0L &&
    all(stats_for_cpp %in% cpp_ok_stats) &&
    is.null(additional_previous_events) &&
    is.null(history_log)
  if (use_cpp) {
    cpp_cols <- compute_features_cpp(
      as.character(log_df$sender),
      as.character(log_df$receiver),
      as.numeric(log_df$time),
      stats_for_cpp,
      if (is.null(half_life)) NA_real_ else as.numeric(half_life))
    for (st in stats_for_cpp) {
      log_df[[st]] <- cpp_cols[[st]]
    }
    if ("out_sender" %in% stats) {
      out_sender_targets <- new.env(parent = emptyenv())
      out_sender_col     <- vector("list", nrow(log_df))
      s_vec <- as.character(log_df$sender)
      r_vec <- as.character(log_df$receiver)
      # Group by time to ensure strict < t semantics
      time_groups <- split(seq_len(nrow(log_df)), log_df$time)
      for (grp in time_groups) {
        # READ phase
        for (i in grp) {
          s   <- s_vec[i]
          cur <- out_sender_targets[[s]]
          out_sender_col[[i]] <- if (is.null(cur)) character(0) else cur
        }
        # WRITE phase: all rows update state when no history_log
        for (i in grp) {
          s <- s_vec[i]
          r <- r_vec[i]
          cur <- out_sender_targets[[s]]
          if (is.null(cur) || !r %in% cur)
            out_sender_targets[[s]] <- c(cur, r)
        }
      }
      log_df[["out_sender"]] <- out_sender_col
    }
    return(log_df)
  }
  n <- nrow(log_df)
  if (!n) {
    for (stat in stats) {
      if (stat == "out_sender") {
        log_df[[stat]] <- vector("list", 0)
      } else {
        log_df[[stat]] <- numeric(0)
      }
    }
    return(log_df)
  }
  trans_names <- c("transitivity_binary", "transitivity_count",
                   "transitivity_binary_ordered", "transitivity_count_ordered",
                   "transitivity_exp_decay", "transitivity_exp_decay_ordered",
                   "transitivity_time_recent", "transitivity_time_first",
                   "transitivity_time_recent_ordered", "transitivity_time_first_ordered",
                   "transitivity_time_recent_interrupted", "transitivity_time_first_interrupted",
                   "transitivity_count_interrupted", "transitivity_binary_interrupted",
                   "transitivity_exp_decay_interrupted")
  cyc_names <- c("cyclic_binary", "cyclic_count", "cyclic_binary_ordered",
                 "cyclic_count_ordered", "cyclic_time_recent", "cyclic_time_first",
                 "cyclic_time_recent_ordered", "cyclic_time_first_ordered",
                 "cyclic_exp_decay", "cyclic_exp_decay_ordered", "cyclic_time_recent_interrupted",
                 "cyclic_time_first_interrupted", "cyclic_count_interrupted",
                 "cyclic_binary_interrupted", "cyclic_exp_decay_interrupted")
  sb_names <- c("sending_balance_binary", "sending_balance_count",
                "sending_balance_binary_ordered", "sending_balance_count_ordered",
                "sending_balance_time_recent", "sending_balance_time_first",
                "sending_balance_time_recent_ordered", "sending_balance_time_first_ordered",
                "sending_balance_exp_decay", "sending_balance_exp_decay_ordered",
                "sending_balance_time_recent_interrupted", "sending_balance_time_first_interrupted",
                "sending_balance_count_interrupted", "sending_balance_binary_interrupted",
                "sending_balance_exp_decay_interrupted")
  rb_names <- c("receiving_balance_binary", "receiving_balance_count",
                "receiving_balance_binary_ordered", "receiving_balance_count_ordered",
                "receiving_balance_time_recent", "receiving_balance_time_first",
                "receiving_balance_time_recent_ordered", "receiving_balance_time_first_ordered",
                "receiving_balance_exp_decay", "receiving_balance_exp_decay_ordered",
                "receiving_balance_time_recent_interrupted", "receiving_balance_time_first_interrupted",
                "receiving_balance_count_interrupted", "receiving_balance_binary_interrupted",
                "receiving_balance_exp_decay_interrupted")
  need_triadic    <- any(c(trans_names, cyc_names, sb_names, rb_names) %in% stats)
  need_out_sender <- "out_sender" %in% stats
  dyad_key <- function(s, r) paste0(s, "->", r)
  sender_counts   <- numeric(0)
  receiver_counts <- numeric(0)
  dyad_last_time   <- new.env(parent = emptyenv())
  dyad_first_time  <- new.env(parent = emptyenv())
  dyad_event_count <- new.env(parent = emptyenv())
  dyad_times       <- new.env(parent = emptyenv())
  interrupted_recip_stats <- c("reciprocity_count_interrupted",
                               "reciprocity_binary_interrupted", "reciprocity_exp_decay_interrupted",
                               "reciprocity_time_recent_interrupted", "reciprocity_time_first_interrupted")
  need_interrupted <- any(interrupted_recip_stats %in% stats)
  if (need_interrupted) {
    dyad_int_count <- new.env(parent = emptyenv())
    dyad_int_times <- new.env(parent = emptyenv())
    dyad_int_last  <- new.env(parent = emptyenv())
    dyad_int_first <- new.env(parent = emptyenv())
  }
  if (need_triadic || need_out_sender) {
    out_targets <- new.env(parent = emptyenv())
    in_sources  <- new.env(parent = emptyenv())
    # pre-populate from additional_previous_events (e.g. native range data)
    if (!is.null(additional_previous_events)) {
      ape_s <- as.character(additional_previous_events$sender)
      ape_r <- as.character(additional_previous_events$receiver)
      for (j in seq_along(ape_s)) {
        s_ap  <- ape_s[j]
        r_ap  <- ape_r[j]
        cur   <- out_targets[[s_ap]]
        if (is.null(cur) || !r_ap %in% cur)
          out_targets[[s_ap]] <- c(cur, r_ap)
        cur_in <- in_sources[[r_ap]]
        if (is.null(cur_in) || !s_ap %in% cur_in)
          in_sources[[r_ap]] <- c(cur_in, s_ap)
      }
    }
  }
  get_count <- function(x, key) {
    if (!length(x))
      return(0)
    val <- x[key]
    if (!length(val) || is.na(val))
      return(0)
    val
  }
  binary_set <- c("reciprocity", "reciprocity_binary", "reciprocity_binary_interrupted",
                  "transitivity_binary", "transitivity_binary_ordered",
                  "transitivity_binary_interrupted", "cyclic_binary",
                  "cyclic_binary_ordered", "cyclic_binary_interrupted",
                  "sending_balance_binary", "sending_balance_binary_ordered",
                  "sending_balance_binary_interrupted", "receiving_balance_binary",
                  "receiving_balance_binary_interrupted", "receiving_balance_binary_ordered")
  count_set <- c("sender_outdegree", "receiver_indegree",
                 "reciprocity_count", "reciprocity_exp_decay", "transitivity_count",
                 "transitivity_count_ordered", "transitivity_exp_decay",
                 "transitivity_exp_decay_ordered", "transitivity_count_interrupted",
                 "transitivity_exp_decay_interrupted", "cyclic_count",
                 "cyclic_count_ordered", "cyclic_exp_decay", "cyclic_exp_decay_ordered",
                 "cyclic_count_interrupted", "cyclic_exp_decay_interrupted",
                 "sending_balance_count", "sending_balance_count_ordered",
                 "sending_balance_exp_decay", "sending_balance_exp_decay_ordered",
                 "sending_balance_count_interrupted", "sending_balance_exp_decay_interrupted",
                 "receiving_balance_count", "receiving_balance_count_ordered",
                 "receiving_balance_exp_decay", "receiving_balance_exp_decay_ordered",
                 "receiving_balance_count_interrupted", "receiving_balance_exp_decay_interrupted",
                 "reciprocity_count_interrupted", "reciprocity_exp_decay_interrupted")
  for (stat in stats) {
    if (stat == "out_sender") {
      log_df[[stat]] <- vector("list", n)
    } else if (stat %in% binary_set) {
      log_df[[stat]] <- integer(n)
    } else if (stat %in% count_set) {
      log_df[[stat]] <- numeric(n)
    } else {
      log_df[[stat]] <- rep(NA_real_, n)
    }
  }
  compute_triadic <- function(s, r, t_now, prefix, intermediaries,
                              get_e1_times, get_e2_times, t_closure = -Inf) {
    res <- list()
    req <- stats[startsWith(stats, paste0(prefix, "_"))]
    if (!length(req))
      return(res)
    n_k  <- length(intermediaries)
    b_nm <- paste0(prefix, "_binary")
    c_nm <- paste0(prefix, "_count")
    if (b_nm %in% req) res[[b_nm]] <- as.integer(n_k > 0L)
    if (c_nm %in% req) res[[c_nm]] <- n_k
    if (n_k == 0L) {
      for (nm in req) {
        if (is.null(res[[nm]])) {
          res[[nm]] <- if (grepl("binary|count|exp", nm)) 0 else NA_real_
        }
      }
      return(res)
    }
    need_ord       <- any(grepl("ordered",                     req))
    need_exp       <- any(grepl("exp_decay",                   req))
    need_time      <- any(grepl("time_",                       req))
    need_int_time  <- any(grepl("_time_[a-z]+_interrupted$",   req))
    need_int_count <- any(grepl("_(count|binary)_interrupted$", req))
    need_int_exp   <- any(grepl("_exp_decay_interrupted$",     req))
    need_int       <- need_int_time || need_int_count || need_int_exp
    form_recent    <- -Inf
    form_first     <-  Inf
    n_ordered      <- 0L
    n_int          <- 0L
    form_ord_recent <- -Inf
    form_ord_first  <-  Inf
    exp_sum         <- 0
    exp_ord_sum     <- 0
    exp_int_sum     <- 0
    form_int_recent <- -Inf
    form_int_first  <-  Inf
    for (ki in seq_along(intermediaries)) {
      k         <- intermediaries[ki]
      e1        <- get_e1_times(k)
      e2        <- get_e2_times(k)
      formation <- max(min(e1), min(e2))
      if (need_time) {
        if (formation > form_recent) form_recent <- formation
        if (formation < form_first)  form_first  <- formation
      }
      if (need_int && formation > t_closure) {
        n_int <- n_int + 1L
        if (formation > form_int_recent) form_int_recent <- formation
        if (formation < form_int_first)  form_int_first  <- formation
        if (need_int_exp && !is.null(half_life)) {
          exp_int_sum <- exp_int_sum + exp(-(t_now - formation) * log(2) / half_life)
        }
      }
      if (need_exp && !is.null(half_life)) {
        exp_sum <- exp_sum + exp(-(t_now - formation) * log(2) / half_life)
      }
      if (need_ord) {
        valid_e2 <- e2[e2 > min(e1)]
        if (length(valid_e2)) {
          n_ordered     <- n_ordered + 1L
          formation_ord <- min(valid_e2)
          if (formation_ord > form_ord_recent) form_ord_recent <- formation_ord
          if (formation_ord < form_ord_first)  form_ord_first  <- formation_ord
          if (need_exp && !is.null(half_life)) {
            exp_ord_sum <- exp_ord_sum +
              exp(-(t_now - formation_ord) * log(2) / half_life)
          }
        }
      }
    }
    tr_nm <- paste0(prefix, "_time_recent")
    tf_nm <- paste0(prefix, "_time_first")
    if (tr_nm %in% req) res[[tr_nm]] <- t_now - form_recent
    if (tf_nm %in% req) res[[tf_nm]] <- t_now - form_first
    e_nm <- paste0(prefix, "_exp_decay")
    if (e_nm %in% req) res[[e_nm]] <- exp_sum
    bo_nm  <- paste0(prefix, "_binary_ordered")
    co_nm  <- paste0(prefix, "_count_ordered")
    tro_nm <- paste0(prefix, "_time_recent_ordered")
    tfo_nm <- paste0(prefix, "_time_first_ordered")
    eo_nm  <- paste0(prefix, "_exp_decay_ordered")
    if (bo_nm %in% req) res[[bo_nm]] <- as.integer(n_ordered > 0L)
    if (co_nm %in% req) res[[co_nm]] <- n_ordered
    if (n_ordered > 0L) {
      if (tro_nm %in% req) res[[tro_nm]] <- t_now - form_ord_recent
      if (tfo_nm %in% req) res[[tfo_nm]] <- t_now - form_ord_first
      if (eo_nm  %in% req) res[[eo_nm]]  <- exp_ord_sum
    } else {
      if (tro_nm %in% req) res[[tro_nm]] <- NA_real_
      if (tfo_nm %in% req) res[[tfo_nm]] <- NA_real_
      if (eo_nm  %in% req) res[[eo_nm]]  <- 0
    }
    tri_nm <- paste0(prefix, "_time_recent_interrupted")
    tfi_nm <- paste0(prefix, "_time_first_interrupted")
    if (tri_nm %in% req) {
      res[[tri_nm]] <- if (form_int_recent > -Inf) t_now - form_int_recent else NA_real_
    }
    if (tfi_nm %in% req) {
      res[[tfi_nm]] <- if (form_int_first < Inf) t_now - form_int_first else NA_real_
    }
    ci_nm <- paste0(prefix, "_count_interrupted")
    bi_nm <- paste0(prefix, "_binary_interrupted")
    ei_nm <- paste0(prefix, "_exp_decay_interrupted")
    if (ci_nm %in% req) res[[ci_nm]] <- n_int
    if (bi_nm %in% req) res[[bi_nm]] <- as.integer(n_int > 0L)
    if (ei_nm %in% req) res[[ei_nm]] <- exp_int_sum
    res
  }
  
  # Helper: READ phase for a single row i
  do_read <- function(i) {
    s  <- as.character(log_df$sender[i])
    r  <- as.character(log_df$receiver[i])
    ti <- log_df$time[i]
    key_sr <- dyad_key(s, r)
    key_rs <- dyad_key(r, s)
    
    if ("sender_outdegree" %in% stats)
      log_df$sender_outdegree[i] <<- get_count(sender_counts, s)
    if ("receiver_indegree" %in% stats)
      log_df$receiver_indegree[i] <<- get_count(receiver_counts, r)
    if ("recency" %in% stats) {
      lt <- dyad_last_time[[key_sr]]
      if (!is.null(lt)) log_df$recency[i] <<- ti - lt
    }
    if (need_out_sender) {
      s_out <- out_targets[[s]]
      log_df[["out_sender"]][[i]] <<- if (is.null(s_out)) character(0) else s_out
    }
    has_reverse <- !is.null(dyad_event_count[[key_rs]])
    if ("reciprocity" %in% stats)
      log_df$reciprocity[i] <<- as.integer(has_reverse)
    if ("reciprocity_binary" %in% stats)
      log_df$reciprocity_binary[i] <<- as.integer(has_reverse)
    if ("reciprocity_count" %in% stats) {
      rc <- dyad_event_count[[key_rs]]
      log_df$reciprocity_count[i] <<- if (is.null(rc)) 0 else rc
    }
    if ("reciprocity_exp_decay" %in% stats) {
      rs_t <- dyad_times[[key_rs]]
      log_df$reciprocity_exp_decay[i] <<- if (is.null(rs_t)) 0
      else sum(exp(-(ti - rs_t) * log(2) / half_life))
    }
    if ("reciprocity_time_recent" %in% stats) {
      lt_rs <- dyad_last_time[[key_rs]]
      if (!is.null(lt_rs)) log_df$reciprocity_time_recent[i] <<- ti - lt_rs
    }
    if ("reciprocity_time_first" %in% stats) {
      ft_rs <- dyad_first_time[[key_rs]]
      if (!is.null(ft_rs)) log_df$reciprocity_time_first[i] <<- ti - ft_rs
    }
    if (need_interrupted) {
      if ("reciprocity_count_interrupted" %in% stats) {
        v <- dyad_int_count[[key_sr]]
        log_df$reciprocity_count_interrupted[i] <<- if (is.null(v)) 0 else v
      }
      if ("reciprocity_binary_interrupted" %in% stats) {
        v <- dyad_int_count[[key_sr]]
        log_df$reciprocity_binary_interrupted[i] <<- if (is.null(v) || v == 0) 0L else 1L
      }
      if ("reciprocity_exp_decay_interrupted" %in% stats) {
        ts <- dyad_int_times[[key_sr]]
        log_df$reciprocity_exp_decay_interrupted[i] <<- if (is.null(ts)) 0
        else sum(exp(-(ti - ts) * log(2) / half_life))
      }
      if ("reciprocity_time_recent_interrupted" %in% stats) {
        lt <- dyad_int_last[[key_sr]]
        if (!is.null(lt)) log_df$reciprocity_time_recent_interrupted[i] <<- ti - lt
      }
      if ("reciprocity_time_first_interrupted" %in% stats) {
        ft <- dyad_int_first[[key_sr]]
        if (!is.null(ft)) log_df$reciprocity_time_first_interrupted[i] <<- ti - ft
      }
    }
    if (need_triadic) {
      s_out <- out_targets[[s]]
      if (is.null(s_out)) s_out <- character(0)
      r_out <- out_targets[[r]]
      if (is.null(r_out)) r_out <- character(0)
      s_in  <- in_sources[[s]]
      if (is.null(s_in))  s_in  <- character(0)
      r_in  <- in_sources[[r]]
      if (is.null(r_in))  r_in  <- character(0)
      last_sr   <- dyad_last_time[[key_sr]]
      t_closure <- if (is.null(last_sr)) -Inf else last_sr
      if (any(trans_names %in% stats)) {
        ks  <- setdiff(intersect(s_out, r_in), c(s, r))
        tri <- compute_triadic(s, r, ti, "transitivity", ks,
                               function(k) dyad_times[[dyad_key(s, k)]],
                               function(k) dyad_times[[dyad_key(k, r)]],
                               t_closure = t_closure)
        for (nm in names(tri)) log_df[[nm]][i] <<- tri[[nm]]
      }
      if (any(cyc_names %in% stats)) {
        ks  <- setdiff(intersect(r_out, s_in), c(s, r))
        cyc <- compute_triadic(s, r, ti, "cyclic", ks,
                               function(k) dyad_times[[dyad_key(r, k)]],
                               function(k) dyad_times[[dyad_key(k, s)]],
                               t_closure = t_closure)
        for (nm in names(cyc)) log_df[[nm]][i] <<- cyc[[nm]]
      }
      if (any(sb_names %in% stats)) {
        ks <- setdiff(intersect(s_out, r_out), c(s, r))
        sb <- compute_triadic(s, r, ti, "sending_balance", ks,
                              function(k) dyad_times[[dyad_key(s, k)]],
                              function(k) dyad_times[[dyad_key(r, k)]],
                              t_closure = t_closure)
        for (nm in names(sb)) log_df[[nm]][i] <<- sb[[nm]]
      }
      if (any(rb_names %in% stats)) {
        ks <- setdiff(intersect(s_in, r_in), c(s, r))
        rb <- compute_triadic(s, r, ti, "receiving_balance", ks,
                              function(k) dyad_times[[dyad_key(k, s)]],
                              function(k) dyad_times[[dyad_key(k, r)]],
                              t_closure = t_closure)
        for (nm in names(rb)) log_df[[nm]][i] <<- rb[[nm]]
      }
    }
  }
  
  # Helper: WRITE phase for a single row i.
  # When history_log is supplied, only rows whose (sender, receiver, time)
  # triple appears in history_log update the state; all other rows are
  # read-only (their covariates are computed but they never enter the history).
  do_write <- function(i) {
    s  <- as.character(log_df$sender[i])
    r  <- as.character(log_df$receiver[i])
    ti <- log_df$time[i]
    
    # Skip state update for non-history rows
    if (!is.null(history_keys)) {
      row_key <- paste(s, r, ti, sep = "\r")
      if (!row_key %in% history_keys) return(invisible(NULL))
    }
    
    key_sr <- dyad_key(s, r)
    key_rs <- dyad_key(r, s)
    
    sender_counts[s]   <<- get_count(sender_counts, s) + 1
    receiver_counts[r] <<- get_count(receiver_counts, r) + 1
    dyad_last_time[[key_sr]] <<- ti
    if (is.null(dyad_first_time[[key_sr]])) dyad_first_time[[key_sr]] <<- ti
    prev_c <- dyad_event_count[[key_sr]]
    dyad_event_count[[key_sr]] <<- if (is.null(prev_c)) 1L else prev_c + 1L
    dyad_times[[key_sr]] <<- c(dyad_times[[key_sr]], ti)
    if (need_interrupted) {
      dyad_int_count[[key_sr]] <<- 0L
      for (env in list(dyad_int_times, dyad_int_last, dyad_int_first)) {
        if (exists(key_sr, envir = env, inherits = FALSE))
          rm(list = key_sr, envir = env)
      }
      prev_int_c <- dyad_int_count[[key_rs]]
      dyad_int_count[[key_rs]] <<- if (is.null(prev_int_c)) 1L else prev_int_c + 1L
      dyad_int_times[[key_rs]] <<- c(dyad_int_times[[key_rs]], ti)
      dyad_int_last[[key_rs]]  <<- ti
      if (is.null(dyad_int_first[[key_rs]])) dyad_int_first[[key_rs]] <<- ti
    }
    if (need_triadic || need_out_sender) {
      cur_out <- out_targets[[s]]
      if (is.null(cur_out) || !r %in% cur_out)
        out_targets[[s]] <<- c(cur_out, r)
      cur_in <- in_sources[[r]]
      if (is.null(cur_in) || !s %in% cur_in)
        in_sources[[r]] <<- c(cur_in, s)
    }
  }
  
  # Main loop: process rows grouped by time.
  # READ all rows in a time group before WRITing any,
  # so that same-time events see state strictly before their own time (< t).
  # WRITE only touches rows that are in history_log (or all rows if
  # history_log is NULL).
  time_groups <- split(seq_len(n), log_df$time)
  for (grp in time_groups) {
    for (i in grp) do_read(i)
    for (i in grp) do_write(i)
  }
  
  log_df
}
