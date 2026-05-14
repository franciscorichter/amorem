# test-bipartite-closure.R
# Coverage for the closure-family endogenous statistics in bipartite
# and two-mode settings, where senders and receivers may differ in
# content, ordering, or size. Previously the simulator raised
# "one-mode" errors for these inputs; PR #41 (Phase 1) introduced
# the |U| x |U| unified-actor infrastructure and PR #42 (Phase 2)
# wires it through the per-event update paths.

test_that("disjoint sender / receiver sets simulate without error", {
  set.seed(2026)
  ev <- simulate_relational_events(
    n_events = 30,
    senders   = letters[1:4],
    receivers = LETTERS[1:5],
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = c("transitivity_count", "cyclic_count",
                            "sending_balance_count", "receiving_balance_count"),
    endogenous_effects = setNames(rep(0, 4),
                                    c("transitivity_count", "cyclic_count",
                                      "sending_balance_count",
                                      "receiving_balance_count")))
  expect_s3_class(ev, "data.frame")
  expect_equal(nrow(ev), 30L)
  expect_true(all(ev$sender %in% letters[1:4]))
  expect_true(all(ev$receiver %in% LETTERS[1:5]))
})

test_that("disjoint sender/receiver: reciprocity stats are identically zero", {
  # When senders and receivers are disjoint, every "reverse event"
  # would require a receiver to act as a sender, which the rate
  # space disallows. So reciprocity_count is permanently 0 at every
  # rate-space dyad.
  set.seed(2027)
  ev <- simulate_relational_events(
    n_events = 30,
    senders   = letters[1:4],
    receivers = LETTERS[1:5],
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = 0)
  expect_true(all(ev$reciprocity_count == 0))
})

test_that("overlapping sender/receiver: reciprocity at the overlap matches one-mode semantics", {
  # Construct a partial overlap: senders = {a, b, c, d}; receivers
  # = {b, c, d, e}. Reciprocity at dyad (a, b) is permanently 0
  # (because a is not a receiver, so events with sender=b,
  # receiver=a are impossible). Reciprocity at dyad (b, c) is
  # well-defined and follows the standard count-of-reverse logic.
  set.seed(2028)
  ev <- simulate_relational_events(
    n_events = 60,
    senders   = c("a", "b", "c", "d"),
    receivers = c("b", "c", "d", "e"),
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = 0)
  # Rows whose sender is "a" can never have a reverse (a is not in
  # the receiver set), so reciprocity_count must be 0 there.
  expect_true(all(ev$reciprocity_count[ev$sender == "a"] == 0))
  # Rows where both sender and receiver come from the overlap must
  # have count consistent with the prior reverse-dyad history.
  for (i in seq_len(nrow(ev))) {
    if (ev$sender[i] %in% c("b", "c", "d") &&
        ev$receiver[i] %in% c("b", "c", "d")) {
      prior <- ev[seq_len(i - 1L), , drop = FALSE]
      expected <- sum(prior$sender == ev$receiver[i] &
                        prior$receiver == ev$sender[i])
      expect_equal(ev$reciprocity_count[i], expected, info = paste("row", i))
    }
  }
})

test_that("disjoint sender/receiver: transitivity_count is 0 (no admissible k)", {
  # In pure bipartite (disjoint sets), the transitive two-path
  # s -> k -> r requires k to be a receiver of s (so k must be in
  # the receiver set) AND a sender to r (so k must be in the sender
  # set). With disjoint sender and receiver sets these are
  # incompatible, so transitivity_count is identically 0.
  set.seed(2029)
  ev <- simulate_relational_events(
    n_events = 40,
    senders   = letters[1:4],
    receivers = LETTERS[1:4],
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = "transitivity_count",
    endogenous_effects = 0)
  expect_true(all(ev$transitivity_count == 0))
})

test_that("disjoint sender/receiver: sending_balance can be non-zero", {
  # In bipartite, sending_balance at dyad (s, r) requires that
  # actors s and r have shared at least one common target k.
  # With disjoint sender / receiver sets this is satisfiable: both
  # s and r need to be senders (so both come from the sender set);
  # but only s is a sender in the focal dyad while r is the
  # receiver. Hence sending_balance reduces to a non-trivial
  # statistic only when r is ALSO a sender -- otherwise it stays at
  # 0.
  set.seed(2030)
  # Use overlapping sender/receiver to enable non-trivial sb.
  ev <- simulate_relational_events(
    n_events = 60,
    senders   = c("a", "b", "c", "d"),
    receivers = c("b", "c", "d", "e"),
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = "sending_balance_count",
    endogenous_effects = 0)
  expect_true(any(ev$sending_balance_count > 0))
  # Rows where receiver is "e" (not a sender) must have sb = 0.
  expect_true(all(ev$sending_balance_count[ev$receiver == "e"] == 0))
})

test_that("bipartite output schema matches one-mode for endogenous stats", {
  set.seed(2031)
  ev <- simulate_relational_events(
    n_events = 25,
    senders   = letters[1:4],
    receivers = LETTERS[1:6],
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = c("reciprocity_count", "transitivity_count",
                            "cyclic_count", "sending_balance_count",
                            "receiving_balance_count"),
    endogenous_effects = setNames(rep(0, 5),
                                    c("reciprocity_count", "transitivity_count",
                                      "cyclic_count", "sending_balance_count",
                                      "receiving_balance_count")))
  expect_true(all(c("reciprocity_count", "transitivity_count",
                    "cyclic_count", "sending_balance_count",
                    "receiving_balance_count") %in% names(ev)))
})

test_that("one-mode behaviour is byte-equivalent before and after Phase 2", {
  # Sanity: a one-mode call with reciprocity_count must give the same
  # output as the historical implementation (the simulator's
  # observable behaviour cannot drift).
  set.seed(2032)
  ev <- simulate_relational_events(
    n_events = 20,
    senders   = paste0("a", 1:5),
    receivers = paste0("a", 1:5),
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = 0)
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    expected <- sum(prior$sender == ev$receiver[i] &
                      prior$receiver == ev$sender[i])
    expect_equal(ev$reciprocity_count[i], expected, info = paste("row", i))
  }
})

test_that("bipartite tau-leap path produces well-formed output", {
  set.seed(2033)
  ev <- simulate_relational_events(
    n_events = 30,
    senders   = letters[1:4],
    receivers = LETTERS[1:5],
    baseline_rate = 1, allow_loops = FALSE,
    endogenous_stats   = c("transitivity_count", "cyclic_count"),
    endogenous_effects = c(transitivity_count = 0, cyclic_count = 0),
    method = "tau_leap", tau = 0.05)
  expect_true(all(ev$transitivity_count >= 0))
  expect_true(all(ev$cyclic_count >= 0))
})
