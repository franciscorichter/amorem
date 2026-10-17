# Profiles for the data catalogue. A reader returns a standard object; profile()
# turns it into aggregates only (counts, distributions, rates, a small REM fit),
# which are what the site publishes. Raw rows never leave data-raw/raw/.
#
# Standard object (from a reader in readers.R):
#   list(kind = "dyadic" | "hyper" | "series",
#        directed = TRUE/FALSE,
#        events = data.frame(sender, receiver, time)      # dyadic
#                 or data.frame(time) + list columns I, J  # hyper
#                 or data.frame(time, <value columns>)    # series
#        time_unit = "seconds" | "days" | "years" | ...,
#        origin = POSIXct of time 0, or NULL when time is not clock time,
#        tz = time zone of the clock (for daily/weekly cycles),
#        note = character)

suppressPackageStartupMessages(library(data.table))

.ccdf <- function(x, n = 60) {
  x <- x[is.finite(x) & x > 0]
  if (!length(x)) return(data.frame(x = numeric(0), p = numeric(0)))
  grid <- unique(signif(exp(seq(log(min(x)), log(max(x)), length.out = n)), 4))
  ex <- ecdf(x)
  data.frame(x = grid, p = 1 - ex(grid) + mean(x == max(x)) * (grid >= max(x)))
}

.gini <- function(x) {
  x <- sort(x); n <- length(x)
  if (n < 2 || sum(x) == 0) return(NA_real_)
  sum((2 * seq_len(n) - n - 1) * x) / (n * sum(x))
}

.burstiness <- function(dt) {
  dt <- dt[is.finite(dt)]
  if (length(dt) < 3) return(NA_real_)
  m <- mean(dt); s <- stats::sd(dt)
  (s - m) / (s + m)
}

profile_dyadic <- function(obj, fit_n = 4000, seed = 1) {
  e <- as.data.table(obj$events)[, .(sender = as.character(sender),
                                      receiver = as.character(receiver),
                                      time = as.numeric(time))]
  e <- e[!is.na(time) & sender != receiver]
  setorder(e, time)
  n <- nrow(e)
  key <- if (obj$directed) paste(e$sender, e$receiver, sep = "\r")
         else paste(pmin(e$sender, e$receiver), pmax(e$sender, e$receiver), sep = "\r")
  first_dyad <- e[, .(t0 = min(time)), by = .(k = key)]
  rep_share <- mean(duplicated(key))
  A <- length(unique(c(e$sender, e$receiver)))
  D <- if (obj$directed) A * (A - 1) else A * (A - 1) / 2
  rep_random <- max(0, 1 - D * (1 - (1 - 1 / D)^n) / n)   # share of repeats if every event picked a dyad at random
  recip_share <- NA_real_
  if (obj$directed) {
    rk <- paste(e$receiver, e$sender, sep = "\r")
    t_rev <- first_dyad$t0[match(rk, first_dyad$k)]
    recip_share <- mean(!is.na(t_rev) & t_rev < e$time)
  }
  actors <- unique(c(e$sender, e$receiver))
  act <- table(factor(c(e$sender, e$receiver), levels = actors))
  partners <- e[, .(a = c(sender, receiver), b = c(receiver, sender))][, .(deg = uniqueN(b)), by = a]
  # gaps between successive events of the same pair (inter-contact times)
  ord <- order(key, e$time)
  ks <- key[ord]; ts <- e$time[ord]
  dt <- diff(ts)[ks[-1] == ks[-length(ks)]]
  dt <- dt[dt > 0]
  bins <- max(10, min(200, length(unique(e$time))))
  br <- seq(min(e$time), max(e$time), length.out = bins + 1)
  rate <- data.frame(t = head(br, -1) + diff(br) / 2,
                     n = as.integer(table(cut(e$time, br, include.lowest = TRUE))))
  cyc <- NULL
  if (!is.null(obj$origin)) {
    sec <- switch(obj$time_unit, seconds = 1, minutes = 60, hours = 3600, days = 86400, NA)
    # clock cycles only when times resolve the time of day
    if (!is.na(sec) && mean((e$time * sec) %% 86400 == 0) < 0.5) {
      clock <- as.POSIXlt(obj$origin + e$time * sec, tz = obj$tz %||% "UTC")
      cyc <- list(hour = as.integer(table(factor(clock$hour, levels = 0:23))),
                  wday = as.integer(table(factor((clock$wday + 6) %% 7, levels = 0:6))))
    }
  }
  fit <- tryCatch(.profile_fit(e, obj$directed, fit_n, seed), error = function(err) conditionMessage(err))
  list(kind = "dyadic", directed = obj$directed, time_unit = obj$time_unit,
       origin = obj$origin, tz = obj$tz, note = obj$note,
       stats = c(events = n, actors = length(actors), dyads = nrow(first_dyad),
                 span = diff(range(e$time)), repetition = rep_share, repetition_random = rep_random,
                 reciprocity = recip_share, burstiness = .burstiness(dt),
                 gini_activity = .gini(as.numeric(act)),
                 top10_share = sum(sort(as.numeric(act), decreasing = TRUE)[seq_len(ceiling(length(act) / 10))]) / sum(act),
                 tied_time_share = mean(duplicated(e$time))),
       rate = rate, iet_ccdf = .ccdf(dt), degree_ccdf = .ccdf(partners$deg),
       activity_ccdf = .ccdf(as.numeric(act)), cycle = cyc, fit = fit)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# A small REM on the first fit_n events of a directed log: log counts of the
# sender's past activity, the receiver's past popularity and past reciprocating
# events, one control per event, default case-control history. Undirected logs
# get no fit (node-level counts depend on an arbitrary order of the pair).
.profile_fit <- function(e, directed, fit_n, seed) {
  if (!directed) return(NULL)
  ev <- as.data.frame(e[seq_len(min(nrow(e), fit_n))])
  cc <- amorem::sample_non_events(ev, n_controls = 1, seed = seed)
  st <- c("sender_outdegree", "receiver_indegree", "reciprocity_count")
  f <- amorem::endogenous_features(cc, stats = st)
  for (s in st) { v <- f[[s]]; v[is.na(v)] <- 0; f[[s]] <- log1p(v) }
  fit <- amorem::rem(event ~ sender_outdegree + receiver_indegree + reciprocity_count,
                     data = f, method = "clogit", stratum = "stratum")
  sm <- summary(fit$fit)$coefficients
  data.frame(term = rownames(sm), estimate = sm[, "coef"], se = sm[, "se(coef)"],
             n_events = nrow(ev), row.names = NULL)
}

profile_hyper <- function(obj) {
  e <- obj$events
  e <- e[order(e$time), ]
  sI <- lengths(e$I); sJ <- if (!is.null(e$J)) lengths(e$J) else integer(nrow(e))
  key <- paste(vapply(e$I, function(x) paste(sort(x), collapse = ","), ""),
               if (!is.null(e$J)) vapply(e$J, function(x) paste(sort(x), collapse = ","), "") else "",
               sep = "|")
  actors <- unique(c(unlist(e$I), unlist(e$J)))
  dt <- diff(as.numeric(e$time)); dt <- dt[dt > 0]
  bins <- max(10, min(200, length(unique(e$time))))
  br <- seq(min(e$time), max(e$time), length.out = bins + 1)
  list(kind = "hyper", directed = !is.null(e$J) && any(sJ > 0), time_unit = obj$time_unit,
       origin = obj$origin, note = obj$note,
       stats = c(events = nrow(e), actors = length(actors), span = diff(range(e$time)),
                 mean_I = mean(sI), max_I = max(sI), mean_J = mean(sJ), max_J = max(sJ),
                 exact_repetition = mean(duplicated(key)), burstiness = .burstiness(dt)),
       size_I = as.data.frame(table(size = sI)), size_J = as.data.frame(table(size = sJ)),
       rate = data.frame(t = head(br, -1) + diff(br) / 2,
                         n = as.integer(table(cut(e$time, br, include.lowest = TRUE)))),
       iet_ccdf = .ccdf(dt))
}

profile_series <- function(obj) {
  d <- as.data.frame(obj$events)
  vals <- setdiff(names(d), "time")
  list(kind = "series", time_unit = obj$time_unit, origin = obj$origin, note = obj$note,
       stats = c(points = nrow(d), span = diff(range(d$time, na.rm = TRUE))),
       series = d,
       summary = do.call(rbind, lapply(vals, function(v) {
         x <- suppressWarnings(as.numeric(d[[v]]))
         data.frame(variable = v, n = sum(!is.na(x)), mean = mean(x, na.rm = TRUE),
                    sd = stats::sd(x, na.rm = TRUE), min = min(x, na.rm = TRUE),
                    max = max(x, na.rm = TRUE), missing = mean(is.na(x)))
       })))
}

profile <- function(obj, ...) {
  switch(obj$kind, dyadic = profile_dyadic(obj, ...), hyper = profile_hyper(obj),
         series = profile_series(obj))
}
