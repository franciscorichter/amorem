#' Standardize a relational event log
#'
#' Module A focuses on preprocessing utilities. This helper normalizes user
#' supplied event logs into the canonical `sender`/`receiver`/`time` structure
#' expected elsewhere in the package. It also handles common cleaning tasks such
#' as sorting, dropping missing rows, and removing loops.
#'
#' @param event_log A data.frame (or tibble) containing at least one row per
#'   event.
#' @param sender_col,receiver_col,time_col Column names storing the sender,
#'   receiver, and time information.
#' @param sort Logical; should the output be sorted by time (ties are kept in
#'   input order)?
#' @param drop_nas Logical; if `TRUE`, rows with missing sender/receiver/time are
#'   removed. Otherwise an error is thrown when NAs are present.
#' @param drop_loops Logical; when `TRUE`, self-loops (`sender == receiver`) are
#'   dropped.
#' @param strictly_increasing_time Logical; if `TRUE`, an error is raised when
#'   non-increasing time stamps are detected after sorting.
#' @param remove_duplicates Logical; drop duplicated combinations of
#'   sender/receiver/time.
#' @param keep_extra Logical; if `FALSE`, only the standardized columns are
#'   returned. When `TRUE`, additional columns from the original input are
#'   preserved.
#'
#' @return A data.frame with columns `sender`, `receiver`, and `time`. The return
#'   object is tagged with class `"amore_event_log"` for downstream dispatch.
#' @examples
#' data(classroom_events)
#' std <- standardize_event_log(classroom_events)
#' head(std)
#' @export
standardize_event_log <- function(
    event_log,
    sender_col = "sender",
    receiver_col = "receiver",
    time_col = "time",
    sort = TRUE,
    drop_nas = TRUE,
    drop_loops = FALSE,
    strictly_increasing_time = FALSE,
    remove_duplicates = TRUE,
    keep_extra = TRUE) {
  if (!is.data.frame(event_log)) {
    stop("`event_log` must be a data.frame.")
  }

  required <- c(sender_col, receiver_col, time_col)
  missing_cols <- setdiff(required, names(event_log))
  if (length(missing_cols)) {
    stop("Missing required column(s): ", paste(missing_cols, collapse = ", "))
  }

  out <- if (keep_extra) {
    event_log
  } else {
    event_log[, required, drop = FALSE]
  }

  col_map <- c(sender_col, receiver_col, time_col)
  target_names <- c("sender", "receiver", "time")
  for (i in seq_along(col_map)) {
    colname <- col_map[i]
    target <- target_names[i]
    if (colname %in% names(out)) {
      names(out)[names(out) == colname] <- target
    }
  }

  base_cols <- c("sender", "receiver", "time")
  out$sender <- as.character(out$sender)
  out$receiver <- as.character(out$receiver)
  out$time <- as.numeric(out$time)

  na_rows <- !stats::complete.cases(out[, base_cols])
  if (any(na_rows)) {
    if (drop_nas) {
      out <- out[!na_rows, , drop = FALSE]
    } else {
      stop("Missing values detected in sender/receiver/time columns.")
    }
  }

  if (drop_loops) {
    out <- out[out$sender != out$receiver, , drop = FALSE]
  }

  if (remove_duplicates && nrow(out)) {
    dup_mask <- duplicated(out[, base_cols])
    out <- out[!dup_mask, , drop = FALSE]
  }

  if (sort && nrow(out)) {
    ord <- order(out$time, seq_len(nrow(out)))
    out <- out[ord, , drop = FALSE]
  }

  if (strictly_increasing_time && nrow(out) > 1) {
    diffs <- diff(out$time)
    if (any(diffs <= 0)) {
      stop("Time column must be strictly increasing when `strictly_increasing_time = TRUE`.")
    }
  }

  rownames(out) <- NULL
  class(out) <- unique(c("amore_event_log", class(out)))
  out
}

#' Attach static covariates to an event log
#'
#' This helper augments an event log with sender and/or receiver covariates that
#' live in separate lookup tables. It is designed for static covariates (one row
#' per actor). Dynamic covariates should be merged manually before calling this
#' helper.
#'
#' @param event_log A standardized event log containing columns `sender` and
#'   `receiver`.
#' @param sender_covariates,receiver_covariates Data frames with one row per
#'   actor. Each must include the identifier column specified by `actor_col`.
#' @param actor_col Name of the identifier column inside the covariate tables.
#' @param sender_prefix,receiver_prefix Prefixes applied to the appended
#'   covariate column names.
#' @param allow_missing Logical; if `FALSE`, missing actors trigger an error.
#'
#' @return The input `event_log` with additional columns for each covariate table
#'   supplied.
#' @export
attach_static_covariates <- function(
    event_log,
    sender_covariates = NULL,
    receiver_covariates = NULL,
    actor_col = "actor",
    sender_prefix = "sender_",
    receiver_prefix = "receiver_",
    allow_missing = TRUE) {
  if (!is.data.frame(event_log)) {
    stop("`event_log` must be a data.frame.")
  }
  required_cols <- c("sender", "receiver")
  missing_cols <- setdiff(required_cols, names(event_log))
  if (length(missing_cols)) {
    stop("Event log is missing required column(s): ", paste(missing_cols, collapse = ", "))
  }

  out <- event_log

  append_covariates <- function(df, covariates, target_col, prefix) {
    if (is.null(covariates)) {
      return(df)
    }
    if (!is.data.frame(covariates)) {
      stop("Covariates must be provided as a data.frame.")
    }
    if (!actor_col %in% names(covariates)) {
      stop("Covariate table is missing the actor identifier column `", actor_col, "`.")
    }
    if (anyDuplicated(covariates[[actor_col]])) {
      stop("Covariate table for `", prefix, "` actors contains duplicate identifiers.")
    }

    value_cols <- setdiff(names(covariates), actor_col)
    if (!length(value_cols)) {
      stop("Covariate table for `", prefix, "` actors contains no covariate columns.")
    }

    matches <- match(df[[target_col]], covariates[[actor_col]])
    if (!allow_missing && any(is.na(matches))) {
      missing_ids <- unique(df[[target_col]][is.na(matches)])
      stop(
        "Missing covariate rows for actors: ",
        paste(missing_ids, collapse = ", ")
      )
    }

    cov_subset <- covariates[matches, value_cols, drop = FALSE]
    names(cov_subset) <- paste0(prefix, value_cols)
    df <- cbind(df, cov_subset)
    df
  }

  out <- append_covariates(out, sender_covariates, "sender", sender_prefix)
  out <- append_covariates(out, receiver_covariates, "receiver", receiver_prefix)
  out
}

# Internal: list-column giving, for each row, the set of receivers the row's
# sender has reached *before* that row. With an event mask, only masked-in
# rows update the set, so sampled non-events read the true history without
# polluting it. Processed in time groups (input assumed time-sorted) so rows
# sharing a timestamp all read the pre-t set. Backs the `sender_receivers_set`
# statistic of compute_endogenous_features().
.sender_receivers_set_col <- function(senders, receivers, times,
                                      is_event_mask = logical(0)) {
  n <- length(senders)
  out <- vector("list", n)
  if (!n) return(out)
  reached <- new.env(parent = emptyenv())
  use_mask <- length(is_event_mask) > 0L
  grp <- match(times, unique(times))
  for (g in unique(grp)) {
    idx <- which(grp == g)
    for (i in idx) {
      cur <- reached[[senders[i]]]
      out[[i]] <- if (is.null(cur)) character(0) else cur
    }
    for (i in idx) {
      if (use_mask && !isTRUE(is_event_mask[i])) next
      cur <- reached[[senders[i]]]
      if (is.null(cur) || !(receivers[i] %in% cur)) {
        reached[[senders[i]]] <- c(cur, receivers[i])
      }
    }
  }
  out
}

#' Compute endogenous event-network statistics
#'
#' Given a standardized relational event log, this helper derives historical
#' statistics for each event based on the evolving network.  The statistics
#' follow the taxonomy of Juozaitienė and Wit (2025, JRSS-A) and cover
#' reciprocity, transitivity, cyclic closure, sending balance and receiving
#' balance.  All definitions use the *continuous* convention (effects persist
#' even after a closure event).
#'
#' @param event_log A data.frame containing at least `sender`, `receiver`, and
#'   `time` columns.
#' @param stats Character vector of statistics to compute.  See **Details** for
#'   the full list of allowed values.
#' @param half_life Positive numeric; the half-life parameter \eqn{T} for
#'   exponential-decay statistics (`*_exp_decay*`).
#' @param sort Logical; when `TRUE`, events are ordered by time prior to
#'   computing summaries (ties preserve input order).
#' @param history_log Optional data.frame giving the authoritative event
#'   history (columns `sender`, `receiver`, `time`). When supplied, only rows
#'   of `event_log` whose `(sender, receiver, time)` triple appears in
#'   `history_log` update the running network state; all other rows (e.g.
#'   sampled non-events / controls) have their statistics computed against
#'   that history but never enter it. This makes it possible to evaluate
#'   endogenous statistics for non-events without those non-events polluting
#'   the history. Defaults to `NULL` (every row is treated as an event).
#'   Currently supported only for statistics handled by the C++ engine
#'   (see [cpp_supported_stats()]).
#' @param prior_log Optional data.frame of events that precede the study window
#'   (columns `sender`, `receiver`, `time`), used to **warm-start** the network
#'   state. Its rows always update the running state but never appear in the
#'   returned data.frame. This separates warm-starting from the non-event
#'   masking role of `history_log`: pass earlier history through `prior_log`
#'   and use `history_log` purely to mark which rows of `event_log` are real
#'   events. Defaults to `NULL`. Like `history_log`, it is currently supported
#'   only for statistics handled by the C++ engine (see [cpp_supported_stats()]).
#'
#' @details All statistics are evaluated immediately **before** the event is
#'   logged.  They are grouped into five families.
#'
#'   **Degree / baseline:**
#'   \describe{
#'     \item{`sender_outdegree`}{Number of events previously sent by the
#'       sender.}
#'     \item{`receiver_indegree`}{Number of events previously received by the
#'       receiver.}
#'     \item{`recency`}{Elapsed time since the last event on the same ordered
#'       pair; `NA` when the dyad is brand new.}
#'   }
#'
#'   **Reciprocity** — reverse-dyad (receiver \eqn{\to} sender) history:
#'   \describe{
#'     \item{`reciprocity` / `reciprocity_binary`}{1 if the reverse dyad has
#'       ever been observed, 0 otherwise.}
#'     \item{`reciprocity_count`}{Total count of past reverse-dyad events.}
#'     \item{`reciprocity_exp_decay`}{Exponentially weighted sum of past
#'       reverse-dyad events (requires `half_life`).}
#'     \item{`reciprocity_time_recent`}{Elapsed time since the most recent
#'       reverse-dyad event; `NA` if none.}
#'     \item{`reciprocity_time_first`}{Elapsed time since the first
#'       reverse-dyad event; `NA` if none.}
#'   }
#'
#'   **Transitivity** — two-path \eqn{s \to k \to r}:
#'   \describe{
#'     \item{`transitivity_binary`}{1 if any intermediary \eqn{k} exists with
#'       both \eqn{(s,k)} and \eqn{(k,r)} before \eqn{t}.}
#'     \item{`transitivity_count`}{Number of such intermediaries.}
#'     \item{`transitivity_binary_ordered`}{Like binary but requiring
#'       \eqn{(s,k)} to precede \eqn{(k,r)}.}
#'     \item{`transitivity_count_ordered`}{Count with order restriction.}
#'     \item{`transitivity_exp_decay`}{Exp-decay weighted sum over two-paths
#'       (requires `half_life`).}
#'     \item{`transitivity_exp_decay_ordered`}{Exp-decay with order
#'       restriction.}
#'     \item{`transitivity_time_recent`}{Time since the most recently completed
#'       two-path; `NA` if none.}
#'     \item{`transitivity_time_first`}{Time since the earliest two-path; `NA`
#'       if none.}
#'     \item{`transitivity_time_recent_ordered`}{Time since the most recent
#'       ordered two-path; `NA` if none.}
#'     \item{`transitivity_time_first_ordered`}{Time since the earliest ordered
#'       two-path; `NA` if none.}
#'   }
#'
#'   **Cyclic closure** — two-path \eqn{r \to k \to s}, closed by
#'   \eqn{s \to r}:
#'   \describe{
#'     \item{`cyclic_binary`}{1 if any cyclic two-path exists.}
#'     \item{`cyclic_count`}{Number of cyclic intermediaries.}
#'     \item{`cyclic_time_recent`}{Time since the most recent cyclic two-path
#'       formation; `NA` if none.}
#'     \item{`cyclic_time_first`}{Time since the first cyclic two-path
#'       formation; `NA` if none.}
#'   }
#'
#'   **Sending balance** — shared target: both \eqn{s \to k} and \eqn{r \to k}
#'   exist:
#'   \describe{
#'     \item{`sending_balance_binary`}{1 if any shared target exists.}
#'     \item{`sending_balance_count`}{Number of shared targets.}
#'     \item{`sending_balance_time_recent`}{Time since the most recent
#'       shared-target two-path formation; `NA` if none.}
#'     \item{`sending_balance_time_first`}{Time since the first
#'       shared-target two-path formation; `NA` if none.}
#'   }
#'
#'   **Receiving balance** — shared source: both \eqn{k \to s} and
#'   \eqn{k \to r} exist:
#'   \describe{
#'     \item{`receiving_balance_binary`}{1 if any shared source exists.}
#'     \item{`receiving_balance_count`}{Number of shared sources.}
#'     \item{`receiving_balance_time_recent`}{Time since the most recent
#'       shared-source two-path formation; `NA` if none.}
#'     \item{`receiving_balance_time_first`}{Time since the first
#'       shared-source two-path formation; `NA` if none.}
#'   }
#'
#'   The statistic `"sender_receivers_set"` is special: it adds a **list-column**
#'   in which each element is the character vector of receivers the row's sender
#'   has reached before that row (the building block for set-valued endogenous
#'   covariates, e.g. an alien species' previously invaded regions). It honours
#'   `history_log`, so it can be computed for sampled non-events without those
#'   non-events polluting the history.
#'
#' @return The event log with added columns, one per requested statistic
#'   (`sender_receivers_set` is added as a list-column).
#' @examples
#' data(classroom_events)
#' feats <- compute_endogenous_features(classroom_events,
#'                                      stats = c("reciprocity", "recency"))
#' head(feats)
#' @export
compute_endogenous_features <- function(
    event_log,
    stats = c("sender_outdegree", "receiver_indegree", "reciprocity", "recency"),
    half_life = NULL,
    sort = TRUE,
    history_log = NULL,
    prior_log = NULL) {

  if (!is.data.frame(event_log)) {
    stop("`event_log` must be a data.frame.")
  }
  required_cols <- c("sender", "receiver", "time")
  missing_cols <- setdiff(required_cols, names(event_log))
  if (length(missing_cols)) {
    stop("Event log is missing required column(s): ",
         paste(missing_cols, collapse = ", "))
  }

  # Warm-start support (issue #94). `prior_log` holds events that precede the
  # study window: they must update the running network state but never appear
  # in the output. We internalize the documented prepend-and-trim recipe ---
  # prepend the prior events, treat them (and the usual events) as history, run
  # the normal machinery, then strip the prior rows. This keeps `history_log`
  # free to do non-event masking on `event_log` alone. Restoring the original
  # event_log rows by a private row id (not by sender/receiver/time key) makes
  # the strip robust even if a prior event shares a triple with a real row.
  if (!is.null(prior_log)) {
    if (!is.data.frame(prior_log)) {
      stop("`prior_log` must be a data.frame or NULL.")
    }
    pl_missing <- setdiff(required_cols, names(prior_log))
    if (length(pl_missing)) {
      stop("`prior_log` is missing required column(s): ",
           paste(pl_missing, collapse = ", "))
    }
    eid <- ".__amore_eid__"
    event_aug <- event_log
    event_aug[[eid]] <- seq_len(nrow(event_log))
    # Prior rows aligned to event_log's columns (extra columns left NA via
    # NA-row indexing, which preserves each column's type); they carry no event
    # id so they are dropped after the computation.
    prior_aug <- event_aug[rep(NA_integer_, nrow(prior_log)), , drop = FALSE]
    prior_aug$sender   <- as.character(prior_log$sender)
    prior_aug$receiver <- as.character(prior_log$receiver)
    prior_aug$time     <- as.numeric(prior_log$time)
    prior_aug[[eid]]   <- NA_integer_
    combined <- rbind(prior_aug, event_aug)
    # Effective history: prior rows always update state; among event_log rows,
    # those that update state are the ones history_log already designates
    # (every row, when history_log is NULL).
    base_hist <- if (is.null(history_log)) event_log else history_log
    eff_hist <- rbind(
      data.frame(sender = as.character(prior_log$sender),
                 receiver = as.character(prior_log$receiver),
                 time = as.numeric(prior_log$time),
                 stringsAsFactors = FALSE),
      data.frame(sender = as.character(base_hist$sender),
                 receiver = as.character(base_hist$receiver),
                 time = as.numeric(base_hist$time),
                 stringsAsFactors = FALSE))
    res <- compute_endogenous_features(
      combined, stats = stats, half_life = half_life, sort = sort,
      history_log = eff_hist, prior_log = NULL)
    res <- res[!is.na(res[[eid]]), , drop = FALSE]
    res <- res[order(res[[eid]]), , drop = FALSE]
    res[[eid]] <- NULL
    rownames(res) <- NULL
    return(res)
  }
  # Optional authoritative event history. When supplied, only rows of
  # `event_log` whose (sender, receiver, time) triple appears in
  # `history_log` update the running state; all other rows (e.g. sampled
  # non-events / controls) have their statistics computed but never enter
  # the history. This lets the statistics for non-events be evaluated
  # against the true event history without those non-events polluting it.
  if (!is.null(history_log)) {
    if (!is.data.frame(history_log)) {
      stop("`history_log` must be a data.frame or NULL.")
    }
    hl_missing <- setdiff(required_cols, names(history_log))
    if (length(hl_missing)) {
      stop("`history_log` is missing required column(s): ",
           paste(hl_missing, collapse = ", "))
    }
  }

  allowed <- c(
    "sender_outdegree", "receiver_indegree", "recency",
    "sender_receivers_set",
    "reciprocity", "reciprocity_binary", "reciprocity_count",
    "reciprocity_exp_decay", "reciprocity_time_recent", "reciprocity_time_first",
    "reciprocity_binary_interrupted", "reciprocity_count_interrupted",
    "reciprocity_exp_decay_interrupted",
    "reciprocity_time_recent_interrupted",
    "reciprocity_time_first_interrupted",
    "transitivity_binary", "transitivity_count",
    "transitivity_binary_ordered", "transitivity_count_ordered",
    "transitivity_exp_decay", "transitivity_exp_decay_ordered",
    "transitivity_time_recent", "transitivity_time_first",
    "transitivity_time_recent_ordered", "transitivity_time_first_ordered",
    "transitivity_time_recent_interrupted",
    "transitivity_time_first_interrupted",
    "transitivity_count_interrupted", "transitivity_binary_interrupted",
    "transitivity_exp_decay_interrupted",
    "cyclic_binary", "cyclic_count", "cyclic_time_recent", "cyclic_time_first",
    "cyclic_exp_decay",
    "cyclic_binary_ordered", "cyclic_count_ordered",
    "cyclic_exp_decay_ordered",
    "cyclic_time_recent_ordered", "cyclic_time_first_ordered",
    "cyclic_time_recent_interrupted", "cyclic_time_first_interrupted",
    "cyclic_count_interrupted", "cyclic_binary_interrupted",
    "cyclic_exp_decay_interrupted",
    "sending_balance_binary", "sending_balance_count",
    "sending_balance_time_recent", "sending_balance_time_first",
    "sending_balance_exp_decay",
    "sending_balance_binary_ordered", "sending_balance_count_ordered",
    "sending_balance_exp_decay_ordered",
    "sending_balance_time_recent_ordered",
    "sending_balance_time_first_ordered",
    "sending_balance_time_recent_interrupted",
    "sending_balance_time_first_interrupted",
    "sending_balance_count_interrupted",
    "sending_balance_binary_interrupted",
    "sending_balance_exp_decay_interrupted",
    "receiving_balance_binary", "receiving_balance_count",
    "receiving_balance_time_recent", "receiving_balance_time_first",
    "receiving_balance_exp_decay",
    "receiving_balance_binary_ordered", "receiving_balance_count_ordered",
    "receiving_balance_exp_decay_ordered",
    "receiving_balance_time_recent_ordered",
    "receiving_balance_time_first_ordered",
    "receiving_balance_time_recent_interrupted",
    "receiving_balance_time_first_interrupted",
    "receiving_balance_count_interrupted",
    "receiving_balance_binary_interrupted",
    "receiving_balance_exp_decay_interrupted"
  )
  bad <- setdiff(stats, allowed)
  if (length(bad)) {
    stop("Unsupported statistics requested: ", paste(bad, collapse = ", "))
  }
  if (!length(stats)) {
    stop("At least one statistic must be requested.")
  }

  exp_decay_stats <- c("reciprocity_exp_decay", "transitivity_exp_decay",
                       "transitivity_exp_decay_ordered",
                       "reciprocity_exp_decay_interrupted",
                       "transitivity_exp_decay_interrupted",
                       "cyclic_exp_decay", "cyclic_exp_decay_ordered",
                       "cyclic_exp_decay_interrupted",
                       "sending_balance_exp_decay",
                       "sending_balance_exp_decay_ordered",
                       "sending_balance_exp_decay_interrupted",
                       "receiving_balance_exp_decay",
                       "receiving_balance_exp_decay_ordered",
                       "receiving_balance_exp_decay_interrupted")
  if (any(exp_decay_stats %in% stats) &&
      (is.null(half_life) || !is.numeric(half_life) || half_life <= 0)) {
    stop("`half_life` must be a positive number when ",
         "exponential-decay statistics are requested.")
  }

  log_df <- event_log
  if (sort && nrow(log_df)) {
    ord <- order(log_df$time, seq_len(nrow(log_df)))
    log_df <- log_df[ord, , drop = FALSE]
  }

  # Build the per-row event mask (aligned to log_df's row order). Empty when
  # no history_log is supplied, which the C++ engine reads as "all rows are
  # events" (the original, history-free behaviour).
  is_event_mask <- logical(0)
  if (!is.null(history_log)) {
    history_keys <- paste(as.character(history_log$sender),
                          as.character(history_log$receiver),
                          as.numeric(history_log$time), sep = "\r")
    row_keys <- paste(as.character(log_df$sender),
                      as.character(log_df$receiver),
                      as.numeric(log_df$time), sep = "\r")
    is_event_mask <- row_keys %in% history_keys
  }

  # G2/G3: `sender_receivers_set` is a list-column -- the set of receivers each
  # sender has reached *before* each row. It is computed separately from the
  # numeric-stat machinery and honours `history_log` (only event rows update
  # the set, so sampled non-events read the true history without polluting it).
  srs_requested <- "sender_receivers_set" %in% stats
  srs_col <- if (srs_requested) {
    .sender_receivers_set_col(as.character(log_df$sender),
                              as.character(log_df$receiver),
                              log_df$time, is_event_mask)
  } else NULL
  if (srs_requested) stats <- setdiff(stats, "sender_receivers_set")
  if (srs_requested && !length(stats)) {
    log_df[["sender_receivers_set"]] <- srs_col
    return(log_df)
  }

  # Fast path: when every requested statistic is supported by the
  # C++ inner loop, dispatch there. The C++ implementation uses
  # integer-indexed std::vector state, eliminating the env-based
  # hashmap lookups that account for ~80% of the R loop's runtime
  # on dense logs (paper/figures/benchmark_C_posthoc.csv). The C++ engine
  # honours `is_event_mask` natively, so the history-aware path is just as
  # fast as the history-free one.
  cpp_ok_stats <- cpp_supported_stats()
  if (nrow(log_df) > 0L && all(stats %in% cpp_ok_stats)) {
    # `half_life` is forwarded so the C++ path can compute the
    # exp_decay variants. It is unused (NA_real_) on the C++ side
    # when no exp_decay stat is requested.
    cpp_cols <- compute_features_cpp(
      as.character(log_df$sender),
      as.character(log_df$receiver),
      as.numeric(log_df$time),
      stats,
      is_event_mask,
      if (is.null(half_life)) NA_real_ else as.numeric(half_life))
    for (st in stats) {
      log_df[[st]] <- cpp_cols[[st]]
    }
    if (srs_requested) log_df[["sender_receivers_set"]] <- srs_col
    return(log_df)
  }

  # The pure-R fallback below does not yet honour history_log. It is only
  # reached for statistics outside the C++ engine; guard the combination
  # rather than silently ignoring the history.
  if (!is.null(history_log)) {
    stop("history_log is currently supported only for statistics handled by ",
         "the C++ engine (see cpp_supported_stats()).")
  }

  n <- nrow(log_df)
  if (!n) {
    for (stat in stats) log_df[[stat]] <- numeric(0)
    if (srs_requested) log_df[["sender_receivers_set"]] <- srs_col
    return(log_df)
  }

  # --- Determine which families are needed ---
  trans_names <- c("transitivity_binary", "transitivity_count",
                   "transitivity_binary_ordered", "transitivity_count_ordered",
                   "transitivity_exp_decay", "transitivity_exp_decay_ordered",
                   "transitivity_time_recent", "transitivity_time_first",
                   "transitivity_time_recent_ordered",
                   "transitivity_time_first_ordered",
                   "transitivity_time_recent_interrupted",
                   "transitivity_time_first_interrupted",
                   "transitivity_count_interrupted",
                   "transitivity_binary_interrupted",
                   "transitivity_exp_decay_interrupted")
  cyc_names   <- c("cyclic_binary", "cyclic_count",
                   "cyclic_binary_ordered", "cyclic_count_ordered",
                   "cyclic_time_recent", "cyclic_time_first",
                   "cyclic_time_recent_ordered", "cyclic_time_first_ordered",
                   "cyclic_exp_decay", "cyclic_exp_decay_ordered",
                   "cyclic_time_recent_interrupted",
                   "cyclic_time_first_interrupted",
                   "cyclic_count_interrupted",
                   "cyclic_binary_interrupted",
                   "cyclic_exp_decay_interrupted")
  sb_names    <- c("sending_balance_binary", "sending_balance_count",
                   "sending_balance_binary_ordered",
                   "sending_balance_count_ordered",
                   "sending_balance_time_recent", "sending_balance_time_first",
                   "sending_balance_time_recent_ordered",
                   "sending_balance_time_first_ordered",
                   "sending_balance_exp_decay",
                   "sending_balance_exp_decay_ordered",
                   "sending_balance_time_recent_interrupted",
                   "sending_balance_time_first_interrupted",
                   "sending_balance_count_interrupted",
                   "sending_balance_binary_interrupted",
                   "sending_balance_exp_decay_interrupted")
  rb_names    <- c("receiving_balance_binary", "receiving_balance_count",
                   "receiving_balance_binary_ordered",
                   "receiving_balance_count_ordered",
                   "receiving_balance_time_recent", "receiving_balance_time_first",
                   "receiving_balance_time_recent_ordered",
                   "receiving_balance_time_first_ordered",
                   "receiving_balance_exp_decay",
                   "receiving_balance_exp_decay_ordered",
                   "receiving_balance_time_recent_interrupted",
                   "receiving_balance_time_first_interrupted",
                   "receiving_balance_count_interrupted",
                   "receiving_balance_binary_interrupted",
                   "receiving_balance_exp_decay_interrupted")
  need_triadic <- any(c(trans_names, cyc_names, sb_names, rb_names) %in% stats)

  # --- Tracking data structures ---
  dyad_key <- function(s, r) paste0(s, "->", r)

  sender_counts  <- numeric(0)
  receiver_counts <- numeric(0)
  dyad_last_time  <- new.env(parent = emptyenv())
  dyad_first_time <- new.env(parent = emptyenv())
  dyad_event_count <- new.env(parent = emptyenv())
  dyad_times      <- new.env(parent = emptyenv())

  # Interrupted reciprocity tracking: each dyad (s, r) accumulates
  # information about reverse-dyad (r, s) events that occurred SINCE
  # the most recent (s, r) event. State for dyad (s, r) is reset
  # whenever event (s, r) fires.
  interrupted_recip_stats <- c("reciprocity_count_interrupted",
                                "reciprocity_binary_interrupted",
                                "reciprocity_exp_decay_interrupted",
                                "reciprocity_time_recent_interrupted",
                                "reciprocity_time_first_interrupted")
  need_interrupted <- any(interrupted_recip_stats %in% stats)
  if (need_interrupted) {
    dyad_int_count <- new.env(parent = emptyenv())
    dyad_int_times <- new.env(parent = emptyenv())  # decay summands
    dyad_int_last  <- new.env(parent = emptyenv())
    dyad_int_first <- new.env(parent = emptyenv())
  }

  if (need_triadic) {
    out_targets <- new.env(parent = emptyenv())
    in_sources  <- new.env(parent = emptyenv())
  }

  get_count <- function(x, key) {
    if (!length(x)) return(0)
    val <- x[key]
    if (!length(val) || is.na(val)) return(0)
    val
  }

  # --- Initialize output columns ---
  binary_set <- c("reciprocity", "reciprocity_binary",
                  "reciprocity_binary_interrupted",
                  "transitivity_binary", "transitivity_binary_ordered",
                  "transitivity_binary_interrupted",
                  "cyclic_binary", "cyclic_binary_ordered",
                  "cyclic_binary_interrupted",
                  "sending_balance_binary",
                  "sending_balance_binary_ordered",
                  "sending_balance_binary_interrupted",
                  "receiving_balance_binary",
                  "receiving_balance_binary_interrupted",
                  "receiving_balance_binary_ordered")
  count_set <- c("sender_outdegree", "receiver_indegree",
                 "reciprocity_count", "reciprocity_exp_decay",
                 "transitivity_count", "transitivity_count_ordered",
                 "transitivity_exp_decay", "transitivity_exp_decay_ordered",
                 "transitivity_count_interrupted",
                 "transitivity_exp_decay_interrupted",
                 "cyclic_count", "cyclic_count_ordered",
                 "cyclic_exp_decay", "cyclic_exp_decay_ordered",
                 "cyclic_count_interrupted",
                 "cyclic_exp_decay_interrupted",
                 "sending_balance_count", "sending_balance_count_ordered",
                 "sending_balance_exp_decay",
                 "sending_balance_exp_decay_ordered",
                 "sending_balance_count_interrupted",
                 "sending_balance_exp_decay_interrupted",
                 "receiving_balance_count", "receiving_balance_count_ordered",
                 "receiving_balance_exp_decay",
                 "receiving_balance_exp_decay_ordered",
                 "receiving_balance_count_interrupted",
                 "receiving_balance_exp_decay_interrupted",
                 "reciprocity_count_interrupted",
                 "reciprocity_exp_decay_interrupted")
  for (stat in stats) {
    if (stat %in% binary_set) {
      log_df[[stat]] <- integer(n)
    } else if (stat %in% count_set) {
      log_df[[stat]] <- numeric(n)
    } else {
      log_df[[stat]] <- rep(NA_real_, n)
    }
  }

  # --- Triadic helper --------------------------------------------------
  # Computes binary / count / time / exp-decay stats for a given set of
  # intermediaries whose two edges are retrieved via get_e1_times / get_e2_times.
  # `t_closure` is the time of the most recent same-direction (s, r) event,
  # or `-Inf` if no closure has occurred. Used to filter per-k formation
  # times for the *_time_*_interrupted variants.
  compute_triadic <- function(s, r, t_now, prefix, intermediaries,
                              get_e1_times, get_e2_times,
                              t_closure = -Inf) {
    res <- list()
    req <- stats[startsWith(stats, paste0(prefix, "_"))]
    if (!length(req)) return(res)

    n_k <- length(intermediaries)
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

    need_ord       <- any(grepl("ordered", req))
    need_exp       <- any(grepl("exp_decay", req))
    need_time      <- any(grepl("time_", req))
    need_int_time  <- any(grepl("_time_[a-z]+_interrupted$", req))
    need_int_count <- any(grepl("_(count|binary)_interrupted$", req))
    need_int_exp   <- any(grepl("_exp_decay_interrupted$", req))
    need_int       <- need_int_time || need_int_count || need_int_exp

    form_recent     <- -Inf
    form_first      <- Inf
    n_ordered       <- 0L
    n_int           <- 0L
    form_ord_recent <- -Inf
    form_ord_first  <- Inf
    exp_sum         <- 0
    exp_ord_sum     <- 0
    exp_int_sum     <- 0
    # Interrupted-window aggregates: only per-k formation times that
    # occurred strictly after the most recent (s, r) closure.
    form_int_recent <- -Inf
    form_int_first  <- Inf

    for (ki in seq_along(intermediaries)) {
      k  <- intermediaries[ki]
      e1 <- get_e1_times(k)
      e2 <- get_e2_times(k)

      # Per-k formation time = the time the two-path s -> k -> r first
      # exists, i.e., the time the second of its two legs is first
      # observed (paper t^(7) family; matches the simulator's
      # apply_time_writes contract). Re-firings of either leg do not
      # change the formation time.
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
          exp_int_sum <- exp_int_sum +
            exp(-(t_now - formation) * log(2) / half_life)
        }
      }
      if (need_exp && !is.null(half_life)) {
        exp_sum <- exp_sum +
          exp(-(t_now - formation) * log(2) / half_life)
      }
      if (need_ord) {
        # First leg-2 event strictly after the first leg-1 event is the
        # ordered chain's formation time. Across k, take max for
        # form_ord_recent and min for form_ord_first.
        valid_e2 <- e2[e2 > min(e1)]
        if (length(valid_e2)) {
          n_ordered <- n_ordered + 1L
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

    # Interrupted-window outputs: every formation strictly after the most
    # recent (s, r) closure event contributes a fresh "k that closed
    # since the last (s, r)". `n_int` counts such k's; the timing /
    # exp-decay aggregates above hold the per-window summaries.
    tri_nm <- paste0(prefix, "_time_recent_interrupted")
    tfi_nm <- paste0(prefix, "_time_first_interrupted")
    if (tri_nm %in% req) {
      res[[tri_nm]] <- if (form_int_recent > -Inf) t_now - form_int_recent else NA_real_
    }
    if (tfi_nm %in% req) {
      res[[tfi_nm]] <- if (form_int_first  <  Inf) t_now - form_int_first  else NA_real_
    }
    ci_nm  <- paste0(prefix, "_count_interrupted")
    bi_nm  <- paste0(prefix, "_binary_interrupted")
    ei_nm  <- paste0(prefix, "_exp_decay_interrupted")
    if (ci_nm %in% req) res[[ci_nm]] <- n_int
    if (bi_nm %in% req) res[[bi_nm]] <- as.integer(n_int > 0L)
    if (ei_nm %in% req) res[[ei_nm]] <- exp_int_sum

    res
  }

  # --- Main loop -------------------------------------------------------
  for (i in seq_len(n)) {
    s  <- as.character(log_df$sender[i])
    r  <- as.character(log_df$receiver[i])
    ti <- log_df$time[i]
    key_sr <- dyad_key(s, r)
    key_rs <- dyad_key(r, s)

    # Degree
    if ("sender_outdegree" %in% stats)
      log_df$sender_outdegree[i] <- get_count(sender_counts, s)
    if ("receiver_indegree" %in% stats)
      log_df$receiver_indegree[i] <- get_count(receiver_counts, r)

    # Recency (same-direction dyad)
    if ("recency" %in% stats) {
      lt <- dyad_last_time[[key_sr]]
      if (!is.null(lt)) log_df$recency[i] <- ti - lt
    }

    # Reciprocity family (reverse-dyad)
    has_reverse <- !is.null(dyad_event_count[[key_rs]])
    if ("reciprocity" %in% stats)
      log_df$reciprocity[i] <- as.integer(has_reverse)
    if ("reciprocity_binary" %in% stats)
      log_df$reciprocity_binary[i] <- as.integer(has_reverse)
    if ("reciprocity_count" %in% stats) {
      rc <- dyad_event_count[[key_rs]]
      log_df$reciprocity_count[i] <- if (is.null(rc)) 0 else rc
    }
    if ("reciprocity_exp_decay" %in% stats) {
      rs_t <- dyad_times[[key_rs]]
      log_df$reciprocity_exp_decay[i] <-
        if (is.null(rs_t)) 0 else sum(exp(-(ti - rs_t) * log(2) / half_life))
    }
    if ("reciprocity_time_recent" %in% stats) {
      lt_rs <- dyad_last_time[[key_rs]]
      if (!is.null(lt_rs)) log_df$reciprocity_time_recent[i] <- ti - lt_rs
    }
    if ("reciprocity_time_first" %in% stats) {
      ft_rs <- dyad_first_time[[key_rs]]
      if (!is.null(ft_rs)) log_df$reciprocity_time_first[i] <- ti - ft_rs
    }

    # Interrupted reciprocity family: each variant reads the SAME-DIRECTION
    # state slot (dyad (s, r)) — the state was populated by reverse-direction
    # events (r, s) since the most recent (s, r) event. The corresponding
    # update step below resets state[key_sr] and bumps state[key_rs].
    if (need_interrupted) {
      if ("reciprocity_count_interrupted" %in% stats) {
        v <- dyad_int_count[[key_sr]]
        log_df$reciprocity_count_interrupted[i] <- if (is.null(v)) 0 else v
      }
      if ("reciprocity_binary_interrupted" %in% stats) {
        v <- dyad_int_count[[key_sr]]
        log_df$reciprocity_binary_interrupted[i] <-
          if (is.null(v) || v == 0) 0L else 1L
      }
      if ("reciprocity_exp_decay_interrupted" %in% stats) {
        ts <- dyad_int_times[[key_sr]]
        log_df$reciprocity_exp_decay_interrupted[i] <-
          if (is.null(ts)) 0 else sum(exp(-(ti - ts) * log(2) / half_life))
      }
      if ("reciprocity_time_recent_interrupted" %in% stats) {
        lt <- dyad_int_last[[key_sr]]
        if (!is.null(lt))
          log_df$reciprocity_time_recent_interrupted[i] <- ti - lt
      }
      if ("reciprocity_time_first_interrupted" %in% stats) {
        ft <- dyad_int_first[[key_sr]]
        if (!is.null(ft))
          log_df$reciprocity_time_first_interrupted[i] <- ti - ft
      }
    }

    # Triadic statistics
    if (need_triadic) {
      s_out <- out_targets[[s]]; if (is.null(s_out)) s_out <- character(0)
      r_out <- out_targets[[r]]; if (is.null(r_out)) r_out <- character(0)
      s_in  <- in_sources[[s]];  if (is.null(s_in))  s_in  <- character(0)
      r_in  <- in_sources[[r]];  if (is.null(r_in))  r_in  <- character(0)

      # Time of the most recent same-direction (s, r) event -- the
      # closure event for every triadic family's interrupted variants.
      # `-Inf` if (s, r) has never fired before this row.
      last_sr <- dyad_last_time[[key_sr]]
      t_closure <- if (is.null(last_sr)) -Inf else last_sr

      # Transitivity: s -> k -> r
      if (any(trans_names %in% stats)) {
        ks <- setdiff(intersect(s_out, r_in), c(s, r))
        tri <- compute_triadic(s, r, ti, "transitivity", ks,
          function(k) dyad_times[[dyad_key(s, k)]],
          function(k) dyad_times[[dyad_key(k, r)]],
          t_closure = t_closure)
        for (nm in names(tri)) log_df[[nm]][i] <- tri[[nm]]
      }

      # Cyclic closure: r -> k -> s, closed by s -> r
      if (any(cyc_names %in% stats)) {
        ks <- setdiff(intersect(r_out, s_in), c(s, r))
        cyc <- compute_triadic(s, r, ti, "cyclic", ks,
          function(k) dyad_times[[dyad_key(r, k)]],
          function(k) dyad_times[[dyad_key(k, s)]],
          t_closure = t_closure)
        for (nm in names(cyc)) log_df[[nm]][i] <- cyc[[nm]]
      }

      # Sending balance: s -> k AND r -> k
      if (any(sb_names %in% stats)) {
        ks <- setdiff(intersect(s_out, r_out), c(s, r))
        sb <- compute_triadic(s, r, ti, "sending_balance", ks,
          function(k) dyad_times[[dyad_key(s, k)]],
          function(k) dyad_times[[dyad_key(r, k)]],
          t_closure = t_closure)
        for (nm in names(sb)) log_df[[nm]][i] <- sb[[nm]]
      }

      # Receiving balance: k -> s AND k -> r
      if (any(rb_names %in% stats)) {
        ks <- setdiff(intersect(s_in, r_in), c(s, r))
        rb <- compute_triadic(s, r, ti, "receiving_balance", ks,
          function(k) dyad_times[[dyad_key(k, s)]],
          function(k) dyad_times[[dyad_key(k, r)]],
          t_closure = t_closure)
        for (nm in names(rb)) log_df[[nm]][i] <- rb[[nm]]
      }
    }

    # --- Update state ---
    sender_counts[s]  <- get_count(sender_counts, s) + 1
    receiver_counts[r] <- get_count(receiver_counts, r) + 1
    dyad_last_time[[key_sr]] <- ti
    if (is.null(dyad_first_time[[key_sr]])) dyad_first_time[[key_sr]] <- ti
    prev_c <- dyad_event_count[[key_sr]]
    dyad_event_count[[key_sr]] <- if (is.null(prev_c)) 1L else prev_c + 1L
    dyad_times[[key_sr]] <- c(dyad_times[[key_sr]], ti)

    # Interrupted reciprocity: event (s, r) closes the cycle for dyad
    # (s, r) -- reset its state -- AND counts as a reverse-direction
    # event for dyad (r, s).
    if (need_interrupted) {
      dyad_int_count[[key_sr]] <- 0L
      for (env in list(dyad_int_times, dyad_int_last, dyad_int_first)) {
        if (exists(key_sr, envir = env, inherits = FALSE))
          rm(list = key_sr, envir = env)
      }
      prev_int_c <- dyad_int_count[[key_rs]]
      dyad_int_count[[key_rs]] <- if (is.null(prev_int_c)) 1L else prev_int_c + 1L
      dyad_int_times[[key_rs]] <- c(dyad_int_times[[key_rs]], ti)
      dyad_int_last[[key_rs]]  <- ti
      if (is.null(dyad_int_first[[key_rs]])) dyad_int_first[[key_rs]] <- ti
    }

    if (need_triadic) {
      cur_out <- out_targets[[s]]
      if (is.null(cur_out) || !r %in% cur_out) out_targets[[s]] <- c(cur_out, r)
      cur_in <- in_sources[[r]]
      if (is.null(cur_in) || !s %in% cur_in) in_sources[[r]] <- c(cur_in, s)
    }
  }

  if (srs_requested) log_df[["sender_receivers_set"]] <- srs_col
  log_df
}

#' Sample non-events for inference
#'
#' Given an observed event log, generate nested case-control data by sampling
#' counterfactual sender--receiver pairs according to predefined strategies.
#'
#' @param event_log Data frame with columns `sender`, `receiver`, and `time`.
#' @param n_controls Number of non-events (controls) to sample per realized
#'   event.
#' @param scope Candidate set definition. `"all"` uses every actor observed in
#'   the data; `"appearance"` restricts to actors that have appeared in prior
#'   events; `"citation"` matches citation networks where senders are restricted
#'   to the papers that debut at the current time and receivers must have
#'   appeared earlier.
#' @param mode `"one"` draws both sender and receiver from the same candidate
#'   pool (single-mode). `"two"` samples sender and receiver from separate pools
#'   (two-mode).
#' @param risk Strategy governing the risk set. `"standard"` (default) keeps all
#'   unrealized dyads available across strata, whereas `"remove"` deletes a dyad
#'   from the candidate pool after it has occurred (useful for processes such as
#'   species invasions where a pair cannot reoccur). Under `"remove"`, dyads
#'   firing at the focal event's own timestamp are also kept out of its control
#'   pool (concurrent events are not valid non-events at that instant).
#' @param exclude_pairs Optional two-column data.frame/matrix of
#'   `(sender, receiver)` pairs that are structurally ineligible as controls and
#'   must never be sampled (e.g. an alien species' native range, or any dyad
#'   forbidden in advance). Columns named `sender`/`receiver` are used if
#'   present, otherwise the first two columns.
#' @param allow_loops Logical; can sampled non-events have identical sender and
#'   receiver?
#' @param seed Optional seed for reproducibility.
#' @param max_attempts Maximum resampling attempts per control before giving up
#'   (prevents infinite loops when candidate sets are small).
#'
#' @return A data.frame containing the original events (`event = 1`) and the
#'   sampled controls (`event = 0`), grouped by `stratum` identifiers.
#' @examples
#' data(classroom_events)
#' cc <- sample_non_events(classroom_events, n_controls = 1, seed = 1)
#' head(cc)
#' @export
sample_non_events <- function(
    event_log,
    n_controls = 1,
    scope = c("all", "appearance", "citation"),
    mode = c("two", "one"),
    risk = c("standard", "remove"),
    exclude_pairs = NULL,
    allow_loops = FALSE,
    seed = NULL,
    max_attempts = 1000) {
  if (!is.data.frame(event_log)) {
    stop("`event_log` must be a data.frame.")
  }
  required_cols <- c("sender", "receiver", "time")
  missing_cols <- setdiff(required_cols, names(event_log))
  if (length(missing_cols)) {
    stop("Event log is missing required column(s): ", paste(missing_cols, collapse = ", "))
  }

  if (!is.numeric(n_controls) || length(n_controls) != 1 || n_controls < 1) {
    stop("`n_controls` must be a positive integer.")
  }
  n_controls <- as.integer(n_controls)

  scope <- match.arg(scope)
  mode <- match.arg(mode)
  risk <- match.arg(risk)

  # G1: structurally ineligible (sender, receiver) pairs that must never be
  # sampled as controls (e.g. an alien species' native range). Keys match the
  # internal `dyad_key()` format ("sender->receiver").
  exclude_pairs_env <- new.env(parent = emptyenv())
  n_exclude_pairs <- 0L
  if (!is.null(exclude_pairs)) {
    if (is.matrix(exclude_pairs)) {
      exclude_pairs <- as.data.frame(exclude_pairs, stringsAsFactors = FALSE)
    }
    if (!is.data.frame(exclude_pairs) || ncol(exclude_pairs) < 2) {
      stop("`exclude_pairs` must be a two-column data.frame/matrix of ",
           "(sender, receiver) pairs.")
    }
    if (all(c("sender", "receiver") %in% names(exclude_pairs))) {
      es <- as.character(exclude_pairs$sender)
      er <- as.character(exclude_pairs$receiver)
    } else {
      es <- as.character(exclude_pairs[[1]])
      er <- as.character(exclude_pairs[[2]])
    }
    for (k in paste0(es, "->", er)) exclude_pairs_env[[k]] <- TRUE
    n_exclude_pairs <- length(es)
  }

  if (!is.null(seed)) {
    old_seed <- get0(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    on.exit({
      if (is.null(old_seed)) {
        if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
          rm(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
        }
      } else {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      }
    })
    set.seed(seed)
  }

  n_events <- nrow(event_log)
  if (n_events == 0) {
    stop("Event log contains no rows.")
  }

  sender_all <- unique(as.character(event_log$sender))
  receiver_all <- unique(as.character(event_log$receiver))
  combined_all <- sort(unique(c(sender_all, receiver_all)))

  sender_first_time <- tapply(event_log$time, event_log$sender, min)

  get_citation_senders <- function(time_val) {
    if (!length(sender_first_time)) {
      return(character(0))
    }
    tol <- if (is.finite(time_val)) sqrt(.Machine$double.eps) else 0
    matches <- abs(sender_first_time - time_val) < tol
    names(sender_first_time)[matches]
  }

  get_citation_receivers <- function(time_val) {
    if (!length(sender_first_time)) {
      return(character(0))
    }
    names(sender_first_time)[sender_first_time < time_val]
  }

  appearance_senders <- character(0)
  appearance_receivers <- character(0)
  appearance_combined <- character(0)

  get_candidates <- function(use_scope, time_val, current_sender, current_receiver) {
    if (use_scope == "all") {
      return(list(
        senders = sender_all,
        receivers = receiver_all,
        combined = combined_all
      ))
    }

    if (use_scope == "appearance") {
      senders <- if (length(appearance_senders)) appearance_senders else sender_all
      receivers <- if (length(appearance_receivers)) appearance_receivers else receiver_all
      combined <- if (length(appearance_combined)) appearance_combined else combined_all
      return(list(senders = senders, receivers = receivers, combined = combined))
    }

    senders <- get_citation_senders(time_val)
    if (!length(senders)) {
      senders <- character(0)
    }
    if (!current_sender %in% senders) {
      senders <- unique(c(senders, current_sender))
    }

    receivers <- get_citation_receivers(time_val)
    if (!length(receivers)) {
      receivers <- character(0)
    }
    if (!current_receiver %in% receivers) {
      receivers <- unique(c(receivers, current_receiver))
    }

    combined <- unique(c(senders, receivers))
    list(senders = senders, receivers = receivers, combined = combined)
  }

  dyad_key <- function(s, r) paste0(s, "->", r)

  removed_dyads <- new.env(parent = emptyenv())

  choose_pair <- function(cands, mode_choice) {
    if (mode_choice == "one") {
      needed <- if (allow_loops) 1L else 2L
      if (length(cands$combined) < needed && scope != "citation") {
        cands$combined <- combined_all
      }
      pair <- sample(cands$combined, size = 2, replace = allow_loops)
      list(sender = pair[1], receiver = pair[2])
    } else {
      if ((!length(cands$senders) || !length(cands$receivers)) && scope != "citation") {
        cands$senders <- sender_all
        cands$receivers <- receiver_all
      }
      s <- sample(cands$senders, size = 1)
      r <- sample(cands$receivers, size = 1)
      list(sender = s, receiver = r)
    }
  }

  has_viable_pair <- function(cands, mode_choice, current_sender, current_receiver) {
    check_pair <- function(s, r) {
      if (!allow_loops && identical(s, r)) {
        return(FALSE)
      }
      if (is.na(s) || is.na(r)) {
        return(FALSE)
      }
      if (identical(s, current_sender) && identical(r, current_receiver)) {
        return(FALSE)
      }
      if (risk == "remove" && !is.null(removed_dyads[[dyad_key(s, r)]])) {
        return(FALSE)
      }
      TRUE
    }

    if (mode_choice == "one") {
      combos <- cands$combined
      if (!length(combos)) {
        return(FALSE)
      }
      if (allow_loops) {
        for (s in combos) {
          for (r in combos) {
            if (check_pair(s, r)) return(TRUE)
          }
        }
        return(FALSE)
      }
      if (length(combos) < 2) {
        return(FALSE)
      }
      for (i in seq_along(combos)) {
        for (j in seq_along(combos)) {
          if (i == j) next
          if (check_pair(combos[i], combos[j])) return(TRUE)
        }
      }
      return(FALSE)
    }

    if (!length(cands$senders) || !length(cands$receivers)) {
      return(FALSE)
    }
    for (s in cands$senders) {
      for (r in cands$receivers) {
        if (check_pair(s, r)) return(TRUE)
      }
    }
    FALSE
  }

  extra_cols <- setdiff(names(event_log), required_cols)

  events_df <- event_log
  events_df$stratum <- seq_len(n_events)
  events_df$event <- 1L
  events_df <- events_df[, c("stratum", "event", required_cols, extra_cols), drop = FALSE]

  total_controls <- n_events * n_controls
  control_df <- data.frame(
    stratum = integer(total_controls),
    event = integer(total_controls),
    sender = character(total_controls),
    receiver = character(total_controls),
    time = numeric(total_controls),
    stringsAsFactors = FALSE
  )
  if (length(extra_cols)) {
    for (col in extra_cols) {
      control_df[[col]] <- NA
    }
  }

  # G1b: under risk = "remove", a dyad firing at the focal event's own time is
  # a concurrent event, not a valid non-event at that instant. Precompute, per
  # event, the set of event-dyad keys firing at the same time (grouped by exact
  # time so float formatting is irrelevant).
  if (risk == "remove" && n_events > 0L) {
    .ev_keys <- dyad_key(events_df$sender, events_df$receiver)
    .tg <- match(events_df$time, unique(events_df$time))
    concurrent_keys <- unname(split(.ev_keys, .tg)[as.character(.tg)])
  } else {
    concurrent_keys <- vector("list", n_events)
  }

  ctrl_index <- 0L

  for (i in seq_len(n_events)) {
    cand_sets <- get_candidates(scope, events_df$time[i], events_df$sender[i], events_df$receiver[i])
    viable <- has_viable_pair(cand_sets, mode, events_df$sender[i], events_df$receiver[i])
    concurrent_keys_i <- concurrent_keys[[i]]

    if (viable) {
      for (j in seq_len(n_controls)) {
        attempts <- 0L
        repeat {
          attempts <- attempts + 1L
          if (attempts > max_attempts) {
            stop("Unable to sample a valid non-event after ", max_attempts, " attempts.")
          }

          sampled <- choose_pair(cand_sets, mode)
          if (!allow_loops && sampled$sender == sampled$receiver) {
            next
          }
          if (sampled$sender == events_df$sender[i] && sampled$receiver == events_df$receiver[i]) {
            next
          }
          cand_key <- dyad_key(sampled$sender, sampled$receiver)
          if (n_exclude_pairs && !is.null(exclude_pairs_env[[cand_key]])) {
            next                                   # G1: structural exclusion
          }
          if (risk == "remove") {
            if (!is.null(removed_dyads[[cand_key]])) {
              next                                 # historical: already fired
            }
            if (cand_key %in% concurrent_keys_i) {
              next                                 # G1b: concurrent event
            }
          }
          break
        }

        ctrl_index <- ctrl_index + 1L
        control_df$stratum[ctrl_index] <- events_df$stratum[i]
        control_df$event[ctrl_index] <- 0L
        control_df$sender[ctrl_index] <- sampled$sender
        control_df$receiver[ctrl_index] <- sampled$receiver
        control_df$time[ctrl_index] <- events_df$time[i]
      }
    }

    appearance_senders <- union(appearance_senders, events_df$sender[i])
    appearance_receivers <- union(appearance_receivers, events_df$receiver[i])
    appearance_combined <- union(appearance_combined, c(events_df$sender[i], events_df$receiver[i]))

    if (risk == "remove") {
      removed_dyads[[dyad_key(events_df$sender[i], events_df$receiver[i])]] <- TRUE
    }
  }

  if (ctrl_index < total_controls) {
    control_df <- control_df[seq_len(ctrl_index), , drop = FALSE]
  }

  out <- rbind(events_df, control_df)
  out <- out[order(out$stratum, -out$event), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Endogenous statistics with a compiled fast path
#'
#' Returns the names of the endogenous statistics that
#' [compute_endogenous_features()] evaluates with the compiled C++ engine.
#' Statistics outside this set are computed by the (slower) pure-R fallback.
#'
#' @return A character vector of statistic names.
#' @seealso [compute_endogenous_features()]
#' @examples
#' length(cpp_supported_stats())
#' head(cpp_supported_stats())
#' @export
#' @name cpp_supported_stats
NULL
