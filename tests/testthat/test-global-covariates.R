# test-global-covariates.R
# Coverage for global_covariates / global_effects (time-varying global rate).

test_that("zero global effect reproduces the constant-rate stream byte-for-byte", {
  actors <- letters[1:4]
  gc <- data.frame(time_start = c(0, 1, 2, 3, 4),
                   weekday    = c(0, 1, 0, 1, 0))
  args <- list(
    n_events = 20,
    senders = actors,
    receivers = actors,
    baseline_rate = 2,
    horizon = 5
  )

  set.seed(101)
  base <- do.call(simulate_relational_events, args)

  set.seed(101)
  with_global <- do.call(simulate_relational_events,
    c(args, list(global_covariates = gc,
                 global_effects = c(weekday = 0))))

  expect_equal(base$sender,   with_global$sender)
  expect_equal(base$receiver, with_global$receiver)
  expect_equal(base$time,     with_global$time)
  expect_true("weekday" %in% names(with_global))
})

test_that("strongly positive weekday effect concentrates events in weekday intervals", {
  set.seed(2024)
  gc <- data.frame(
    time_start = seq(0, 10, by = 1),
    weekday    = rep(c(0, 1), length.out = 11)
  )
  ev <- simulate_relational_events(
    n_events = 200,
    senders = letters[1:5],
    receivers = letters[1:5],
    baseline_rate = 0.3,
    horizon = 11,
    global_covariates = gc,
    global_effects = c(weekday = 3)
  )

  expect_gt(nrow(ev), 0L)
  share_weekday <- mean(ev$weekday == 1)
  # Effective rate ratio exp(3) ~= 20:1 weekday vs weekend; bulk of events
  # should fall in weekday=1 intervals.
  expect_gt(share_weekday, 0.85)
})

test_that("weekday column on output matches the interval at each event's time", {
  set.seed(7)
  gc <- data.frame(
    time_start = c(0, 2, 4, 6),
    weekday    = c(1, 0, 1, 0)
  )
  ev <- simulate_relational_events(
    n_events = 40,
    senders = letters[1:4],
    receivers = letters[1:4],
    baseline_rate = 1,
    horizon = 7,
    global_covariates = gc,
    global_effects = c(weekday = 0)
  )
  expected <- gc$weekday[findInterval(ev$time, gc$time_start,
                                      rightmost.closed = FALSE)]
  expect_equal(ev$weekday, expected)
})

test_that("case-control output carries the global covariate value for every row", {
  set.seed(13)
  gc <- data.frame(time_start = c(0, 1, 2), weekday = c(1, 0, 1))
  cc <- simulate_relational_events(
    n_events = 10,
    senders = letters[1:3],
    receivers = letters[1:3],
    baseline_rate = 2,
    horizon = 3,
    n_controls = 2,
    global_covariates = gc,
    global_effects = c(weekday = 0)
  )
  expect_true("weekday" %in% names(cc))
  # within a stratum, all rows share the same time -> same weekday value
  for (k in unique(cc$stratum)) {
    rows <- cc[cc$stratum == k, , drop = FALSE]
    expect_equal(length(unique(rows$weekday)), 1L)
  }
  expected <- gc$weekday[findInterval(cc$time, gc$time_start,
                                      rightmost.closed = FALSE)]
  expect_equal(cc$weekday, expected)
})

test_that("validation errors fire for malformed global inputs", {
  actors <- letters[1:3]
  base_args <- list(n_events = 2, senders = actors, receivers = actors)

  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = list(time_start = 0, weekday = 1)))),
    "data.frame"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(weekday = 1)))),
    "time_start"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(time_start = numeric(0))))),
    "at least one row"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(time_start = c(0, 1)),
                        global_effects = 1))),
    "covariate column"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(time_start = c(2, 1), weekday = c(0, 1)),
                        global_effects = 1))),
    "strictly increasing"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(start_time = 0,
                        global_covariates = data.frame(time_start = c(1, 2), weekday = c(0, 1)),
                        global_effects = 1))),
    "at or before start_time"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(time_start = c(0, 1), weekday = c(0, 1))))),
    "global_effects must be supplied"
  )
  expect_error(
    do.call(simulate_relational_events,
      c(base_args, list(global_covariates = data.frame(time_start = c(0, 1),
                                                       weekday = c(0, 1)),
                        global_effects = c(other = 1)))),
    "must match"
  )
})

test_that("non-event horizon stop still respects boundaries", {
  # In a single-interval setup the boundary-aware path must behave identically
  # to the simple path: if horizon < first interval boundary, no events fire.
  set.seed(1)
  gc <- data.frame(time_start = 0, weekday = 1)
  ev <- simulate_relational_events(
    n_events = 50,
    senders = letters[1:3],
    receivers = letters[1:3],
    baseline_rate = 1,
    horizon = 0,
    global_covariates = gc,
    global_effects = c(weekday = 0)
  )
  expect_equal(nrow(ev), 0L)
  expect_true("weekday" %in% names(ev))
})
