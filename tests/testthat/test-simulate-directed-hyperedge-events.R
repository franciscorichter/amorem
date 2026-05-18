# test-simulate-directed-hyperedge-events.R
# Coverage for simulate_directed_hyperedge_events() -- two-mode
# directed counterpart of simulate_hyperedge_events()
# (Boschi+Lerner+Wit 2025 Section 5).

test_that("output is a directed hyperedge log with non-empty J", {
  set.seed(11)
  hl <- simulate_directed_hyperedge_events(
    n_events  = 25,
    senders   = paste0("a", 1:4),
    receivers = paste0("p", 1:4),
    max_size_I = 2, max_size_J = 2,
    baseline_rate = 0.3,
    endogenous_stats   = "size_I",
    endogenous_effects = c(size_I = -0.5))
  expect_true(is_hyperedge_log(hl))
  expect_equal(nrow(hl), 25L)
  expect_true(all(vapply(hl$J, length, integer(1)) >= 1L))
  expect_true(all(vapply(hl$I, length, integer(1)) >= 1L))
  # Times strictly increasing.
  expect_true(all(diff(hl$time) > 0))
})

test_that("size penalties shape the cardinality distribution", {
  set.seed(12)
  hl <- simulate_directed_hyperedge_events(
    n_events  = 60,
    senders   = paste0("a", 1:4),
    receivers = paste0("p", 1:4),
    max_size_I = 3, max_size_J = 3,
    baseline_rate = 0.5,
    endogenous_stats   = c("size_I", "size_J"),
    endogenous_effects = c(size_I = -3, size_J = -3))
  size_I <- vapply(hl$I, length, integer(1))
  size_J <- vapply(hl$J, length, integer(1))
  expect_gt(mean(size_I == 1L), 0.6)
  expect_gt(mean(size_J == 1L), 0.6)
})

test_that("rejects malformed inputs", {
  expect_error(simulate_directed_hyperedge_events(
    0, "a", "b", baseline_rate = 1), "positive integer")
  expect_error(simulate_directed_hyperedge_events(
    5, character(0), "b", baseline_rate = 1), "non-empty")
  expect_error(simulate_directed_hyperedge_events(
    5, "a", character(0), baseline_rate = 1), "non-empty")
  expect_error(simulate_directed_hyperedge_events(
    5, "a", "b", baseline_rate = 1,
    endogenous_stats = "bogus", endogenous_effects = 0),
    "Unsupported")
  expect_error(simulate_directed_hyperedge_events(
    5, "a", "b", baseline_rate = 1, endogenous_stats = "size_I",
    endogenous_effects = c(1, 2)), "same length")
  expect_error(simulate_directed_hyperedge_events(
    5, c("a","b"), c("p","q"), max_size_I = 0,
    baseline_rate = 1), "min <= max")
})

test_that("subrep_<rho>_<l> stats run when rho/l fit the focal cardinality", {
  set.seed(13)
  hl <- simulate_directed_hyperedge_events(
    n_events  = 30,
    senders   = paste0("a", 1:3),
    receivers = paste0("p", 1:3),
    min_size_I = 2, max_size_I = 2,
    min_size_J = 1, max_size_J = 1,
    baseline_rate = 0.3,
    endogenous_stats   = c("subrep_1_1", "size_I"),
    endogenous_effects = c(subrep_1_1 = 0.5, size_I = 0))
  expect_equal(nrow(hl), 30L)
})

test_that("a degenerate case (singleton I and J) collapses to dyadic", {
  set.seed(14)
  hl <- simulate_directed_hyperedge_events(
    n_events  = 20,
    senders   = c("a", "b", "c"),
    receivers = c("x", "y", "z"),
    max_size_I = 1, max_size_J = 1,
    baseline_rate = 1)
  expect_true(all(vapply(hl$I, length, integer(1)) == 1L))
  expect_true(all(vapply(hl$J, length, integer(1)) == 1L))
  # Should be round-trippable to a dyadic event log.
  dy <- as_dyadic_log(hl)
  expect_equal(nrow(dy), 20L)
})
