# test-ordered-transitivity.R
# Coverage for the four new generative ordered-transitivity stats:
#   transitivity_count_ordered, transitivity_binary_ordered,
#   transitivity_time_recent_ordered, transitivity_time_first_ordered.
#
# Per Juozaitiene & Wit (2024) eqs 2c / 4c / 8ac / 8bc, an *ordered*
# two-path s -> k -> r requires the chronological constraint that the
# first leg (s, k) is observed strictly before the second leg (k, r);
# unordered variants allow either temporal order.

# Brute-force computation of the set of validated intermediaries `k` and
# their per-k validation times for an ordered chain s -> k -> r given the
# prior event log `prior`. Returns a numeric vector (possibly empty) of
# validation times, one per validated k.
validated_ordered <- function(prior, s, r, actors) {
  out <- numeric(0)
  for (k in actors) {
    if (k == s || k == r) next
    leg1 <- prior$time[prior$sender == s & prior$receiver == k]
    leg2 <- prior$time[prior$sender == k & prior$receiver == r]
    if (!length(leg1) || !length(leg2)) next
    # Smallest leg2 time that is strictly after the smallest leg1 time
    # is the chain's validation time (first time both legs are present
    # with the required ordering). If no such leg2 exists, the chain
    # is not ordered-validated.
    earliest_leg1 <- min(leg1)
    valid_leg2 <- leg2[leg2 > earliest_leg1]
    if (length(valid_leg2)) out <- c(out, min(valid_leg2))
  }
  out
}

run_check <- function(seed, n_events = 25, n_actors = 5) {
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count_ordered",
                         "transitivity_binary_ordered",
                         "transitivity_time_recent_ordered",
                         "transitivity_time_first_ordered"),
    endogenous_effects = c(transitivity_count_ordered = 0,
                            transitivity_binary_ordered = 0,
                            transitivity_time_recent_ordered = 0,
                            transitivity_time_first_ordered = 0)
  )
  actors <- LETTERS[1:n_actors]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    val_times <- validated_ordered(prior, ev$sender[i], ev$receiver[i], actors)
    exp_count <- length(val_times)
    exp_binary <- as.numeric(exp_count > 0)
    exp_recent <- if (exp_count) ev$time[i] - max(val_times) else 0
    exp_first  <- if (exp_count) ev$time[i] - min(val_times) else 0
    expect_equal(ev$transitivity_count_ordered[i],  exp_count,  info = paste("row", i))
    expect_equal(ev$transitivity_binary_ordered[i], exp_binary, info = paste("row", i))
    expect_equal(ev$transitivity_time_recent_ordered[i], exp_recent,
                 info = paste("row", i, "recent"))
    expect_equal(ev$transitivity_time_first_ordered[i],  exp_first,
                 info = paste("row", i, "first"))
  }
  ev
}

test_that("count / binary / time_recent / time_first match brute-force ordered semantics", {
  for (sd in c(11, 12, 13)) run_check(sd)
})

test_that("ordered count is always <= unordered count", {
  set.seed(21)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count", "transitivity_count_ordered"),
    endogenous_effects = c(transitivity_count = 0,
                            transitivity_count_ordered = 0)
  )
  expect_true(all(ev$transitivity_count_ordered <= ev$transitivity_count))
})

test_that("binary_ordered equals (count_ordered > 0) on every row", {
  set.seed(22)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count_ordered",
                         "transitivity_binary_ordered"),
    endogenous_effects = c(transitivity_count_ordered = 0,
                            transitivity_binary_ordered = 0)
  )
  expect_equal(ev$transitivity_binary_ordered,
               as.numeric(ev$transitivity_count_ordered > 0))
})

test_that("time_first_ordered >= time_recent_ordered on every row", {
  set.seed(23)
  ev <- simulate_relational_events(
    n_events = 40,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_time_recent_ordered",
                         "transitivity_time_first_ordered"),
    endogenous_effects = c(transitivity_time_recent_ordered = 0,
                            transitivity_time_first_ordered = 0)
  )
  expect_true(all(ev$transitivity_time_first_ordered >=
                   ev$transitivity_time_recent_ordered))
})

test_that("the time stats are 0 iff count_ordered is 0", {
  set.seed(24)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count_ordered",
                         "transitivity_time_recent_ordered",
                         "transitivity_time_first_ordered"),
    endogenous_effects = c(transitivity_count_ordered = 0,
                            transitivity_time_recent_ordered = 0,
                            transitivity_time_first_ordered = 0)
  )
  zero <- ev$transitivity_count_ordered == 0
  expect_true(all(ev$transitivity_time_recent_ordered[zero] == 0))
  expect_true(all(ev$transitivity_time_first_ordered[zero]  == 0))
})

test_that("ordered stats error on bipartite settings (one-mode required)", {
  for (st in c("transitivity_count_ordered", "transitivity_binary_ordered",
               "transitivity_time_recent_ordered",
               "transitivity_time_first_ordered")) {
    expect_error(
      simulate_relational_events(
        n_events = 5,
        senders = c("a", "b"), receivers = c("x", "y", "z"),
        endogenous_stats = st,
        endogenous_effects = 0.5
      ),
      "one-mode",
      info = st
    )
  }
})

test_that("ordered stats work under tau-leap and stay consistent with the count", {
  set.seed(31)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("transitivity_count_ordered",
                         "transitivity_binary_ordered",
                         "transitivity_time_recent_ordered",
                         "transitivity_time_first_ordered"),
    endogenous_effects = c(transitivity_count_ordered = 0,
                            transitivity_binary_ordered = 0,
                            transitivity_time_recent_ordered = 0,
                            transitivity_time_first_ordered = 0),
    method = "tau_leap", tau = 0.02
  )
  expect_equal(ev$transitivity_binary_ordered,
               as.numeric(ev$transitivity_count_ordered > 0))
  expect_true(all(ev$transitivity_time_first_ordered >=
                   ev$transitivity_time_recent_ordered))
})

test_that("a positive coefficient on transitivity_count_ordered is sign-recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)
  set.seed(2026)
  true_beta <- 0.3
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "transitivity_count_ordered",
    endogenous_effects = true_beta
  )
  cases <- cc[cc$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc[cc$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(
    one     = rep(1, nrow(cases)),
    delta_t = cases$transitivity_count_ordered -
              ctrls$transitivity_count_ordered
  )
  fit <- gam(one ~ delta_t - 1, family = "binomial", data = df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.1 && est < 0.65,
              info = sprintf("estimated count_ordered effect = %.3f", est))
})
