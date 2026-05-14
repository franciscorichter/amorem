# test-transitivity-timing.R
# Coverage for transitivity_time_recent and transitivity_time_first.
#
# Per Juozaitienė & Wit (2024) §2.2.1 these are the t^(7ac) and t^(7bc)
# definitions: the time elapsed since the most recent / first two-path
# s -> k -> r was formed for any intermediary k. "Formed" means the
# later of the two legs (s,k) and (k,r) had been observed.

two_path_times <- function(ev, i) {
  # For event row i, return the formation times of every two-path
  # s -> k -> r where s = ev$sender[i], r = ev$receiver[i], computed
  # from rows strictly before i (the simulator records the value the
  # dyad had at its event time, *before* this event fires).
  prior <- ev[seq_len(i - 1L), , drop = FALSE]
  s <- ev$sender[i]; r <- ev$receiver[i]
  ks <- unique(c(prior$sender, prior$receiver))
  out <- numeric(0)
  for (k in ks) {
    leg1_times <- prior$time[prior$sender == s & prior$receiver == k]
    leg2_times <- prior$time[prior$sender == k & prior$receiver == r]
    if (length(leg1_times) && length(leg2_times)) {
      out <- c(out, max(min(leg1_times), min(leg2_times)))
    }
  }
  out
}

test_that("transitivity_time_recent equals t - max(formation time of 2-paths s->k->r)", {
  set.seed(31)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "transitivity_time_recent",
    endogenous_effects = 0
  )
  expect_true("transitivity_time_recent" %in% names(ev))
  for (i in seq_len(nrow(ev))) {
    fts <- two_path_times(ev, i)
    expected <- if (length(fts)) ev$time[i] - max(fts) else 0
    expect_equal(ev$transitivity_time_recent[i], expected,
                 info = paste("row", i))
  }
})

test_that("transitivity_time_first equals t - min(formation time of 2-paths s->k->r)", {
  set.seed(32)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "transitivity_time_first",
    endogenous_effects = 0
  )
  expect_true("transitivity_time_first" %in% names(ev))
  for (i in seq_len(nrow(ev))) {
    fts <- two_path_times(ev, i)
    expected <- if (length(fts)) ev$time[i] - min(fts) else 0
    expect_equal(ev$transitivity_time_first[i], expected,
                 info = paste("row", i))
  }
})

test_that("time_first >= time_recent on every row", {
  set.seed(33)
  ev <- simulate_relational_events(
    n_events = 40,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_time_first", "transitivity_time_recent"),
    endogenous_effects = c(transitivity_time_first = 0,
                            transitivity_time_recent = 0)
  )
  expect_true(all(ev$transitivity_time_first >= ev$transitivity_time_recent))
})

test_that("both timing stats are 0 when transitivity_count is 0 (no two-path yet)", {
  set.seed(34)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count",
                         "transitivity_time_recent",
                         "transitivity_time_first"),
    endogenous_effects = c(transitivity_count = 0,
                            transitivity_time_recent = 0,
                            transitivity_time_first = 0)
  )
  zero <- ev$transitivity_count == 0
  expect_true(all(ev$transitivity_time_recent[zero] == 0))
  expect_true(all(ev$transitivity_time_first[zero]  == 0))
})

test_that("timing stats error on bipartite settings (one-mode required)", {
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = c("a", "b"), receivers = c("x", "y", "z"),
      endogenous_stats = "transitivity_time_recent",
      endogenous_effects = 0.5
    ),
    "one-mode"
  )
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = c("a", "b"), receivers = c("x", "y", "z"),
      endogenous_stats = "transitivity_time_first",
      endogenous_effects = 0.5
    ),
    "one-mode"
  )
})

test_that("transitivity timing composes with transitivity_count and recency", {
  set.seed(35)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("transitivity_count", "transitivity_time_recent",
                         "transitivity_time_first", "recency"),
    endogenous_effects = c(transitivity_count = 0,
                            transitivity_time_recent = 0,
                            transitivity_time_first = 0,
                            recency = 0)
  )
  expect_true(all(c("transitivity_count", "transitivity_time_recent",
                    "transitivity_time_first", "recency") %in% names(ev)))
  expect_true(all(ev$transitivity_time_recent >= 0))
  expect_true(all(ev$transitivity_time_first  >= 0))
})

test_that("timing stats work under tau-leap", {
  set.seed(36)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("transitivity_time_recent",
                         "transitivity_time_first"),
    endogenous_effects = c(transitivity_time_recent = 0,
                            transitivity_time_first = 0),
    method = "tau_leap", tau = 0.02
  )
  expect_true(all(ev$transitivity_time_recent >= 0))
  expect_true(all(ev$transitivity_time_first  >= 0))
  expect_true(all(ev$transitivity_time_first >= ev$transitivity_time_recent))
})

test_that("positive coefficient on transitivity_time_recent is sign-recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)

  # A positive coefficient on time_recent means dyads whose last two-path
  # formed long ago fire faster; in our (low-rate) baseline, this is
  # equivalent to: dyads with old two-paths get a boost. Use 1500 events
  # and case-control with n_controls = 1.
  set.seed(2026)
  true_beta <- 0.3
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "transitivity_time_recent",
    endogenous_effects = true_beta
  )
  cases    <- cc[cc$event == 1L, ]
  controls <- cc[cc$event == 0L, ]
  cases    <- cases[order(cases$stratum), ]
  controls <- controls[order(controls$stratum), ]
  fit_df <- data.frame(
    one     = 1,
    delta_t = cases$transitivity_time_recent - controls$transitivity_time_recent
  )
  fit <- gam(one ~ delta_t - 1, family = "binomial", data = fit_df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.05 && est < 0.65,
              info = sprintf("estimated transitivity_time_recent effect = %.3f", est))
})
