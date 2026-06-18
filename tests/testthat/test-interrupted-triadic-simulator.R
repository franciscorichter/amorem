# test-interrupted-triadic-simulator.R
# Simulator-side generation of the count / binary / exp_decay variants
# of the *_interrupted family for the four closure families. Each test
# simulates an event log with one family's interrupted stats active
# and verifies the per-row simulator output matches what the post-hoc
# engine (already covered by test-interrupted-triadic.R) produces from
# the same event log.

run_parity <- function(family, seed, n_events = 40, n_actors = 5,
                       baseline_rate = 2, half_life = 4) {
  stats <- c(paste0(family, "_count_interrupted"),
             paste0(family, "_binary_interrupted"),
             paste0(family, "_exp_decay_interrupted"))
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = baseline_rate,
    endogenous_stats = stats,
    endogenous_effects = setNames(rep(0, length(stats)), stats),
    half_life = half_life)
  ref <- endogenous_features(
    ev[, c("sender", "receiver", "time")],
    stats = stats, half_life = half_life)
  for (st in stats) {
    expect_equal(ev[[st]], ref[[st]], tolerance = 1e-9,
                 info = paste(family, st))
  }
}

test_that("transitivity_*_interrupted (count/binary/exp_decay) match the post-hoc engine", {
  for (sd in c(11, 12, 13)) run_parity("transitivity", sd)
})

test_that("cyclic_*_interrupted match the post-hoc engine", {
  for (sd in c(21, 22, 23)) run_parity("cyclic", sd)
})

test_that("sending_balance_*_interrupted match the post-hoc engine", {
  for (sd in c(31, 32, 33)) run_parity("sending_balance", sd)
})

test_that("receiving_balance_*_interrupted match the post-hoc engine", {
  for (sd in c(41, 42, 43)) run_parity("receiving_balance", sd)
})

test_that("count_interrupted is <= unordered count on every simulated row", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    stat_int <- paste0(family, "_count_interrupted")
    stat_unord <- paste0(family, "_count")
    set.seed(101)
    ev <- simulate_relational_events(
      n_events = 35,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = c(stat_unord, stat_int),
      endogenous_effects = setNames(c(0, 0), c(stat_unord, stat_int)))
    expect_true(all(ev[[stat_int]] <= ev[[stat_unord]]), info = family)
  }
})

test_that("binary_interrupted equals (count_interrupted > 0) for each family", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    count_st  <- paste0(family, "_count_interrupted")
    binary_st <- paste0(family, "_binary_interrupted")
    set.seed(202)
    ev <- simulate_relational_events(
      n_events = 25,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = c(count_st, binary_st),
      endogenous_effects = setNames(c(0, 0), c(count_st, binary_st)))
    expect_equal(ev[[binary_st]], as.numeric(ev[[count_st]] > 0),
                 info = family)
  }
})

test_that("interrupted stats work under tau-leap", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    stats <- c(paste0(family, "_count_interrupted"),
               paste0(family, "_binary_interrupted"))
    set.seed(505)
    ev <- simulate_relational_events(
      n_events = 30,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = stats,
      endogenous_effects = setNames(c(0, 0), stats),
      method = "tau_leap", tau = 0.02)
    expect_equal(ev[[stats[2]]], as.numeric(ev[[stats[1]]] > 0),
                 info = family)
  }
})

test_that("exp_decay_interrupted requires half_life at the simulator", {
  expect_error(
    simulate_relational_events(
      n_events = 10,
      senders = LETTERS[1:4], receivers = LETTERS[1:4],
      baseline_rate = 1,
      endogenous_stats = "cyclic_exp_decay_interrupted",
      endogenous_effects = c(cyclic_exp_decay_interrupted = 0)),
    regexp = "half_life")
})

test_that("a positive coefficient on transitivity_count_interrupted is sign-recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  set.seed(2026)
  true_beta <- 0.35
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "transitivity_count_interrupted",
    endogenous_effects = c(transitivity_count_interrupted = true_beta))
  cases <- cc[cc$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc[cc$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(
    one = rep(1, nrow(cases)),
    delta_t = cases$transitivity_count_interrupted -
              ctrls$transitivity_count_interrupted)
  fit <- mgcv::gam(one ~ delta_t - 1, family = "binomial", data = df)
  est <- unname(stats::coef(fit)[1])
  expect_true(est > 0.1 && est < 0.7,
              info = sprintf("estimated effect = %.3f", est))
})
