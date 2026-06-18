# test-sim-vs-posthoc-parity.R
# Cross-validation: for every endogenous statistic that both the
# simulator and endogenous_features() support, the two paths
# must agree row-by-row on the same event log.
#
# The simulator computes each stat at the time the event fires
# (immediately before it fires). endogenous_features() does
# the same when applied to the resulting event table. If both
# implementations follow paper semantics they must produce identical
# columns.

# Helper: run the simulator with the given stats list, then strip the
# endogenous columns and re-compute them post-hoc. Returns a list with
# the two data frames keyed by stat name. By default uses a one-mode
# network of `n_actors` LETTERS, but the senders / receivers vectors
# can be overridden directly to exercise bipartite or two-mode
# configurations.
sim_vs_posthoc <- function(stats, seed = 11, n_events = 25,
                            n_actors = 5, half_life = NULL,
                            baseline_rate = 3,
                            senders = NULL, receivers = NULL) {
  set.seed(seed)
  effs <- setNames(rep(0, length(stats)), stats)
  if (is.null(senders))   senders   <- LETTERS[1:n_actors]
  if (is.null(receivers)) receivers <- LETTERS[1:n_actors]
  args <- list(
    n_events = n_events,
    senders = senders,
    receivers = receivers,
    baseline_rate = baseline_rate,
    endogenous_stats = stats,
    endogenous_effects = effs
  )
  if (!is.null(half_life)) args$half_life <- half_life
  ev <- do.call(simulate_relational_events, args)
  base <- ev[, c("sender", "receiver", "time")]
  feats <- endogenous_features(base, stats = stats,
                                        half_life = half_life)
  list(sim = ev, posthoc = feats)
}

# Per-stat equality with a small tolerance. endogenous_features()
# returns NA for never-observed timing slots; the simulator returns 0.
# Treat the two as equivalent (the simulator's 0 means "no such
# two-path yet", same condition that triggers NA post-hoc).
expect_columns_match <- function(sim, ph, stat) {
  v_sim <- sim[[stat]]
  v_ph  <- ph[[stat]]
  expect_false(is.null(v_sim), info = paste("simulator missing", stat))
  expect_false(is.null(v_ph),  info = paste("post-hoc missing",  stat))
  v_ph[is.na(v_ph)] <- 0
  expect_equal(v_sim, v_ph, tolerance = 1e-9, info = stat)
}

test_that("simulator and post-hoc agree on reciprocity-family stats", {
  stats <- c("reciprocity_binary", "reciprocity_count",
             "reciprocity_exp_decay",
             "reciprocity_time_recent", "reciprocity_time_first")
  out <- sim_vs_posthoc(stats, seed = 101, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on interrupted reciprocity stats", {
  stats <- c("reciprocity_binary_interrupted", "reciprocity_count_interrupted",
             "reciprocity_exp_decay_interrupted",
             "reciprocity_time_recent_interrupted",
             "reciprocity_time_first_interrupted")
  out <- sim_vs_posthoc(stats, seed = 111, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on transitivity unordered stats", {
  stats <- c("transitivity_binary", "transitivity_count",
             "transitivity_time_recent", "transitivity_time_first",
             "transitivity_exp_decay")
  out <- sim_vs_posthoc(stats, seed = 102, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on transitivity ordered stats", {
  stats <- c("transitivity_binary_ordered", "transitivity_count_ordered",
             "transitivity_time_recent_ordered",
             "transitivity_time_first_ordered",
             "transitivity_exp_decay_ordered")
  out <- sim_vs_posthoc(stats, seed = 103, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on cyclic stats", {
  stats <- c("cyclic_binary", "cyclic_count",
             "cyclic_time_recent", "cyclic_time_first",
             "cyclic_exp_decay")
  out <- sim_vs_posthoc(stats, seed = 104, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on sending_balance stats", {
  stats <- c("sending_balance_binary", "sending_balance_count",
             "sending_balance_time_recent", "sending_balance_time_first",
             "sending_balance_exp_decay")
  out <- sim_vs_posthoc(stats, seed = 105, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on receiving_balance stats", {
  stats <- c("receiving_balance_binary", "receiving_balance_count",
             "receiving_balance_time_recent", "receiving_balance_time_first",
             "receiving_balance_exp_decay")
  out <- sim_vs_posthoc(stats, seed = 106, half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on interrupted triadic timing stats", {
  stats <- c("transitivity_time_recent_interrupted",
             "transitivity_time_first_interrupted",
             "cyclic_time_recent_interrupted",
             "cyclic_time_first_interrupted",
             "sending_balance_time_recent_interrupted",
             "sending_balance_time_first_interrupted",
             "receiving_balance_time_recent_interrupted",
             "receiving_balance_time_first_interrupted")
  out <- sim_vs_posthoc(stats, seed = 121)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("simulator and post-hoc agree on per-actor / single-direction stats", {
  stats <- c("sender_outdegree", "receiver_indegree", "recency")
  set.seed(107)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = stats,
    endogenous_effects = setNames(rep(0, length(stats)), stats)
  )
  base <- ev[, c("sender", "receiver", "time")]
  feats <- endogenous_features(base, stats = stats)
  # `recency`: simulator initialises to `start_time` so the elapsed
  # time at row 1 is the event time - start_time = the event time
  # (start_time defaults to 0). Post-hoc returns NA for never-seen
  # dyads; coerce NA -> sim value (= the event time on the first
  # firing of each dyad) only on the first occurrence of each dyad.
  feats$recency[is.na(feats$recency)] <- ev$recency[is.na(feats$recency)]
  for (st in stats) expect_equal(ev[[st]], feats[[st]], tolerance = 1e-9,
                                  info = st)
})

test_that("simulator and post-hoc agree on a mixed cross-family stat bundle", {
  stats <- c("reciprocity_count", "reciprocity_time_recent",
             "transitivity_count", "transitivity_time_recent",
             "cyclic_count", "cyclic_time_recent",
             "sending_balance_count", "sending_balance_time_recent",
             "sender_outdegree", "receiver_indegree")
  out <- sim_vs_posthoc(stats, seed = 108)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

# ---- Bipartite parity --------------------------------------------------
#
# The simulator's closure-family state machinery is sized |U| x |U|
# over the unified actor universe; the post-hoc engine keys its
# event history by literal string identifiers so it is naturally
# universe-agnostic. The blocks below pin both paths together on
# bipartite / two-mode inputs by checking that the two produce
# identical columns on event logs that the simulator generates with
# disjoint or overlapping sender / receiver sets.

test_that("disjoint sender/receiver: counts agree across all closure families", {
  stats <- c("reciprocity_count", "transitivity_count",
             "cyclic_count", "sending_balance_count",
             "receiving_balance_count")
  out <- sim_vs_posthoc(stats, seed = 201,
                        senders   = letters[1:4],
                        receivers = LETTERS[1:5])
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("disjoint sender/receiver: timing stats agree across all closure families", {
  stats <- c("transitivity_time_recent", "transitivity_time_first",
             "cyclic_time_recent", "cyclic_time_first",
             "sending_balance_time_recent", "sending_balance_time_first",
             "receiving_balance_time_recent", "receiving_balance_time_first")
  out <- sim_vs_posthoc(stats, seed = 202,
                        senders   = letters[1:4],
                        receivers = LETTERS[1:5])
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("disjoint sender/receiver: exp_decay stats agree across all closure families", {
  stats <- c("transitivity_exp_decay", "cyclic_exp_decay",
             "sending_balance_exp_decay", "receiving_balance_exp_decay")
  out <- sim_vs_posthoc(stats, seed = 203,
                        senders   = letters[1:4],
                        receivers = LETTERS[1:5],
                        half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("disjoint sender/receiver: interrupted variants agree", {
  stats <- c("reciprocity_count_interrupted",
             "reciprocity_time_recent_interrupted",
             "transitivity_time_recent_interrupted",
             "cyclic_time_recent_interrupted",
             "sending_balance_time_recent_interrupted",
             "receiving_balance_time_recent_interrupted")
  out <- sim_vs_posthoc(stats, seed = 204,
                        senders   = letters[1:4],
                        receivers = LETTERS[1:5])
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("overlapping sender/receiver: reciprocity-family stats agree", {
  # Partial overlap: senders = {a, b, c, d}, receivers = {b, c, d, e}.
  # The overlap is {b, c, d}; reciprocity at dyads inside the overlap
  # is non-trivial, and reciprocity at dyads that touch only the
  # non-overlapping actors (a, e) is identically zero.
  stats <- c("reciprocity_binary", "reciprocity_count",
             "reciprocity_exp_decay",
             "reciprocity_time_recent", "reciprocity_time_first")
  out <- sim_vs_posthoc(stats, seed = 205,
                        senders   = c("a", "b", "c", "d"),
                        receivers = c("b", "c", "d", "e"),
                        half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})

test_that("overlapping sender/receiver: ordered transitivity stats agree", {
  stats <- c("transitivity_binary_ordered", "transitivity_count_ordered",
             "transitivity_time_recent_ordered",
             "transitivity_time_first_ordered",
             "transitivity_exp_decay_ordered")
  out <- sim_vs_posthoc(stats, seed = 206,
                        senders   = c("a", "b", "c", "d"),
                        receivers = c("b", "c", "d", "e"),
                        half_life = 1)
  for (st in stats) expect_columns_match(out$sim, out$posthoc, st)
})
