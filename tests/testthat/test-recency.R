# test-recency.R
# Coverage for the "recency" endogenous stat in simulate_relational_events().

test_that("recency column matches t - t_last on the same ordered dyad", {
  set.seed(1)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 3,
    endogenous_stats = "recency",
    endogenous_effects = 0   # zero coefficient -> column is pure observable
  )
  expect_true("recency" %in% names(ev))
  # Hand-compute: recency at row i = t_i - t_last(s_i, r_i), or t_i - 0
  # (start_time default) if dyad has never fired.
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    same_mask <- prior$sender == ev$sender[i] & prior$receiver == ev$receiver[i]
    if (any(same_mask)) {
      expected <- ev$time[i] - max(prior$time[same_mask])
    } else {
      expected <- ev$time[i]   # start_time defaulted to 0
    }
    expect_equal(ev$recency[i], expected, tolerance = 1e-9,
                 info = paste("row", i))
  }
})

test_that("recency uses start_time as the never-seen default", {
  set.seed(7)
  ev <- simulate_relational_events(
    n_events = 5,
    senders = LETTERS[1:3], receivers = LETTERS[1:3],
    baseline_rate = 5,
    start_time = 10,
    endogenous_stats = "recency", endogenous_effects = 0
  )
  # First event on its dyad: recency = t - 10.
  expect_equal(ev$recency[1], ev$time[1] - 10, tolerance = 1e-9)
})

test_that("recency composes with reciprocity_count in the same call", {
  set.seed(11)
  cc <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:3], receivers = LETTERS[1:3],
    baseline_rate = 1, n_controls = 1,
    endogenous_stats = c("recency", "reciprocity_count"),
    endogenous_effects = c(recency = 0, reciprocity_count = 0)
  )
  expect_true(all(c("recency", "reciprocity_count") %in% names(cc)))
  expect_true(all(cc$recency >= 0))
  expect_true(all(cc$reciprocity_count >= 0))
})

test_that("tau-leap path produces the same recency semantics", {
  set.seed(42)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 2,
    endogenous_stats = "recency", endogenous_effects = 0,
    method = "tau_leap", tau = 0.02
  )
  expect_true("recency" %in% names(ev))
  # Each row's recency must be a non-negative observable quantity. We do not
  # row-by-row match against history because tau-leap's snapshot semantics
  # use the start-of-step state, which can deviate from exact event-time
  # state when multiple events fall in the same step.
  expect_true(all(ev$recency >= 0))
})

test_that("negative recency effect concentrates events on freshly-fired dyads", {
  # With a negative coefficient on recency, the rate of dyad (s, r) decays
  # as more time passes without it firing -- events should cluster on
  # dyads that have just fired (small recency). Test as a coarse sign
  # check: mean recency at events < mean for the control population.
  # Effect kept mild so the rate matrix does not collapse below the
  # n_controls + 1 admissible-dyad floor.
  skip_on_cran()
  set.seed(2026)
  cc <- simulate_relational_events(
    n_events = 600,
    senders = LETTERS[1:8], receivers = LETTERS[1:8],
    baseline_rate = 2,
    n_controls = 1,
    endogenous_stats = "recency",
    endogenous_effects = -0.8
  )
  mean_events   <- mean(cc$recency[cc$event == 1L])
  mean_controls <- mean(cc$recency[cc$event == 0L])
  expect_lt(mean_events, mean_controls)
})

test_that("recency requires an endogenous_effects entry just like other stats", {
  expect_error(
    simulate_relational_events(
      n_events = 5, senders = LETTERS[1:3], receivers = LETTERS[1:3],
      endogenous_stats = "recency"
    ),
    "endogenous_effects must be supplied"
  )
})
