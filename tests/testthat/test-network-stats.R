# test-network-stats.R
# Coverage for the transitivity_*, cyclic_*, sending_balance_*,
# receiving_balance_* endogenous stats.

reverse_adj_at <- function(ev, time_now) {
  # Build the binary "ever-fired" adjacency from rows of `ev` strictly
  # before time_now. Returns an actor-by-actor matrix indexed by character
  # labels.
  actors <- sort(unique(c(ev$sender, ev$receiver)))
  A <- matrix(0L, length(actors), length(actors),
              dimnames = list(actors, actors))
  prior <- ev[ev$time < time_now, , drop = FALSE]
  for (i in seq_len(nrow(prior))) {
    A[prior$sender[i], prior$receiver[i]] <- 1L
  }
  A
}

test_that("transitivity_count matches the (A %*% A) entry hand-derivation", {
  set.seed(11)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "transitivity_count",
    endogenous_effects = 0
  )
  expect_true("transitivity_count" %in% names(ev))
  for (i in seq_len(nrow(ev))) {
    A <- reverse_adj_at(ev, ev$time[i])
    expected <- sum(A[ev$sender[i], ] * A[, ev$receiver[i]])
    expect_equal(ev$transitivity_count[i], expected,
                 info = paste("row", i))
  }
})

test_that("transitivity_binary equals as.numeric(transitivity_count > 0)", {
  set.seed(12)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_binary", "transitivity_count"),
    endogenous_effects = c(transitivity_binary = 0, transitivity_count = 0)
  )
  expect_equal(ev$transitivity_binary,
               as.numeric(ev$transitivity_count > 0))
})

test_that("cyclic_count at (s, r) equals transitivity at (r, s) for the same history", {
  set.seed(13)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("cyclic_count", "transitivity_count"),
    endogenous_effects = c(cyclic_count = 0, transitivity_count = 0)
  )
  for (i in seq_len(nrow(ev))) {
    A <- reverse_adj_at(ev, ev$time[i])
    expected_cyc <- sum(A[ev$receiver[i], ] * A[, ev$sender[i]])
    expect_equal(ev$cyclic_count[i], expected_cyc,
                 info = paste("row", i))
  }
})

test_that("sending_balance_count is sum_k A[s,k] * A[r,k]", {
  set.seed(14)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "sending_balance_count",
    endogenous_effects = 0
  )
  for (i in seq_len(nrow(ev))) {
    A <- reverse_adj_at(ev, ev$time[i])
    expected <- sum(A[ev$sender[i], ] * A[ev$receiver[i], ])
    expect_equal(ev$sending_balance_count[i], expected,
                 info = paste("row", i))
  }
})

test_that("receiving_balance_count is sum_k A[k,s] * A[k,r]", {
  set.seed(15)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "receiving_balance_count",
    endogenous_effects = 0
  )
  for (i in seq_len(nrow(ev))) {
    A <- reverse_adj_at(ev, ev$time[i])
    expected <- sum(A[, ev$sender[i]] * A[, ev$receiver[i]])
    expect_equal(ev$receiving_balance_count[i], expected,
                 info = paste("row", i))
  }
})

test_that("all 4 binary stats match as.numeric(count > 0)", {
  set.seed(16)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_binary", "transitivity_count",
                         "cyclic_binary", "cyclic_count",
                         "sending_balance_binary", "sending_balance_count",
                         "receiving_balance_binary", "receiving_balance_count"),
    endogenous_effects = setNames(
      rep(0, 8),
      c("transitivity_binary", "transitivity_count",
        "cyclic_binary", "cyclic_count",
        "sending_balance_binary", "sending_balance_count",
        "receiving_balance_binary", "receiving_balance_count")
    )
  )
  expect_equal(ev$transitivity_binary,
               as.numeric(ev$transitivity_count > 0))
  expect_equal(ev$cyclic_binary,
               as.numeric(ev$cyclic_count > 0))
  expect_equal(ev$sending_balance_binary,
               as.numeric(ev$sending_balance_count > 0))
  expect_equal(ev$receiving_balance_binary,
               as.numeric(ev$receiving_balance_count > 0))
})

test_that("recency + transitivity_count compose in the same call", {
  set.seed(17)
  ev <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("recency", "transitivity_count"),
    endogenous_effects = c(recency = 0, transitivity_count = 0)
  )
  expect_true(all(c("recency", "transitivity_count") %in% names(ev)))
  expect_true(all(ev$recency >= 0))
  expect_true(all(ev$transitivity_count >= 0))
})

test_that("positive transitivity_count effect is recoverable via GAM on case-control output", {
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
    endogenous_stats = "transitivity_count",
    endogenous_effects = true_beta
  )
  cases    <- cc[cc$event == 1L, ]
  controls <- cc[cc$event == 0L, ]
  cases    <- cases[order(cases$stratum), ]
  controls <- controls[order(controls$stratum), ]
  fit_df <- data.frame(
    one     = 1,
    delta_t = cases$transitivity_count - controls$transitivity_count
  )
  fit <- gam(one ~ delta_t - 1, family = "binomial", data = fit_df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.15 && est < 0.7,
              info = sprintf("estimated transitivity effect = %.3f", est))
})

test_that("tau-leap produces the same network-stat semantics under matched seed", {
  # Tau-leap uses a start-of-step snapshot for stats; values should still be
  # non-negative integers and the binary should match count > 0 when both
  # are requested.
  set.seed(42)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("transitivity_binary", "transitivity_count"),
    endogenous_effects = c(transitivity_binary = 0, transitivity_count = 0),
    method = "tau_leap", tau = 0.02
  )
  expect_equal(ev$transitivity_binary,
               as.numeric(ev$transitivity_count > 0))
  expect_true(all(ev$transitivity_count >= 0))
})
