# test-decay-and-remove.R
# Coverage for reciprocity_exp_decay endogenous stat and risk = "remove" rule.

test_that("reciprocity_exp_decay column matches the hand-derived weighted sum", {
  set.seed(1)
  half <- 2
  rate <- log(2) / half
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 2,
    endogenous_stats = "reciprocity_exp_decay",
    endogenous_effects = 0,           # zero coefficient -> stat is pure observable
    half_life = half
  )
  # Hand-compute for every row.
  for (i in seq_len(nrow(ev))) {
    if (i == 1L) {
      expect_equal(ev$reciprocity_exp_decay[i], 0, info = paste("row", i))
      next
    }
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    reverse_mask <- prior$sender == ev$receiver[i] & prior$receiver == ev$sender[i]
    expected <- sum(exp(-(ev$time[i] - prior$time[reverse_mask]) * rate))
    expect_equal(ev$reciprocity_exp_decay[i], expected,
                 tolerance = 1e-8, info = paste("row", i))
  }
})

test_that("reciprocity_exp_decay requires a positive half_life", {
  actors <- LETTERS[1:3]
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = "reciprocity_exp_decay",
      endogenous_effects = 0.5
    ),
    "half_life must be a positive finite scalar"
  )
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = "reciprocity_exp_decay",
      endogenous_effects = 0.5,
      half_life = -1
    ),
    "half_life must be a positive finite scalar"
  )
  expect_error(
    simulate_relational_events(
      n_events = 2, senders = actors, receivers = actors,
      endogenous_stats = "reciprocity_exp_decay",
      endogenous_effects = 0.5,
      half_life = Inf
    ),
    "half_life must be a positive finite scalar"
  )
})

test_that("exp-decay stat composes with reciprocity_count in the same call", {
  set.seed(42)
  ev <- simulate_relational_events(
    n_events = 20,
    senders = LETTERS[1:4], receivers = LETTERS[1:4],
    baseline_rate = 2,
    endogenous_stats = c("reciprocity_count", "reciprocity_exp_decay"),
    endogenous_effects = c(reciprocity_count = 0, reciprocity_exp_decay = 0),
    half_life = 1
  )
  expect_true(all(c("reciprocity_count", "reciprocity_exp_decay") %in% names(ev)))
  # The exp-decay value never exceeds the integer count.
  expect_true(all(ev$reciprocity_exp_decay <= ev$reciprocity_count + 1e-9))
  # Their relationship: as half_life -> Inf the two coincide; for finite
  # half_life, exp_decay <= count.
  expect_true(all(ev$reciprocity_exp_decay >= 0))
})

test_that("positive reciprocity_exp_decay effect is recoverable via case-control GAM", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  library(mgcv)

  set.seed(2026)
  true_beta <- 0.8
  cc <- simulate_relational_events(
    n_events = 1500,
    senders = as.character(1:10), receivers = as.character(1:10),
    baseline_rate = 1, allow_loops = FALSE,
    n_controls = 1,
    endogenous_stats = "reciprocity_exp_decay",
    endogenous_effects = true_beta,
    half_life = 0.5
  )
  cases    <- cc[cc$event == 1L, ]
  controls <- cc[cc$event == 0L, ]
  cases    <- cases[order(cases$stratum), ]
  controls <- controls[order(controls$stratum), ]
  fit_df <- data.frame(
    one     = 1,
    delta_r = cases$reciprocity_exp_decay - controls$reciprocity_exp_decay
  )
  fit <- gam(one ~ delta_r - 1, family = "binomial", data = fit_df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.4 && est < 1.3,
              info = sprintf("estimated decayed reciprocity effect = %.3f", est))
})

test_that("risk = 'remove' produces unique dyads only", {
  set.seed(7)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 1, risk = "remove"
  )
  expect_false(any(duplicated(paste(ev$sender, ev$receiver))),
               info = "remove-risk dyads should never repeat")
})

test_that("risk = 'remove' terminates gracefully when admissible dyads run out", {
  # 3 actors, no loops -> 6 dyads. Asking for 50 should yield 6 rows.
  set.seed(11)
  ev <- simulate_relational_events(
    n_events = 50,
    senders = LETTERS[1:3], receivers = LETTERS[1:3],
    baseline_rate = 1, risk = "remove"
  )
  expect_equal(nrow(ev), 6L)
  expect_false(any(duplicated(paste(ev$sender, ev$receiver))))
})

test_that("risk = 'remove' composes with case-control sampling", {
  set.seed(99)
  cc <- simulate_relational_events(
    n_events = 10,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 1, n_controls = 1, risk = "remove"
  )
  # Realized events are all unique dyads ...
  events_only <- cc[cc$event == 1L, ]
  expect_false(any(duplicated(paste(events_only$sender, events_only$receiver))))
  # ... and the controls drawn in each stratum should not equal the
  # event in that stratum.
  for (k in unique(cc$stratum)) {
    rows <- cc[cc$stratum == k, ]
    ev_row <- rows[rows$event == 1L, ]
    ct_rows <- rows[rows$event == 0L, ]
    expect_false(any(paste(ct_rows$sender, ct_rows$receiver) ==
                       paste(ev_row$sender, ev_row$receiver)))
  }
})

test_that("risk = 'remove' under tau-leap also produces unique dyads", {
  set.seed(13)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3, risk = "remove",
    method = "tau_leap", tau = 0.02
  )
  expect_false(any(duplicated(paste(ev$sender, ev$receiver))))
})

test_that("exp-decay + remove + case-control compose with all features", {
  set.seed(17)
  cc <- simulate_relational_events(
    n_events = 15,
    senders = LETTERS[1:6], receivers = LETTERS[1:6],
    baseline_rate = 1, n_controls = 1, risk = "remove",
    endogenous_stats = "reciprocity_exp_decay",
    endogenous_effects = 0.3,
    half_life = 1
  )
  expect_true(all(c("stratum", "event", "reciprocity_exp_decay") %in% names(cc)))
  events_only <- cc[cc$event == 1L, ]
  expect_false(any(duplicated(paste(events_only$sender, events_only$receiver))))
})
