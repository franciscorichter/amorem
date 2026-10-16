# Tests for time-shifted case-control sampling, sample_non_events(shift =
# "exponential") (issue #101; Lembo, Juozaitiene, Vinciotti & Wit 2025, Sec. 4).

shift_log <- function(seed = 1, n = 60, actors = letters[1:6]) {
  set.seed(seed)
  ev <- data.frame(sender   = sample(actors, n, replace = TRUE),
                   receiver = sample(actors, n, replace = TRUE),
                   time     = sort(runif(n, 0, 10)), stringsAsFactors = FALSE)
  ev[ev$sender != ev$receiver, ]
}

# Brute-force shifted risk set of each event from the returned shifts, and a
# count of controls that are not in it or not stored at their shifted time.
shift_violations <- function(cc, allow = function(key, tstar) TRUE) {
  info <- attr(cc, "shift")
  h <- info$shifts; w <- info$window
  keys <- names(h)
  s <- sub("->.*", "", keys); r <- sub(".*->", "", keys)
  ev <- cc[cc$event == 1L, ]; ct <- cc[cc$event == 0L, ]
  bad <- 0L
  for (k in seq_len(nrow(ev))) {
    own <- paste0(ev$sender[k], "->", ev$receiver[k])
    te <- ev$time[k] + h[[own]]
    tstar <- te - h
    ok <- tstar >= w[1] & tstar <= w[2] & keys != own & s != r &
      mapply(allow, keys, tstar)
    cand <- keys[ok]
    ck <- ct[ct$stratum == ev$stratum[k], ]
    if (!nrow(ck)) {
      if (length(cand)) bad <- bad + 1L
      if (!ev$stratum[k] %in% info$uninformative) bad <- bad + 1L
      next
    }
    ckey <- paste0(ck$sender, "->", ck$receiver)
    if (!all(ckey %in% cand)) bad <- bad + 1L
    if (any(abs(ck$time - (te - h[ckey])) > 1e-9)) bad <- bad + 1L
  }
  bad
}

test_that("shifted controls carry their own times (the issue #101 example)", {
  set.seed(1)
  ev <- data.frame(sender   = sample(letters[1:5], 50, replace = TRUE),
                   receiver = sample(letters[1:5], 50, replace = TRUE),
                   time     = sort(runif(50)))
  ev <- ev[ev$sender != ev$receiver, ]
  none <- sample_non_events(ev, n_controls = 1, seed = 1)
  expect_true(all(tapply(none$time, none$stratum, function(x) length(unique(x))) == 1L))
  sh <- sample_non_events(ev, n_controls = 1, seed = 1, shift = "exponential")
  ctrl <- sh[sh$event == 0L, ]
  ev_time <- sh$time[sh$event == 1L][match(ctrl$stratum, sh$stratum[sh$event == 1L])]
  expect_true(all(ctrl$time != ev_time))
  expect_true(all(ctrl$time >= min(ev$time) & ctrl$time <= max(ev$time)))
})

test_that("shift = 'none' is the default and leaves the sample unchanged", {
  el <- shift_log()
  expect_identical(sample_non_events(el, n_controls = 2, seed = 4),
                   sample_non_events(el, n_controls = 2, seed = 4, shift = "none"))
  expect_null(attr(sample_non_events(el, seed = 4), "shift"))
})

test_that("every control is drawn from the shifted risk set, for both modes", {
  el <- shift_log()
  for (m in c("one", "two")) {
    for (nu in c(1, 30)) {
      cc <- sample_non_events(el, n_controls = 3, mode = m, seed = 2,
                              shift = "exponential", shift_scale = nu,
                              window = c(0, 10))
      expect_equal(shift_violations(cc), 0L)
    }
  }
})

test_that("one shift per dyad, with mean shift_scale x the average event time", {
  el <- shift_log(n = 80)
  cc <- sample_non_events(el, mode = "one", seed = 3, shift = "exponential",
                          shift_scale = 2, window = c(0, 10))
  info <- attr(cc, "shift")
  expect_equal(info$mean, 2 * mean(el$time))
  expect_equal(info$window, c(0, 10))
  expect_length(info$shifts, 6L * 5L)              # ordered pairs, no loops
  expect_false(anyDuplicated(names(info$shifts)) > 0L)
})

test_that("controls are uniform over the shifted risk set", {
  # One event; with n_controls large the control frequencies should match a
  # uniform draw over its shifted risk set.
  el <- data.frame(sender = c("a", "b", "c"), receiver = c("b", "c", "a"),
                   time = c(1, 5, 9), stringsAsFactors = FALSE)
  cc <- sample_non_events(el, n_controls = 3000, mode = "one", seed = 5,
                          shift = "exponential", shift_scale = 0.2,
                          window = c(0, 10))
  info <- attr(cc, "shift")
  h <- info$shifts
  te <- 5 + h[["b->c"]]
  cand <- names(h)[te - h >= 0 & te - h <= 10 & names(h) != "b->c"]
  ct <- cc[cc$event == 0L & cc$stratum == 2L, ]
  freq <- table(factor(paste0(ct$sender, "->", ct$receiver), levels = cand))
  expect_gt(length(cand), 2L)
  expect_gt(suppressWarnings(stats::chisq.test(freq)$p.value), 1e-3)
})

test_that("risk = 'remove' and scope = 'appearance' are applied at the shifted time", {
  el <- shift_log(n = 80)
  first_fire <- tapply(el$time, paste0(el$sender, "->", el$receiver), min)
  first_seen <- tapply(c(el$time, el$time), c(el$sender, el$receiver), min)
  cc <- sample_non_events(el, n_controls = 2, mode = "one", risk = "remove",
                          scope = "appearance", seed = 6,
                          shift = "exponential", window = c(0, 10))
  allow <- function(key, tstar) {
    ff <- first_fire[key]
    s <- sub("->.*", "", key); r <- sub(".*->", "", key)
    (is.na(ff) || ff >= tstar) && first_seen[[s]] < tstar && first_seen[[r]] < tstar
  }
  expect_equal(shift_violations(cc, allow), 0L)
  expect_gt(sum(cc$event == 0L), 0L)
})

test_that("exclude_pairs are never controls, and an empty risk set skips the stratum", {
  el <- shift_log()
  forbidden <- data.frame(sender = c("a", "b"), receiver = c("b", "c"))
  cc <- sample_non_events(el, n_controls = 4, seed = 7, shift = "exponential",
                          exclude_pairs = forbidden)
  ctrl_keys <- with(cc[cc$event == 0L, ], paste0(sender, "->", receiver))
  expect_false(any(ctrl_keys %in% c("a->b", "b->c")))
  # Two actors in mode "two": each event's only alternative is excluded.
  two <- data.frame(sender = c("a", "b"), receiver = c("b", "a"), time = c(1, 2))
  cc2 <- sample_non_events(two, mode = "two", seed = 1, shift = "exponential",
                           exclude_pairs = two[, 1:2], max_attempts = 20)
  expect_equal(sum(cc2$event == 0L), 0L)
  expect_setequal(attr(cc2, "shift")$uninformative, 1:2)
})

test_that("endogenous statistics of a shifted control use the history before its own time", {
  el <- shift_log(n = 80)
  cc <- sample_non_events(el, n_controls = 1, mode = "one", seed = 8,
                          shift = "exponential", window = c(0, 10))
  feat <- endogenous_features(cc, stats = "reciprocity_count",
                              history_log = el)
  ct <- feat[feat$event == 0L, ]
  brute <- mapply(function(s, r, t) sum(el$sender == r & el$receiver == s & el$time < t),
                  ct$sender, ct$receiver, ct$time)
  expect_equal(unname(ct$reciprocity_count), unname(brute))
})

test_that("history_log also works for statistics outside the compiled engine", {
  el <- shift_log(n = 80)
  cc <- sample_non_events(el, n_controls = 2, mode = "one", seed = 3,
                          shift = "exponential", window = c(0, 10))
  both <- c("reciprocity_count", "recency", "transitivity_count")
  cpp <- endogenous_features(cc, stats = both, history_log = el)
  # Adding a non-compiled statistic sends every statistic through the R path.
  rfb <- endogenous_features(cc, stats = c(both, "reciprocity_time_recent",
                                           "reciprocity_exp_decay"),
                             history_log = el, half_life = 2)
  expect_equal(rfb[, both], cpp[, both])
  past_reverse <- function(s, r, t) el$time[el$sender == r & el$receiver == s & el$time < t]
  recent <- mapply(function(s, r, t) {
    x <- past_reverse(s, r, t); if (length(x)) t - max(x) else NA_real_
  }, rfb$sender, rfb$receiver, rfb$time)
  decay <- mapply(function(s, r, t) sum(exp(-(t - past_reverse(s, r, t)) * log(2) / 2)),
                  rfb$sender, rfb$receiver, rfb$time)
  expect_equal(unname(rfb$reciprocity_time_recent), unname(recent))
  expect_equal(unname(rfb$reciprocity_exp_decay), unname(decay))
})

test_that("widen_case_control pairs shifted controls by stratum after rows are re-sorted", {
  el <- shift_log(n = 80)
  cc <- sample_non_events(el, n_controls = 1, mode = "one", seed = 9,
                          shift = "exponential", window = c(0, 10))
  feat <- endogenous_features(cc, stats = "reciprocity_count", history_log = el)
  expect_false(identical(feat$stratum, cc$stratum))   # rows were reordered
  w <- widen_case_control(feat, covariates = c("reciprocity_count", "time"))
  informative <- setdiff(unique(cc$stratum), attr(cc, "shift")$uninformative)
  expect_setequal(w$stratum, informative)
  ctrl <- cc[cc$event == 0L, ]
  m <- match(w$stratum, ctrl$stratum)
  expect_equal(w$time_nv, ctrl$time[m])
  expect_equal(w$sender_nv, ctrl$sender[m])
})

test_that("a global effect is recovered from the shifted design", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  a <- paste0("a", 1:10)
  g <- data.frame(time_start = seq(0, 400, by = 2))
  g$x <- rep(c(0, 1), length.out = nrow(g))
  set.seed(1)
  ev <- simulate_relational_events(n_events = 2000, senders = a, receivers = a,
                                   baseline_rate = 0.1, global_covariates = g,
                                   global_effects = c(x = 1))
  ev <- ev[, c("sender", "receiver", "time")]
  cc <- sample_non_events(ev, mode = "one", seed = 1, shift = "exponential",
                          window = c(0, max(ev$time)))
  cc$x <- g$x[findInterval(cc$time, g$time_start)]
  w <- suppressMessages(widen_case_control(cc, covariates = "x"))
  fit <- rem(~ x, data = w, method = "gam")
  expect_lt(abs(coef(fit)[["x"]] - 1), 0.25)
})

test_that("shift arguments are validated", {
  el <- shift_log()
  expect_error(sample_non_events(el, shift = "exponential", scope = "citation"),
               "citation")
  expect_error(sample_non_events(el, shift = "exponential", shift_scale = 0),
               "shift_scale")
  expect_error(sample_non_events(el, shift = "exponential", window = c(5, 1)),
               "window")
  expect_error(sample_non_events(el, shift = "exponential", window = c(2, 10)),
               "inside `window`")
  expect_error(sample_non_events(el, shift = "gamma"))
})
