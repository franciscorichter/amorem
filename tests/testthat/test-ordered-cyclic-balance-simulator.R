# test-ordered-cyclic-balance-simulator.R
# Simulator-side generation of the new ordered_* variants for the
# cyclic / sending-balance / receiving-balance closure families. Each
# test simulates an event log with one family's ordered stats active
# and checks that the per-row simulator output matches what the
# (already-tested) post-hoc engine produces from the same event log.

run_parity <- function(family, seed, n_events = 40, n_actors = 5,
                       baseline_rate = 2) {
  stats <- c(paste0(family, "_count_ordered"),
             paste0(family, "_binary_ordered"),
             paste0(family, "_time_recent_ordered"),
             paste0(family, "_time_first_ordered"))
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = baseline_rate,
    endogenous_stats = stats,
    endogenous_effects = setNames(rep(0, length(stats)), stats))
  ref <- compute_endogenous_features(
    ev[, c("sender", "receiver", "time")],
    stats = stats)
  for (st in stats) {
    sim_vec <- ev[[st]]
    ref_vec <- ref[[st]]
    if (grepl("^.*_time_", st)) {
      # The simulator emits 0 for "never validated" cells (rate-space
      # convention); the post-hoc engine emits NA. Align on the count.
      count_st <- paste0(family, "_count_ordered")
      none <- ev[[count_st]] == 0
      expect_equal(sim_vec[!none], ref_vec[!none], tolerance = 1e-9,
                   info = paste(family, st))
      expect_true(all(sim_vec[none] == 0), info = paste(family, st, "zero-fill"))
    } else {
      expect_equal(sim_vec, ref_vec, tolerance = 1e-9,
                   info = paste(family, st))
    }
  }
}

test_that("cyclic_*_ordered matches the post-hoc engine row-for-row", {
  for (sd in c(11, 12, 13)) run_parity("cyclic", sd)
})

test_that("sending_balance_*_ordered matches the post-hoc engine row-for-row", {
  for (sd in c(21, 22, 23)) run_parity("sending_balance", sd)
})

test_that("receiving_balance_*_ordered matches the post-hoc engine row-for-row", {
  for (sd in c(31, 32, 33)) run_parity("receiving_balance", sd)
})

test_that("ordered_count <= unordered_count for cyc/sb/rb on every simulated row", {
  for (family in c("cyclic", "sending_balance", "receiving_balance")) {
    stat_ord <- paste0(family, "_count_ordered")
    stat_unord <- paste0(family, "_count")
    set.seed(101)
    ev <- simulate_relational_events(
      n_events = 35,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = c(stat_unord, stat_ord),
      endogenous_effects = setNames(c(0, 0), c(stat_unord, stat_ord)))
    expect_true(all(ev[[stat_ord]] <= ev[[stat_unord]]),
                info = family)
  }
})

test_that("binary_ordered equals (count_ordered > 0) for each family", {
  for (family in c("cyclic", "sending_balance", "receiving_balance")) {
    count_st  <- paste0(family, "_count_ordered")
    binary_st <- paste0(family, "_binary_ordered")
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

test_that("two families simultaneously active stay independent", {
  stats <- c("cyclic_count_ordered", "sending_balance_count_ordered",
             "receiving_balance_count_ordered")
  set.seed(303)
  ev <- simulate_relational_events(
    n_events = 35,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = stats,
    endogenous_effects = setNames(rep(0, length(stats)), stats))
  ref <- compute_endogenous_features(
    ev[, c("sender", "receiver", "time")], stats = stats)
  for (st in stats) {
    expect_equal(ev[[st]], ref[[st]], tolerance = 1e-9, info = st)
  }
})

test_that("exp_decay_ordered for cyc/sb/rb stays finite and non-negative", {
  for (family in c("cyclic", "sending_balance", "receiving_balance")) {
    st <- paste0(family, "_exp_decay_ordered")
    set.seed(404)
    ev <- simulate_relational_events(
      n_events = 30,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = st,
      endogenous_effects = setNames(0, st),
      half_life = 1)
    v <- ev[[st]]
    expect_true(all(is.finite(v)) && all(v >= 0), info = family)
  }
})

test_that("ordered stats work under tau-leap for each family", {
  for (family in c("cyclic", "sending_balance", "receiving_balance")) {
    stats <- c(paste0(family, "_count_ordered"),
               paste0(family, "_binary_ordered"))
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

test_that("a positive coefficient on cyclic_count_ordered is sign-recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  set.seed(2027)
  true_beta <- 0.4
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "cyclic_count_ordered",
    endogenous_effects = c(cyclic_count_ordered = true_beta))
  cases <- cc[cc$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc[cc$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(
    one = rep(1, nrow(cases)),
    delta_t = cases$cyclic_count_ordered - ctrls$cyclic_count_ordered)
  fit <- mgcv::gam(one ~ delta_t - 1, family = "binomial", data = df)
  est <- unname(stats::coef(fit)[1])
  expect_true(est > 0.1 && est < 0.75,
              info = sprintf("estimated effect = %.3f", est))
})
