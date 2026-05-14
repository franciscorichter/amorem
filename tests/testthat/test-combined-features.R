# test-combined-features.R
# Exercises endogenous_stats and global_covariates active simultaneously.
# PR #9 composes the two paths (per-step endogenous recompute + global
# multiplier rescaling). These tests pin down the joint behaviour.

test_that("zero endogenous + zero global effect matches the global-only zero-effect run", {
  # The boundary-aware Gillespie path consumes additional rexp draws on every
  # interval crossing, so it does NOT byte-match the simple (no-global)
  # simulator under a shared seed. The right invariant is: turning the
  # endogenous coefficients off should leave the global-only stream
  # unchanged, since the per-step rate recomputation is a no-op when the
  # endogenous coefficient vector is zero.
  actors <- letters[1:4]
  gc <- data.frame(
    time_start = c(0, 1, 2, 3, 4),
    weekday    = c(1, 0, 1, 0, 1)
  )
  args <- list(
    n_events = 25,
    senders = actors,
    receivers = actors,
    baseline_rate = 2,
    horizon = 5,
    global_covariates = gc,
    global_effects = c(weekday = 0)
  )

  set.seed(2026)
  global_only <- do.call(simulate_relational_events, args)

  set.seed(2026)
  combined <- do.call(
    simulate_relational_events,
    c(args, list(
      endogenous_stats   = "reciprocity_count",
      endogenous_effects = c(reciprocity_count = 0)
    ))
  )

  expect_equal(global_only$sender,   combined$sender)
  expect_equal(global_only$receiver, combined$receiver)
  expect_equal(global_only$time,     combined$time)
  expect_true(all(c("reciprocity_count", "weekday") %in% names(combined)))
})

test_that("both stat columns appear with the correct per-row values", {
  set.seed(99)
  actors <- letters[1:4]
  gc <- data.frame(
    time_start = c(0, 2, 4, 6),
    weekday    = c(1, 0, 1, 0)
  )

  ev <- simulate_relational_events(
    n_events = 30,
    senders = actors,
    receivers = actors,
    baseline_rate = 1,
    horizon = 8,
    endogenous_stats   = c("reciprocity_count", "reciprocity_binary"),
    endogenous_effects = c(reciprocity_count = 0, reciprocity_binary = 0),
    global_covariates  = gc,
    global_effects     = c(weekday = 0)
  )

  expect_true(all(
    c("reciprocity_count", "reciprocity_binary", "weekday") %in% names(ev)
  ))

  # Global column matches the interval at each event time.
  expected_weekday <- gc$weekday[findInterval(
    ev$time, gc$time_start, rightmost.closed = FALSE
  )]
  expect_equal(ev$weekday, expected_weekday)

  # Endogenous count reproduces the reverse-dyad tally over realized history.
  for (i in seq_len(nrow(ev))) {
    past_reverse <- sum(
      ev$sender[seq_len(i - 1L)]   == ev$receiver[i] &
      ev$receiver[seq_len(i - 1L)] == ev$sender[i]
    )
    expect_equal(ev$reciprocity_count[i], past_reverse, info = paste("row", i))
    expect_equal(ev$reciprocity_binary[i],
                 as.numeric(past_reverse > 0),
                 info = paste("row", i))
  }
})

test_that("case-control composition: per-row stat and global values align with each stratum", {
  set.seed(11)
  actors <- letters[1:5]
  gc <- data.frame(time_start = c(0, 1, 2, 3), weekday = c(1, 0, 1, 0))

  cc <- simulate_relational_events(
    n_events = 12,
    senders = actors,
    receivers = actors,
    baseline_rate = 2,
    horizon = 4,
    n_controls = 2,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0),
    global_covariates  = gc,
    global_effects     = c(weekday = 0)
  )

  expect_true(all(
    c("stratum", "event", "reciprocity_count", "weekday") %in% names(cc)
  ))

  # Within a stratum, the global covariate value must be constant: events and
  # their controls share the same event time.
  for (k in unique(cc$stratum)) {
    rows <- cc[cc$stratum == k, , drop = FALSE]
    expect_equal(length(unique(rows$weekday)), 1L)
    expect_equal(length(unique(rows$time)), 1L)
  }
})
