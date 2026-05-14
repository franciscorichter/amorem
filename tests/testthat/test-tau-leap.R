# test-tau-leap.R
# Coverage for method = "tau_leap" in simulate_relational_events().

test_that("method = 'gillespie' (default) is unchanged when tau-leap args are added", {
  set.seed(101)
  g1 <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:4],
    receivers = LETTERS[1:4],
    baseline_rate = 1.5
  )
  set.seed(101)
  g2 <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:4],
    receivers = LETTERS[1:4],
    baseline_rate = 1.5,
    method = "gillespie"
  )
  expect_identical(g1, g2)
})

test_that("tau must be supplied when method = 'tau_leap'", {
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = LETTERS[1:3], receivers = LETTERS[1:3],
      method = "tau_leap"
    ),
    "tau must be supplied"
  )
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = LETTERS[1:3], receivers = LETTERS[1:3],
      method = "tau_leap", tau = -0.1
    ),
    "positive finite"
  )
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = LETTERS[1:3], receivers = LETTERS[1:3],
      method = "tau_leap", tau = Inf
    ),
    "positive finite"
  )
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = LETTERS[1:3], receivers = LETTERS[1:3],
      tau = 0.1
    ),
    "tau is only used"
  )
})

test_that("tau-leap produces n_events records in time order", {
  set.seed(7)
  ev <- simulate_relational_events(
    n_events = 50,
    senders = letters[1:5],
    receivers = letters[1:5],
    baseline_rate = 2,
    method = "tau_leap", tau = 0.05
  )
  expect_equal(nrow(ev), 50L)
  expect_true(all(diff(ev$time) >= 0))
  expect_true(all(ev$sender %in% letters[1:5]))
  expect_true(all(ev$sender != ev$receiver))
})

test_that("tau-leap with horizon stops at horizon", {
  set.seed(11)
  ev <- simulate_relational_events(
    n_events = 1000,
    senders = letters[1:4],
    receivers = letters[1:4],
    baseline_rate = 0.5,
    horizon = 1,
    method = "tau_leap", tau = 0.05
  )
  expect_lte(max(ev$time), 1)
})

test_that("zero events: tau-leap on horizon = 0 returns empty frame with right columns", {
  set.seed(1)
  ev <- simulate_relational_events(
    n_events = 5, senders = letters[1:3], receivers = letters[1:3],
    baseline_rate = 1, horizon = 0,
    method = "tau_leap", tau = 0.1
  )
  expect_equal(nrow(ev), 0L)
  expect_setequal(names(ev), c("sender", "receiver", "time"))
})

test_that("tau-leap mean rate approximately matches the theoretical rate", {
  # 6 valid dyads (no loops, 3x3), each rate exp(0) * baseline_rate = 1.
  # Total rate = 6; expected event count over horizon = 2 is 12.
  set.seed(202)
  reps <- 60
  counts <- replicate(reps, {
    ev <- simulate_relational_events(
      n_events = 1000,
      senders = letters[1:3], receivers = letters[1:3],
      baseline_rate = 1, horizon = 2,
      method = "tau_leap", tau = 0.02
    )
    nrow(ev)
  })
  # mean should be near 12; allow a wide tolerance for stochasticity.
  expect_true(abs(mean(counts) - 12) < 1.5,
              info = sprintf("observed mean %.2f", mean(counts)))
})

test_that("tau-leap respects time-varying global covariates (rate ratio)", {
  set.seed(303)
  # Alternating weekday=0/1 unit intervals; weekday effect = log(4) so
  # weekday rate is 4x weekend.
  gc <- data.frame(
    time_start = seq(0, 10, by = 1),
    weekday    = rep(c(0, 1), length.out = 11)
  )
  ev <- simulate_relational_events(
    n_events = 1500,
    senders = letters[1:5],
    receivers = letters[1:5],
    baseline_rate = 0.5,
    horizon = 11,
    global_covariates = gc,
    global_effects = c(weekday = log(4)),
    method = "tau_leap", tau = 0.02
  )
  share_weekday <- mean(ev$weekday == 1)
  # 5 weekday and 6 weekend intervals of length 1 each; expected share:
  # 5 * 4 / (5 * 4 + 6 * 1) = 20 / 26 ≈ 0.769.
  expect_true(share_weekday > 0.70 && share_weekday < 0.83,
              info = sprintf("observed share %.3f (expected ~0.77)", share_weekday))
})

test_that("tau-leap with endogenous reciprocity_count: events skew to high-state cells", {
  set.seed(404)
  cc <- simulate_relational_events(
    n_events = 600,
    senders = as.character(1:8),
    receivers = as.character(1:8),
    baseline_rate = 1,
    n_controls = 1,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6),
    method = "tau_leap", tau = 0.02
  )
  expect_true("reciprocity_count" %in% names(cc))
  mean_at_events   <- mean(cc$reciprocity_count[cc$event == 1L])
  mean_at_controls <- mean(cc$reciprocity_count[cc$event == 0L])
  expect_gt(mean_at_events, mean_at_controls)
})

test_that("tau-leap output matches Gillespie shape and column set", {
  set.seed(55)
  gc <- data.frame(time_start = c(0, 2), weekday = c(1, 0))
  args <- list(
    n_events = 30,
    senders = letters[1:4], receivers = letters[1:4],
    baseline_rate = 1, horizon = 3,
    n_controls = 1,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = 0.2,
    global_covariates = gc, global_effects = c(weekday = 1)
  )
  g <- do.call(simulate_relational_events, args)
  t <- do.call(simulate_relational_events,
               c(args, list(method = "tau_leap", tau = 0.02)))
  expect_setequal(names(g), names(t))
  # Both should expose reciprocity_count and weekday columns and the
  # case-control machinery.
  expect_true(all(c("stratum", "event", "sender", "receiver", "time",
                    "reciprocity_count", "weekday") %in% names(t)))
})

test_that("recovered reciprocity beta via case-control GAM is consistent under tau-leap", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)

  set.seed(2024)
  true_beta <- 0.5
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = as.character(1:10), receivers = as.character(1:10),
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = true_beta,
    method = "tau_leap", tau = 0.02
  )
  cases    <- cc[cc$event == 1L, ]
  controls <- cc[cc$event == 0L, ]
  cases    <- cases[order(cases$stratum), ]
  controls <- controls[order(controls$stratum), ]
  fit_df <- data.frame(
    one     = 1,
    delta_r = cases$reciprocity_count - controls$reciprocity_count
  )
  fit <- gam(one ~ delta_r - 1, family = "binomial", data = fit_df)
  est <- unname(coef(fit)[1])
  # Wider window than the Gillespie test: tau-leap introduces small bias
  # plus single-replicate sampling noise.
  expect_true(est > 0.2 && est < 0.9,
              info = sprintf("estimated reciprocity effect (tau-leap) = %.3f", est))
})
