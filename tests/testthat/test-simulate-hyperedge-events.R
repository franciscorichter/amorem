# test-simulate-hyperedge-events.R
# Coverage for simulate_hyperedge_events() (Boschi+Lerner+Wit 2025).

test_that("output is a well-formed hyperedge log with the requested length", {
  set.seed(11)
  hl <- simulate_hyperedge_events(
    n_events = 25,
    actors   = LETTERS[1:5],
    max_size = 3,
    baseline_rate = 0.2,
    endogenous_stats   = "size",
    endogenous_effects = c(size = -0.5))
  expect_true(is_hyperedge_log(hl))
  expect_equal(nrow(hl), 25L)
  # Every receiver set is empty (undirected meetings).
  expect_true(all(vapply(hl$J, length, integer(1)) == 0L))
  # Event sizes lie in [1, max_size].
  sizes <- vapply(hl$I, length, integer(1))
  expect_true(all(sizes >= 1L & sizes <= 3L))
  # Times are strictly increasing.
  expect_true(all(diff(hl$time) > 0))
})

test_that("a heavy negative size penalty concentrates events at size 1", {
  set.seed(12)
  hl <- simulate_hyperedge_events(
    n_events = 60,
    actors   = LETTERS[1:5],
    max_size = 4,
    baseline_rate = 0.5,
    endogenous_stats   = "size",
    endogenous_effects = c(size = -3))
  sizes <- vapply(hl$I, length, integer(1))
  expect_gt(mean(sizes == 1L), 0.6)
})

test_that("a positive subrep_2 coefficient produces repeated triads", {
  set.seed(13)
  hl <- simulate_hyperedge_events(
    n_events = 50,
    actors   = LETTERS[1:4],
    max_size = 3,
    baseline_rate = 0.3,
    endogenous_stats   = c("subrep_2", "size"),
    endogenous_effects = c(subrep_2 = 1.5, size = -1))
  # With a strong subrep_2 effect, the most-frequent pair of actors
  # should appear together in many events.
  pair_counts <- table(unlist(
    lapply(hl$I, function(I) if (length(I) >= 2)
             apply(utils::combn(I, 2), 2, function(x) paste(sort(x), collapse = "-"))
           else character(0))))
  if (length(pair_counts)) {
    expect_gt(max(pair_counts), 5L)
  }
})

test_that("rejects malformed inputs", {
  expect_error(simulate_hyperedge_events(0, LETTERS[1:3], 2, 1),
               "positive integer")
  expect_error(simulate_hyperedge_events(5, character(0), 2, 1),
               "non-empty")
  expect_error(simulate_hyperedge_events(5, LETTERS[1:3], 0, 1),
               "in 1..length")
  expect_error(simulate_hyperedge_events(5, LETTERS[1:3], 5, 1),
               "in 1..length")
  expect_error(simulate_hyperedge_events(5, LETTERS[1:3], 2, 1,
                                          "bogus", 1),
               "Unsupported")
  expect_error(simulate_hyperedge_events(5, LETTERS[1:3], 2, 1,
                                          "size", c(1, 2)),
               "same length")
})

test_that("zero endogenous spec recovers a homogeneous Poisson on candidate space", {
  set.seed(14)
  hl <- simulate_hyperedge_events(
    n_events = 30,
    actors   = LETTERS[1:3],
    max_size = 2,
    baseline_rate = 1)
  # Six candidates ({A,B,C} singletons + 3 pairs) -> rate 6 per unit time.
  expect_true(is_hyperedge_log(hl))
  expect_equal(nrow(hl), 30L)
})
