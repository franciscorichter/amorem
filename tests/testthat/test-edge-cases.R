# test-edge-cases.R
# Robustness sweep across degenerate and corner-case inputs. Exists to
# guarantee informative behaviour (clean error or sensible degenerate
# output) in regimes that real users will hit before hitting "happy
# path" usage.

# ----- simulate_relational_events() --------------------------------------

test_that("simulate_relational_events with n_events = 0 returns an empty data frame", {
  out <- simulate_relational_events(
    n_events = 0,
    senders   = LETTERS[1:3],
    receivers = LETTERS[1:3])
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0)
  expect_named(out, c("sender", "receiver", "time"))
})

test_that("simulate_relational_events errors when there is no admissible dyad", {
  # 1 actor universe + allow_loops = FALSE -> no admissible dyads
  expect_error(
    simulate_relational_events(
      n_events = 5,
      senders   = "A",
      receivers = "A",
      allow_loops = FALSE),
    "intensity|admissible|dyad")
})

test_that("simulate_relational_events with n_events = 1 produces exactly one row", {
  set.seed(1)
  out <- simulate_relational_events(
    n_events = 1,
    senders   = LETTERS[1:3],
    receivers = LETTERS[1:3])
  expect_equal(nrow(out), 1L)
  expect_true(out$time[1] > 0)
})

test_that("simulate_relational_events with no endogenous_stats produces a memoryless process", {
  set.seed(2)
  ev <- simulate_relational_events(
    n_events = 50,
    senders   = LETTERS[1:5],
    receivers = LETTERS[1:5],
    baseline_rate = 1,
    endogenous_stats = NULL)
  # Output should have exactly the three event columns, no endo state.
  expect_named(ev, c("sender", "receiver", "time"))
  # The inter-event times should look exponential with rate ~25 (= 5x5
  # dyads each at rate 1).
  dt <- diff(c(0, ev$time))
  expect_true(abs(mean(dt) - 1/25) < 0.05)
})

test_that("simulate_relational_events with empty endogenous_stats is the same as NULL", {
  set.seed(3)
  a <- simulate_relational_events(
    n_events = 30, senders = LETTERS[1:4], receivers = LETTERS[1:4],
    endogenous_stats = NULL)
  set.seed(3)
  b <- simulate_relational_events(
    n_events = 30, senders = LETTERS[1:4], receivers = LETTERS[1:4],
    endogenous_stats = character(0))
  expect_equal(a, b)
})

test_that("simulate_relational_events handles numeric actor labels via as.character", {
  set.seed(4)
  ev <- simulate_relational_events(
    n_events = 10,
    senders   = 1:4,
    receivers = 1:4)
  expect_type(ev$sender, "character")
  expect_type(ev$receiver, "character")
  expect_setequal(unique(ev$sender), as.character(1:4))
})

# ----- compute_endogenous_features() -------------------------------------

test_that("compute_endogenous_features on an empty event log returns the right shape", {
  empty <- data.frame(sender = character(0), receiver = character(0),
                      time = numeric(0))
  out <- compute_endogenous_features(empty,
                                      stats = c("reciprocity_count",
                                                "transitivity_count"))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_true(all(c("reciprocity_count", "transitivity_count") %in% names(out)))
})

test_that("compute_endogenous_features on a single-row event log produces zeros", {
  one <- data.frame(sender = "A", receiver = "B", time = 1)
  out <- compute_endogenous_features(one,
                                      stats = c("reciprocity_count",
                                                "transitivity_count",
                                                "reciprocity_time_recent"))
  expect_equal(out$reciprocity_count, 0)
  expect_equal(out$transitivity_count, 0)
  expect_true(is.na(out$reciprocity_time_recent))  # never-seen -> NA
})

test_that("compute_endogenous_features rejects unsupported stat names with a useful message", {
  log <- data.frame(sender = c("A", "B"), receiver = c("B", "A"), time = c(1, 2))
  expect_error(compute_endogenous_features(log, stats = "not_a_real_stat"),
               "Unsupported")
})

test_that("compute_endogenous_features handles ties in event times deterministically", {
  # Two events at the same timestamp -- the engine must process them in
  # row order and produce well-defined output (never an error).
  log <- data.frame(
    sender   = c("A", "B", "B"),
    receiver = c("B", "A", "A"),
    time     = c(1, 1, 2))
  out <- compute_endogenous_features(log,
                                      stats = c("reciprocity_count",
                                                "reciprocity_binary"))
  expect_equal(nrow(out), 3L)
  # Row 1: A -> B at t = 1; no prior reverse -> count 0.
  expect_equal(out$reciprocity_count[1], 0)
  # Row 2: B -> A at t = 1; row 1 (A -> B at t = 1) is the reverse and
  # is *prior* in row order, so reciprocity_count = 1.
  expect_equal(out$reciprocity_count[2], 1)
})

# ----- sample_non_events() -----------------------------------------------

test_that("sample_non_events errors on an empty event log", {
  empty <- data.frame(sender = character(0), receiver = character(0),
                      time = numeric(0))
  expect_error(sample_non_events(empty), "no rows")
})

test_that("sample_non_events on a single-row event log produces one stratum", {
  one <- data.frame(sender = "A", receiver = "B", time = 1,
                    stringsAsFactors = FALSE)
  # Need at least 2 actors so a non-event can be drawn.
  one2 <- data.frame(sender = c("A", "B"), receiver = c("B", "A"),
                     time = c(1, 2), stringsAsFactors = FALSE)
  out <- sample_non_events(one2, n_controls = 1, scope = "all",
                            mode = "one", seed = 1)
  expect_equal(length(unique(out$stratum)), 2L)
  expect_equal(sum(out$event == 1L), 2L)
  expect_equal(sum(out$event == 0L), 2L)
})

# ----- compare_models() ----------------------------------------------------

test_that("compare_models on a tiny event log still produces a tidy frame", {
  # Six-event toy log -- enough for one case-control per row.
  tiny <- data.frame(
    sender   = c("A", "B", "A", "C", "B", "A"),
    receiver = c("B", "A", "C", "A", "C", "B"),
    time     = 1:6)
  out <- compare_models(tiny,
                        models = list(
                          rec = c("reciprocity_count"),
                          tri = c("transitivity_count")),
                        seed = 1)
  expect_equal(nrow(out), 2L)
  expect_true(all(is.finite(out$AIC)))
})

# ----- standardize_event_log() ------------------------------------------

test_that("standardize_event_log on an empty raw log returns an empty tagged log", {
  empty <- data.frame(source = character(0), target = character(0),
                      ts = numeric(0))
  out <- standardize_event_log(empty,
                                sender_col = "source",
                                receiver_col = "target",
                                time_col = "ts",
                                drop_loops = TRUE)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
})
