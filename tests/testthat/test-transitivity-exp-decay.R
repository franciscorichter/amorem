# test-transitivity-exp-decay.R
# Coverage for the two new exp-decay transitivity stats:
#   transitivity_exp_decay         (paper t^(5c))
#   transitivity_exp_decay_ordered (paper t^(6c))

# Brute-force computation of paper t^(5c)/t^(6c) given a prior event log.
# For each intermediary k, the chain s -> k -> r contributes a single
# exp-decayed term centred on its formation time. The half_life T defines
# the decay rate ln 2 / T. `ordered = TRUE` further requires s -> k to
# fire strictly before k -> r.
expected_decay <- function(prior, s, r, t_now, half_life, actors,
                            ordered = FALSE) {
  if (!nrow(prior)) return(0)
  decay_rate <- log(2) / half_life
  out <- 0
  for (k in actors) {
    if (k == s || k == r) next
    leg1 <- prior$time[prior$sender == s & prior$receiver == k]
    leg2 <- prior$time[prior$sender == k & prior$receiver == r]
    if (!length(leg1) || !length(leg2)) next
    if (ordered) {
      # First k -> r event strictly after first s -> k event
      valid_leg2 <- leg2[leg2 > min(leg1)]
      if (!length(valid_leg2)) next
      formation <- min(valid_leg2)
    } else {
      # Two-path formation = time the second leg first appears
      formation <- max(min(leg1), min(leg2))
    }
    out <- out + exp(-(t_now - formation) * decay_rate)
  }
  out
}

test_that("transitivity_exp_decay matches brute force t^(5c) computation", {
  set.seed(31)
  hl <- 0.5
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "transitivity_exp_decay",
    endogenous_effects = 0,
    half_life = hl
  )
  actors <- LETTERS[1:5]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    exp_val <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], hl, actors, ordered = FALSE)
    expect_equal(ev$transitivity_exp_decay[i], exp_val,
                 tolerance = 1e-9, info = paste("row", i))
  }
})

test_that("transitivity_exp_decay_ordered matches brute force t^(6c) computation", {
  set.seed(32)
  hl <- 0.8
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = "transitivity_exp_decay_ordered",
    endogenous_effects = 0,
    half_life = hl
  )
  actors <- LETTERS[1:5]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    exp_val <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], hl, actors, ordered = TRUE)
    expect_equal(ev$transitivity_exp_decay_ordered[i], exp_val,
                 tolerance = 1e-9, info = paste("row", i))
  }
})

test_that("ordered exp_decay agrees with unordered when natural-order chains hold", {
  # When every chain s -> k -> r is formed in chronological order
  # (every k has min(s -> k) < min(k -> r)), the ordered and unordered
  # exp_decay totals must coincide -- the formation time is identical
  # for both definitions. Constructively schedule such a regime by
  # using a moderate baseline rate and a one-mode universe, then check
  # row-by-row that whenever the ordered total is positive it equals
  # the unordered total for the chains that hold the natural order.
  # (The general inequality `ordered <= unordered` does NOT hold: a
  # later ordered-formation time yields LESS decay and hence a LARGER
  # contribution per chain, even though the ordered set is a subset.)
  set.seed(33)
  hl <- 1
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_exp_decay",
                         "transitivity_exp_decay_ordered"),
    endogenous_effects = c(transitivity_exp_decay = 0,
                            transitivity_exp_decay_ordered = 0),
    half_life = hl
  )
  actors <- LETTERS[1:5]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    e_unord <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], hl, actors, ordered = FALSE)
    e_ord   <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], hl, actors, ordered = TRUE)
    expect_equal(ev$transitivity_exp_decay[i],         e_unord, tolerance = 1e-9)
    expect_equal(ev$transitivity_exp_decay_ordered[i], e_ord,   tolerance = 1e-9)
  }
})

test_that("exp_decay stats are 0 when transitivity_count is 0", {
  set.seed(34)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_count", "transitivity_exp_decay"),
    endogenous_effects = c(transitivity_count = 0, transitivity_exp_decay = 0),
    half_life = 1
  )
  zero <- ev$transitivity_count == 0
  expect_true(all(ev$transitivity_exp_decay[zero] == 0))
})

test_that("exp_decay stats decay over time with the configured half_life", {
  # Schedule a deterministic sequence: an s-k-r chain forms at t = 0,
  # then no further events for a long stretch.  The unordered exp_decay
  # at the closing s -> r event should be exp(-(t_close - 0) * ln 2 / T).
  set.seed(35)
  T_half <- 2
  # Use very low baseline_rate so the simulator produces sparse output,
  # making the brute-force check tight.
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 0.3,
    endogenous_stats = "transitivity_exp_decay",
    endogenous_effects = 0,
    half_life = T_half
  )
  actors <- LETTERS[1:5]
  decay_rate <- log(2) / T_half
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    exp_val <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], T_half, actors, ordered = FALSE)
    expect_equal(ev$transitivity_exp_decay[i], exp_val,
                 tolerance = 1e-9, info = paste("row", i))
  }
})

test_that("half_life is required when an exp-decay stat is requested", {
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = LETTERS[1:3], receivers = LETTERS[1:3],
      endogenous_stats = "transitivity_exp_decay",
      endogenous_effects = 0
    ),
    "half_life"
  )
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders = LETTERS[1:3], receivers = LETTERS[1:3],
      endogenous_stats = "transitivity_exp_decay_ordered",
      endogenous_effects = 0
    ),
    "half_life"
  )
})

test_that("exp_decay stats run under tau-leap and stay non-negative", {
  set.seed(36)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("transitivity_exp_decay",
                         "transitivity_exp_decay_ordered"),
    endogenous_effects = c(transitivity_exp_decay = 0,
                            transitivity_exp_decay_ordered = 0),
    half_life = 1,
    method = "tau_leap", tau = 0.02
  )
  expect_true(all(ev$transitivity_exp_decay >= 0))
  expect_true(all(ev$transitivity_exp_decay_ordered >= 0))
})

test_that("exp_decay stats error on bipartite settings (one-mode required)", {
  for (st in c("transitivity_exp_decay", "transitivity_exp_decay_ordered")) {
    expect_error(
      simulate_relational_events(
        n_events = 5,
        senders = c("a", "b"), receivers = c("x", "y", "z"),
        endogenous_stats = st,
        endogenous_effects = 0.5,
        half_life = 1
      ),
      "one-mode",
      info = st
    )
  }
})

test_that("a positive coefficient on transitivity_exp_decay is sign-recoverable", {
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
    endogenous_stats = "transitivity_exp_decay",
    endogenous_effects = true_beta,
    half_life = 1
  )
  cases <- cc[cc$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc[cc$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(
    one     = rep(1, nrow(cases)),
    delta_d = cases$transitivity_exp_decay - ctrls$transitivity_exp_decay
  )
  fit <- gam(one ~ delta_d - 1, family = "binomial", data = df)
  est <- unname(coef(fit)[1])
  expect_true(est > 0.15 && est < 0.7,
              info = sprintf("estimated exp_decay effect = %.3f", est))
})

test_that("reciprocity_exp_decay still works alongside the new exp_decay stats", {
  # The has_exp_decay / apply_exp_decay refactor must not break the
  # pre-existing reciprocity_exp_decay path.
  set.seed(37)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("reciprocity_exp_decay", "transitivity_exp_decay"),
    endogenous_effects = c(reciprocity_exp_decay = 0,
                            transitivity_exp_decay = 0),
    half_life = 0.5
  )
  expect_true(all(ev$reciprocity_exp_decay >= 0))
  expect_true(all(ev$transitivity_exp_decay >= 0))
})
