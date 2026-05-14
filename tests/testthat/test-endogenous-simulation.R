# test-endogenous-simulation.R
# Coverage for endogenous_stats / endogenous_effects in simulate_relational_events.

test_that("zero endogenous effect reproduces the exogenous-only simulator", {
  actors <- letters[1:4]
  args <- list(
    n_events = 30,
    senders = actors,
    receivers = actors,
    baseline_rate = 2,
    allow_loops = FALSE
  )

  set.seed(101)
  base <- do.call(simulate_relational_events, args)

  set.seed(101)
  endo <- do.call(simulate_relational_events,
    c(args, list(endogenous_stats = "reciprocity_count",
                 endogenous_effects = 0)))

  expect_equal(base$sender,   endo$sender)
  expect_equal(base$receiver, endo$receiver)
  expect_equal(base$time,     endo$time)
  expect_true("reciprocity_count" %in% names(endo))
})

test_that("reciprocity_count column tracks reverse-dyad history correctly", {
  set.seed(2026)
  actors <- letters[1:3]
  ev <- simulate_relational_events(
    n_events = 25,
    senders = actors,
    receivers = actors,
    baseline_rate = 5,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = 0
  )

  expect_true("reciprocity_count" %in% names(ev))
  expect_equal(nrow(ev), 25L)

  # Verify reciprocity_count[i] = number of past events with sender/receiver
  # swapped relative to event i.
  for (i in seq_len(nrow(ev))) {
    expected <- sum(
      ev$sender[seq_len(i - 1L)]   == ev$receiver[i] &
      ev$receiver[seq_len(i - 1L)] == ev$sender[i]
    )
    expect_equal(ev$reciprocity_count[i], expected,
                 info = paste("row", i))
  }
})

test_that("reciprocity_binary records 0/1 only and matches reciprocity_count > 0", {
  set.seed(33)
  actors <- letters[1:3]
  ev <- simulate_relational_events(
    n_events = 20,
    senders = actors,
    receivers = actors,
    baseline_rate = 5,
    endogenous_stats = c("reciprocity_binary", "reciprocity_count"),
    endogenous_effects = c(reciprocity_binary = 0, reciprocity_count = 0)
  )

  expect_true(all(ev$reciprocity_binary %in% c(0, 1)))
  expect_equal(as.numeric(ev$reciprocity_count > 0),
               ev$reciprocity_binary)
})

test_that("case-control output carries per-row stat values for both events and controls", {
  set.seed(7)
  actors <- letters[1:4]
  cc <- simulate_relational_events(
    n_events = 10,
    senders = actors,
    receivers = actors,
    baseline_rate = 2,
    n_controls = 2,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = 0
  )

  expect_true(all(c("stratum", "event", "reciprocity_count") %in% names(cc)))
  expect_gt(nrow(cc), 10L)

  # All controls within a stratum should share the event's time stamp.
  for (k in unique(cc$stratum)) {
    rows <- cc[cc$stratum == k, , drop = FALSE]
    expect_equal(length(unique(rows$time)), 1L)
  }

  # Realized-event reciprocity_count must equal the count of past
  # reverse-dyad realized events (same invariant as the simple log).
  events_only <- cc[cc$event == 1L, ]
  events_only <- events_only[order(events_only$stratum), ]
  for (i in seq_len(nrow(events_only))) {
    past <- events_only[seq_len(i - 1L), , drop = FALSE]
    expected <- sum(past$sender == events_only$receiver[i] &
                    past$receiver == events_only$sender[i])
    expect_equal(events_only$reciprocity_count[i], expected,
                 info = paste("stratum", events_only$stratum[i]))
  }
})

test_that("validation: unknown stat, missing effects, length mismatch all error", {
  actors <- letters[1:3]
  expect_error(
    simulate_relational_events(n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = "made_up_stat", endogenous_effects = 1),
    "Unsupported endogenous_stats"
  )
  expect_error(
    simulate_relational_events(n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = "reciprocity_count"),
    "endogenous_effects must be supplied"
  )
  expect_error(
    simulate_relational_events(n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = c("reciprocity_count", "reciprocity_binary"),
      endogenous_effects = c(1)),
    "same length"
  )
  expect_error(
    simulate_relational_events(n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = c("reciprocity_count", "reciprocity_binary"),
      endogenous_effects = c(wrong_name = 1, reciprocity_count = 2)),
    "must match"
  )
})

test_that("endogenous_stats errors clearly on bipartite / two-mode sender/receiver sets", {
  # The endogenous state machinery indexes a single (S x S) matrix and updates
  # its reverse dyad after each event. That update assumes senders == receivers
  # in the same order. The simulator should refuse rectangular / disjoint
  # actor sets with a clear message rather than silently miscount reciprocity.
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = letters[1:3],
      receivers = LETTERS[1:3],            # disjoint receiver set
      endogenous_stats = "reciprocity_count",
      endogenous_effects = 0.5
    ),
    "same character vector"
  )

  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = letters[1:3],
      receivers = letters[1:4],            # different length
      endogenous_stats = "reciprocity_count",
      endogenous_effects = 0.5
    ),
    "same character vector"
  )

  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = letters[1:3],
      receivers = letters[3:1],            # same set, reordered
      endogenous_stats = "reciprocity_count",
      endogenous_effects = 0.5
    ),
    "same character vector"
  )
})

test_that("positive reciprocity effect is recoverable via conditional logistic regression", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)

  set.seed(2024)
  actors <- as.character(1:10)
  true_beta <- 0.6

  cc <- simulate_relational_events(
    n_events = 1500,
    senders = actors,
    receivers = actors,
    baseline_rate = 1,
    allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "reciprocity_count",
    endogenous_effects = true_beta
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
  # generous interval (single replicate); the point is to catch sign/scale bugs.
  expect_true(est > 0.3 && est < 0.9,
              info = sprintf("estimated reciprocity effect = %.3f", est))
})
