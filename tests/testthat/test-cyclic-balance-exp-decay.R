# test-cyclic-balance-exp-decay.R
# Coverage for the three new generative exp-decay stats:
#   cyclic_exp_decay            (paper c^(5c))
#   sending_balance_exp_decay   (paper sb^(5c))
#   receiving_balance_exp_decay (paper rb^(5c))
#
# Each family follows the same template as transitivity_exp_decay
# (paper t^(5c)): for each intermediary k, the relevant two-path
# contributes a single exp-decayed term centred on its formation
# time (= time the second of its two legs is first observed).

# Brute-force expected exp_decay at a given (s, r) and time, for a
# specified family. `legs(prior, which, s, r, k)` returns the mask
# selecting all rows of `prior` that are the requested leg (A or B)
# of the family's two-path between s and r through k.
expected_decay <- function(prior, s, r, t_now, half_life, actors,
                            legs_fn) {
  if (!nrow(prior)) return(0)
  decay_rate <- log(2) / half_life
  out <- 0
  for (k in actors) {
    if (k == s || k == r) next
    legA <- prior$time[legs_fn(prior, "A", s, r, k)]
    legB <- prior$time[legs_fn(prior, "B", s, r, k)]
    if (!length(legA) || !length(legB)) next
    formation <- max(min(legA), min(legB))
    out <- out + exp(-(t_now - formation) * decay_rate)
  }
  out
}

families <- list(
  cyclic = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == r & prior$receiver == k
    else              prior$sender == k & prior$receiver == s
  },
  sending_balance = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == s & prior$receiver == k
    else              prior$sender == r & prior$receiver == k
  },
  receiving_balance = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == k & prior$receiver == s
    else              prior$sender == k & prior$receiver == r
  })

run_check <- function(family_name, stat_name, seed, n_events = 25,
                       n_actors = 5, half_life = 0.7) {
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = 3,
    endogenous_stats = stat_name,
    endogenous_effects = 0,
    half_life = half_life)
  actors <- LETTERS[1:n_actors]
  legs_fn <- families[[family_name]]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    exp_val <- expected_decay(prior, ev$sender[i], ev$receiver[i],
                              ev$time[i], half_life, actors, legs_fn)
    expect_equal(ev[[stat_name]][i], exp_val, tolerance = 1e-9,
                 info = paste(family_name, "row", i))
  }
}

test_that("cyclic_exp_decay matches brute force on small one-mode runs", {
  run_check("cyclic", "cyclic_exp_decay", seed = 51)
})

test_that("sending_balance_exp_decay matches brute force on small one-mode runs", {
  run_check("sending_balance", "sending_balance_exp_decay", seed = 52)
})

test_that("receiving_balance_exp_decay matches brute force on small one-mode runs", {
  run_check("receiving_balance", "receiving_balance_exp_decay", seed = 53)
})

test_that("each closure family's exp_decay is 0 wherever its count is 0", {
  set.seed(54)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("cyclic_count", "cyclic_exp_decay",
                         "sending_balance_count", "sending_balance_exp_decay",
                         "receiving_balance_count", "receiving_balance_exp_decay"),
    endogenous_effects = c(cyclic_count = 0, cyclic_exp_decay = 0,
                            sending_balance_count = 0,
                            sending_balance_exp_decay = 0,
                            receiving_balance_count = 0,
                            receiving_balance_exp_decay = 0),
    half_life = 1)
  expect_true(all(ev$cyclic_exp_decay[ev$cyclic_count == 0] == 0))
  expect_true(all(ev$sending_balance_exp_decay[ev$sending_balance_count == 0] == 0))
  expect_true(all(ev$receiving_balance_exp_decay[ev$receiving_balance_count == 0] == 0))
})

test_that("half_life is required for each new exp_decay stat", {
  for (st in c("cyclic_exp_decay", "sending_balance_exp_decay",
               "receiving_balance_exp_decay")) {
    expect_error(
      simulate_relational_events(
        n_events = 5,
        senders = LETTERS[1:3], receivers = LETTERS[1:3],
        endogenous_stats = st,
        endogenous_effects = 0),
      "half_life",
      info = st)
  }
})

test_that("each new exp_decay stat errors on bipartite settings", {
  for (st in c("cyclic_exp_decay", "sending_balance_exp_decay",
               "receiving_balance_exp_decay")) {
    expect_error(
      simulate_relational_events(
        n_events = 5,
        senders = c("a", "b"), receivers = c("x", "y", "z"),
        endogenous_stats = st,
        endogenous_effects = 0.5,
        half_life = 1),
      "one-mode",
      info = st)
  }
})

test_that("each new exp_decay stat runs under tau-leap and stays non-negative", {
  set.seed(55)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = c("cyclic_exp_decay", "sending_balance_exp_decay",
                         "receiving_balance_exp_decay"),
    endogenous_effects = c(cyclic_exp_decay = 0,
                            sending_balance_exp_decay = 0,
                            receiving_balance_exp_decay = 0),
    half_life = 1,
    method = "tau_leap", tau = 0.02)
  expect_true(all(ev$cyclic_exp_decay >= 0))
  expect_true(all(ev$sending_balance_exp_decay >= 0))
  expect_true(all(ev$receiving_balance_exp_decay >= 0))
})

test_that("all four closure-family exp_decay stats compose in one call", {
  set.seed(56)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_exp_decay",
                         "cyclic_exp_decay",
                         "sending_balance_exp_decay",
                         "receiving_balance_exp_decay"),
    endogenous_effects = c(transitivity_exp_decay = 0,
                            cyclic_exp_decay = 0,
                            sending_balance_exp_decay = 0,
                            receiving_balance_exp_decay = 0),
    half_life = 1)
  for (st in c("transitivity_exp_decay", "cyclic_exp_decay",
               "sending_balance_exp_decay", "receiving_balance_exp_decay")) {
    expect_true(all(ev[[st]] >= 0), info = st)
  }
})
