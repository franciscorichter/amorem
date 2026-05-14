# test-reciprocity-timing.R
# Coverage for reciprocity_time_recent and reciprocity_time_first.

test_that("reciprocity_time_recent equals t - max(time of prior reverse events)", {
  set.seed(11)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 3,
    endogenous_stats = "reciprocity_time_recent",
    endogenous_effects = 0
  )
  expect_true("reciprocity_time_recent" %in% names(ev))
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    reverse_times <- prior$time[prior$sender == ev$receiver[i] &
                                  prior$receiver == ev$sender[i]]
    expected <- if (length(reverse_times)) {
      ev$time[i] - max(reverse_times)
    } else {
      0
    }
    expect_equal(ev$reciprocity_time_recent[i], expected,
                 info = paste("row", i))
  }
})

test_that("reciprocity_time_first equals t - min(time of prior reverse events)", {
  set.seed(12)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 3,
    endogenous_stats = "reciprocity_time_first",
    endogenous_effects = 0
  )
  expect_true("reciprocity_time_first" %in% names(ev))
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    reverse_times <- prior$time[prior$sender == ev$receiver[i] &
                                  prior$receiver == ev$sender[i]]
    expected <- if (length(reverse_times)) {
      ev$time[i] - min(reverse_times)
    } else {
      0
    }
    expect_equal(ev$reciprocity_time_first[i], expected,
                 info = paste("row", i))
  }
})

test_that("time_first >= time_recent on every row (first event was at least as early)", {
  set.seed(13)
  ev <- simulate_relational_events(
    n_events = 40,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_time_first", "reciprocity_time_recent"),
    endogenous_effects = c(reciprocity_time_first = 0,
                            reciprocity_time_recent = 0)
  )
  expect_true(all(ev$reciprocity_time_first >= ev$reciprocity_time_recent))
})

test_that("both timing stats are 0 on the first occurrence of a dyad direction (never-seen reverse)", {
  set.seed(14)
  ev <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_time_recent", "reciprocity_time_first"),
    endogenous_effects = c(reciprocity_time_recent = 0,
                            reciprocity_time_first = 0)
  )
  # For each row, check whether the reverse dyad has fired before it. If
  # not, both stats must be zero.
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    reverse_seen <- any(prior$sender == ev$receiver[i] &
                          prior$receiver == ev$sender[i])
    if (!reverse_seen) {
      expect_equal(ev$reciprocity_time_recent[i], 0, info = paste("row", i))
      expect_equal(ev$reciprocity_time_first[i],  0, info = paste("row", i))
    }
  }
})

test_that("timing stats compose with other reciprocity stats in the same call", {
  set.seed(15)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 2,
    endogenous_stats = c("reciprocity_count", "reciprocity_time_recent",
                         "reciprocity_time_first"),
    endogenous_effects = c(reciprocity_count = 0,
                            reciprocity_time_recent = 0,
                            reciprocity_time_first = 0)
  )
  expect_true(all(c("reciprocity_count", "reciprocity_time_recent",
                    "reciprocity_time_first") %in% names(ev)))
  # When reciprocity_count is 0 (reverse never fired) the timing stats
  # must also be 0.
  zero_recent <- ev$reciprocity_count == 0
  expect_true(all(ev$reciprocity_time_recent[zero_recent] == 0))
  expect_true(all(ev$reciprocity_time_first[zero_recent]  == 0))
})

test_that("timing stats work under tau-leap (start-of-step approximation)", {
  set.seed(16)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 2,
    endogenous_stats = c("reciprocity_time_recent", "reciprocity_time_first"),
    endogenous_effects = c(reciprocity_time_recent = 0,
                            reciprocity_time_first = 0),
    method = "tau_leap", tau = 0.02
  )
  expect_true(all(ev$reciprocity_time_recent >= 0))
  expect_true(all(ev$reciprocity_time_first  >= 0))
  expect_true(all(ev$reciprocity_time_first >= ev$reciprocity_time_recent))
})

test_that("positive coefficient on reciprocity_time_recent is sign-recoverable via GAM", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)

  # A positive coefficient on time_recent means dyads whose reverse fired
  # *long ago* fire faster; a negative one means recent-reverse dyads do.
  # Use a positive true beta and check the sign and magnitude of the
  # recovered estimate.
  set.seed(2026)
  true_beta <- 0.4
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, n_controls = 1,
    endogenous_stats = "reciprocity_time_recent",
    endogenous_effects = true_beta
  )
  cases    <- cc[cc$event == 1L, ]
  controls <- cc[cc$event == 0L, ]
  cases    <- cases[order(cases$stratum), ]
  controls <- controls[order(controls$stratum), ]
  fit_df <- data.frame(
    one     = 1,
    delta_t = cases$reciprocity_time_recent - controls$reciprocity_time_recent
  )
  fit <- gam(one ~ delta_t - 1, family = "binomial", data = fit_df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.1 && est < 0.75,
              info = sprintf("estimated time_recent effect = %.3f", est))
})
