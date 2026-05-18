# test-cpp-inner-loop.R
# Verifies that the C++ inner loop produces output bit-equivalent to
# the pure-R reference path for every statistic it supports, on both
# one-mode and bipartite event logs.

cpp_supported_subset <- c("reciprocity_binary", "reciprocity_count",
                           "transitivity_binary", "transitivity_count",
                           "cyclic_binary", "cyclic_count",
                           "sending_balance_binary", "sending_balance_count",
                           "receiving_balance_binary", "receiving_balance_count",
                           "sender_outdegree", "receiver_indegree",
                           "recency",
                           "transitivity_time_recent", "transitivity_time_first",
                           "cyclic_time_recent", "cyclic_time_first",
                           "sending_balance_time_recent",
                           "sending_balance_time_first",
                           "receiving_balance_time_recent",
                           "receiving_balance_time_first",
                           "transitivity_exp_decay",
                           "cyclic_exp_decay",
                           "sending_balance_exp_decay",
                           "receiving_balance_exp_decay",
                           "transitivity_count_interrupted",
                           "transitivity_binary_interrupted",
                           "transitivity_exp_decay_interrupted",
                           "transitivity_time_recent_interrupted",
                           "transitivity_time_first_interrupted",
                           "cyclic_count_interrupted",
                           "cyclic_binary_interrupted",
                           "cyclic_exp_decay_interrupted",
                           "cyclic_time_recent_interrupted",
                           "cyclic_time_first_interrupted",
                           "sending_balance_count_interrupted",
                           "sending_balance_binary_interrupted",
                           "sending_balance_exp_decay_interrupted",
                           "sending_balance_time_recent_interrupted",
                           "sending_balance_time_first_interrupted",
                           "receiving_balance_count_interrupted",
                           "receiving_balance_binary_interrupted",
                           "receiving_balance_exp_decay_interrupted",
                           "receiving_balance_time_recent_interrupted",
                           "receiving_balance_time_first_interrupted")

# Stats whose unset cells are NA rather than 0. Both engines emit NA
# on rows where no qualifying past event exists; row-for-row
# expect_equal does that anyway, but documenting here for clarity.
cpp_na_capable <- c("recency",
                    "transitivity_time_recent", "transitivity_time_first",
                    "cyclic_time_recent", "cyclic_time_first",
                    "sending_balance_time_recent", "sending_balance_time_first",
                    "receiving_balance_time_recent", "receiving_balance_time_first",
                    "transitivity_time_recent_interrupted",
                    "transitivity_time_first_interrupted",
                    "cyclic_time_recent_interrupted",
                    "cyclic_time_first_interrupted",
                    "sending_balance_time_recent_interrupted",
                    "sending_balance_time_first_interrupted",
                    "receiving_balance_time_recent_interrupted",
                    "receiving_balance_time_first_interrupted")

call_cpp <- function(ev, stats, half_life = NA_real_) {
  compute_features_cpp(as.character(ev$sender),
                       as.character(ev$receiver),
                       as.numeric(ev$time),
                       stats,
                       half_life)
}

build_reference <- function(ev, stats, half_life = NULL) {
  # Force the pure-R path by appending an unsupported stat
  # (reciprocity_time_recent is R-only).
  feat <- compute_endogenous_features(
    ev, stats = c(stats, "reciprocity_time_recent"),
    half_life = half_life)
  feat
}

needs_half_life <- function(st) grepl("_exp_decay($|_)", st)

test_that("C++ path agrees with R reference on one-mode supported stats", {
  set.seed(2050)
  ev <- simulate_relational_events(
    n_events = 60, senders = LETTERS[1:6], receivers = LETTERS[1:6],
    baseline_rate = 1, allow_loops = FALSE)
  base <- ev[, c("sender", "receiver", "time")]
  for (st in cpp_supported_subset) {
    hl <- if (needs_half_life(st)) 5 else NA_real_
    cpp_v <- call_cpp(base, st, hl)[[st]]
    r_ref <- build_reference(base, st,
                              if (needs_half_life(st)) hl else NULL)[[st]]
    if (st %in% cpp_na_capable) {
      # NA on rows where no qualifying past event exists; both engines
      # must agree on the NA mask and the non-NA values.
      expect_equal(is.na(cpp_v), is.na(r_ref), info = st)
      ok <- !is.na(cpp_v) & !is.na(r_ref)
      expect_equal(cpp_v[ok], r_ref[ok], tolerance = 1e-9, info = st)
    } else {
      expect_equal(cpp_v, r_ref, tolerance = 1e-9, info = st)
    }
  }
})

test_that("C++ path agrees with R reference on bipartite count/binary stats", {
  set.seed(2051)
  ev <- simulate_relational_events(
    n_events = 50,
    senders   = letters[1:4],
    receivers = LETTERS[1:5],
    baseline_rate = 1, allow_loops = FALSE)
  base <- ev[, c("sender", "receiver", "time")]
  for (st in c("reciprocity_count", "transitivity_count", "cyclic_count",
               "sending_balance_count", "receiving_balance_count",
               "sender_outdegree", "receiver_indegree")) {
    cpp_v <- call_cpp(base, st)[[st]]
    r_ref <- build_reference(base, st)[[st]]
    expect_equal(cpp_v, r_ref, tolerance = 1e-9, info = st)
  }
})

test_that("C++ timing variants agree with R reference across the four families", {
  set.seed(2052)
  ev <- simulate_relational_events(
    n_events = 80, senders = LETTERS[1:6], receivers = LETTERS[1:6],
    baseline_rate = 1, allow_loops = FALSE)
  base <- ev[, c("sender", "receiver", "time")]
  for (st in c("transitivity_time_recent", "transitivity_time_first",
               "cyclic_time_recent", "cyclic_time_first",
               "sending_balance_time_recent", "sending_balance_time_first",
               "receiving_balance_time_recent", "receiving_balance_time_first")) {
    cpp_v <- call_cpp(base, st)[[st]]
    r_ref <- build_reference(base, st)[[st]]
    expect_equal(is.na(cpp_v), is.na(r_ref), info = st)
    ok <- !is.na(cpp_v) & !is.na(r_ref)
    expect_equal(cpp_v[ok], r_ref[ok], tolerance = 1e-9, info = st)
  }
})

test_that("C++ dispatches on a mixed timing+count stat set", {
  # The fast-path predicate requires every requested stat to be in
  # cpp_supported_stats(). Includes one timing variant per family.
  data(classroom_events)
  stats <- c("reciprocity_count",
             "transitivity_count", "transitivity_time_recent",
             "cyclic_count", "cyclic_time_recent",
             "sending_balance_time_first",
             "receiving_balance_time_first")
  out_fast <- compute_endogenous_features(classroom_events, stats = stats)
  out_ref  <- build_reference(classroom_events, stats)
  for (st in stats) {
    cpp_v <- out_fast[[st]]; r_ref <- out_ref[[st]]
    expect_equal(is.na(cpp_v), is.na(r_ref), info = st)
    ok <- !is.na(cpp_v) & !is.na(r_ref)
    expect_equal(cpp_v[ok], r_ref[ok], tolerance = 1e-9, info = st)
  }
})

test_that("C++ exp_decay variants agree with R reference across families", {
  set.seed(2053)
  ev <- simulate_relational_events(
    n_events = 80, senders = LETTERS[1:6], receivers = LETTERS[1:6],
    baseline_rate = 1, allow_loops = FALSE)
  base <- ev[, c("sender", "receiver", "time")]
  for (st in c("transitivity_exp_decay", "cyclic_exp_decay",
               "sending_balance_exp_decay", "receiving_balance_exp_decay")) {
    cpp_v <- call_cpp(base, st, half_life = 7)[[st]]
    r_ref <- build_reference(base, st, half_life = 7)[[st]]
    expect_equal(cpp_v, r_ref, tolerance = 1e-9, info = st)
  }
})

test_that("C++ dispatch covers a mixed timing+count+exp_decay stat set", {
  data(classroom_events)
  stats <- c("reciprocity_count",
             "transitivity_time_recent", "transitivity_exp_decay",
             "cyclic_exp_decay",
             "sending_balance_time_first",
             "receiving_balance_exp_decay")
  out_fast <- compute_endogenous_features(classroom_events,
                                            stats = stats, half_life = 30)
  out_ref  <- build_reference(classroom_events, stats, half_life = 30)
  for (st in stats) {
    cpp_v <- out_fast[[st]]; r_ref <- out_ref[[st]]
    expect_equal(is.na(cpp_v), is.na(r_ref), info = st)
    ok <- !is.na(cpp_v) & !is.na(r_ref)
    expect_equal(cpp_v[ok], r_ref[ok], tolerance = 1e-9, info = st)
  }
})

test_that("C++ exp_decay errors out when half_life is missing", {
  data(classroom_events)
  expect_error(
    compute_features_cpp(as.character(classroom_events$sender),
                         as.character(classroom_events$receiver),
                         as.numeric(classroom_events$time),
                         "transitivity_exp_decay"),
    regexp = "half_life")
})

test_that("compute_endogenous_features dispatches to C++ when the stat set allows", {
  data(classroom_events)
  stats <- c("reciprocity_count", "transitivity_count",
             "sender_outdegree", "receiver_indegree")
  # The dispatch should pick C++ for this stats list. We verify only
  # the result equals the R reference (forced by including an
  # unsupported stat).
  out_fast <- compute_endogenous_features(classroom_events, stats = stats)
  out_ref  <- build_reference(classroom_events, stats)
  for (st in stats) {
    expect_equal(out_fast[[st]], out_ref[[st]], tolerance = 1e-9, info = st)
  }
})

test_that("cpp_supported_stats returns the documented support set", {
  expect_setequal(cpp_supported_stats(),
                  c(cpp_supported_subset, "reciprocity"))
})
