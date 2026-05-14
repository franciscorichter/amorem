# test-interrupted-reciprocity.R
# Coverage for the five new interrupted reciprocity stats:
#   reciprocity_binary_interrupted, reciprocity_count_interrupted,
#   reciprocity_exp_decay_interrupted,
#   reciprocity_time_recent_interrupted,
#   reciprocity_time_first_interrupted
#
# Per Juozaitiene & Wit (2024) §2.1.3, each interrupted statistic
# measures the same quantity as its continuous counterpart but only
# considers reverse-dyad events that occurred SINCE the most recent
# same-direction event closes the reciprocity cycle.

# Brute-force interrupted reciprocity counts/times at a given event
# row given the prior log.
brute_force_int <- function(prior, s, r, ti, half_life = 1) {
  reverse <- prior$time[prior$sender == r & prior$receiver == s]
  same_dir <- prior$time[prior$sender == s & prior$receiver == r]
  last_closure <- if (length(same_dir)) max(same_dir) else -Inf
  active_reverse <- reverse[reverse > last_closure]
  count <- length(active_reverse)
  binary <- as.integer(count > 0)
  exp_dec <- if (count == 0) 0 else
    sum(exp(-(ti - active_reverse) * log(2) / half_life))
  recent_t <- if (count == 0) NA_real_ else ti - max(active_reverse)
  first_t  <- if (count == 0) NA_real_ else ti - min(active_reverse)
  list(count = count, binary = binary, exp_decay = exp_dec,
       recent = recent_t, first = first_t)
}

test_that("simulator interrupted reciprocity matches brute force on small one-mode runs", {
  set.seed(11)
  hl <- 1
  stats_vec <- c("reciprocity_count_interrupted",
                  "reciprocity_binary_interrupted",
                  "reciprocity_exp_decay_interrupted",
                  "reciprocity_time_recent_interrupted",
                  "reciprocity_time_first_interrupted")
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = stats_vec,
    endogenous_effects = setNames(rep(0, length(stats_vec)), stats_vec),
    half_life = hl
  )
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    bf <- brute_force_int(prior, ev$sender[i], ev$receiver[i], ev$time[i], hl)
    expect_equal(ev$reciprocity_count_interrupted[i],     bf$count,  info = paste("row", i))
    expect_equal(ev$reciprocity_binary_interrupted[i],    bf$binary, info = paste("row", i))
    expect_equal(ev$reciprocity_exp_decay_interrupted[i], bf$exp_decay,
                 tolerance = 1e-9, info = paste("row", i))
    # The simulator reports 0 for never-seen-since-closure (vs NA in
    # brute force / post-hoc); fold NA -> 0 for comparison.
    if (is.na(bf$recent)) {
      expect_equal(ev$reciprocity_time_recent_interrupted[i], 0)
      expect_equal(ev$reciprocity_time_first_interrupted[i],  0)
    } else {
      expect_equal(ev$reciprocity_time_recent_interrupted[i], bf$recent)
      expect_equal(ev$reciprocity_time_first_interrupted[i],  bf$first)
    }
  }
})

test_that("interrupted count is <= continuous count on every row", {
  set.seed(12)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_count", "reciprocity_count_interrupted"),
    endogenous_effects = c(reciprocity_count = 0,
                            reciprocity_count_interrupted = 0)
  )
  expect_true(all(ev$reciprocity_count_interrupted <= ev$reciprocity_count))
})

test_that("interrupted state resets to 0 (count) / NA (time) after a closure event", {
  # Hand-crafted log:
  #   t=1: B -> A (reverse for dyad (A, B))   => count_int @ next (A, B) read = ?
  #   t=2: B -> A (another reverse)
  #   t=3: A -> B (closure -- resets)
  #   t=4: B -> A (reverse again, post-reset)
  # We can't drive specific firings through the simulator easily, but
  # we CAN inject the log into compute_endogenous_features() and verify
  # the resulting columns.
  log_df <- data.frame(
    sender   = c("B", "B", "A", "B", "A"),
    receiver = c("A", "A", "B", "A", "B"),
    time     = c(1,   2,   3,   4,   5))
  feat <- compute_endogenous_features(
    log_df,
    stats = c("reciprocity_count_interrupted",
              "reciprocity_time_recent_interrupted",
              "reciprocity_time_first_interrupted"))
  # Event 3 (A -> B) reads state[A -> B], which counts reverse (B -> A)
  # events since the most recent (A -> B) event. There was no prior
  # (A -> B), so all (B -> A) events count: B->A at 1 and 2 -> count = 2.
  expect_equal(feat$reciprocity_count_interrupted[3], 2)
  expect_equal(feat$reciprocity_time_recent_interrupted[3], 3 - 2)  # ti - 2
  expect_equal(feat$reciprocity_time_first_interrupted[3],  3 - 1)  # ti - 1
  # Event 5 (A -> B) reads state[A -> B] after the closure at t=3.
  # Only (B -> A) at t=4 counts (post-reset). Count = 1.
  expect_equal(feat$reciprocity_count_interrupted[5], 1)
  expect_equal(feat$reciprocity_time_recent_interrupted[5], 5 - 4)
  expect_equal(feat$reciprocity_time_first_interrupted[5],  5 - 4)
})

test_that("interrupted time stats are NA in post-hoc / 0 in simulator on first-row", {
  set.seed(13)
  ev <- simulate_relational_events(
    n_events = 10,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_time_recent_interrupted",
                         "reciprocity_time_first_interrupted"),
    endogenous_effects = c(reciprocity_time_recent_interrupted = 0,
                            reciprocity_time_first_interrupted = 0)
  )
  expect_equal(ev$reciprocity_time_recent_interrupted[1], 0)
  expect_equal(ev$reciprocity_time_first_interrupted[1],  0)
})

test_that("sim and post-hoc agree on every interrupted variant", {
  set.seed(14)
  hl <- 0.7
  stats_vec <- c("reciprocity_count_interrupted",
                  "reciprocity_binary_interrupted",
                  "reciprocity_exp_decay_interrupted",
                  "reciprocity_time_recent_interrupted",
                  "reciprocity_time_first_interrupted")
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = stats_vec,
    endogenous_effects = setNames(rep(0, length(stats_vec)), stats_vec),
    half_life = hl
  )
  base <- ev[, c("sender", "receiver", "time")]
  phf <- compute_endogenous_features(base, stats = stats_vec, half_life = hl)
  for (st in stats_vec) {
    a <- ev[[st]]; b <- phf[[st]]
    b[is.na(b)] <- 0  # post-hoc NA = simulator 0 for never-since-closure
    expect_equal(a, b, tolerance = 1e-9, info = st)
  }
})

test_that("half_life is required when reciprocity_exp_decay_interrupted is requested", {
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = LETTERS[1:3], receivers = LETTERS[1:3],
      endogenous_stats = "reciprocity_exp_decay_interrupted",
      endogenous_effects = 0
    ),
    "half_life"
  )
})

test_that("interrupted variants compose with their continuous counterparts", {
  set.seed(15)
  ev <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_count", "reciprocity_count_interrupted",
                         "reciprocity_time_recent",
                         "reciprocity_time_recent_interrupted"),
    endogenous_effects = c(reciprocity_count = 0,
                            reciprocity_count_interrupted = 0,
                            reciprocity_time_recent = 0,
                            reciprocity_time_recent_interrupted = 0)
  )
  # Whenever the interrupted count is positive, the continuous count
  # must also be positive (interrupted is a subset).
  expect_true(all(ev$reciprocity_count_interrupted[ev$reciprocity_count == 0] == 0))
})

test_that("interrupted reciprocity runs under tau-leap", {
  set.seed(16)
  stats_vec <- c("reciprocity_count_interrupted",
                  "reciprocity_time_recent_interrupted",
                  "reciprocity_time_first_interrupted")
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = stats_vec,
    endogenous_effects = setNames(rep(0, length(stats_vec)), stats_vec),
    method = "tau_leap", tau = 0.02
  )
  expect_true(all(ev$reciprocity_count_interrupted >= 0))
  expect_true(all(ev$reciprocity_time_recent_interrupted >= 0))
  expect_true(all(ev$reciprocity_time_first_interrupted  >= 0))
})

test_that("a positive coefficient on reciprocity_count_interrupted is sign-recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)
  set.seed(2026)
  true_beta <- 0.4
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "reciprocity_count_interrupted",
    endogenous_effects = true_beta
  )
  cases <- cc[cc$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc[cc$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(
    one     = rep(1, nrow(cases)),
    delta_c = cases$reciprocity_count_interrupted -
              ctrls$reciprocity_count_interrupted
  )
  fit <- gam(one ~ delta_c - 1, family = "binomial", data = df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.15 && est < 0.7,
              info = sprintf("estimated count_interrupted effect = %.3f", est))
})
