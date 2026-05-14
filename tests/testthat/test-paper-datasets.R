# test-paper-datasets.R
# Smoke tests for the four datasets shipped with amore that come from
# the five real-world studies analysed in Juozaitienė & Wit (2024).
# (Enron is intentionally not shipped: the public source is aggregated
# daily counts, not the event-level slice used in the paper.)

test_that("classroom_events / classroom_actors load and have the expected shape", {
  data(classroom_events, envir = environment())
  data(classroom_actors, envir = environment())
  expect_s3_class(classroom_events, "data.frame")
  expect_named(classroom_events,
               c("time", "sender", "receiver", "interaction_type", "weight"))
  expect_true(nrow(classroom_events) > 600)
  expect_true(all(classroom_events$sender %in% classroom_actors$id))
  expect_true(all(classroom_events$receiver %in% classroom_actors$id))
  expect_true(!is.unsorted(classroom_events$time))
  expect_equal(nrow(classroom_actors), 20L)
  expect_setequal(levels(classroom_actors$role),
                  c("instructor", "grade_11", "grade_12"))
})

test_that("social_evolution_* tables load and reference a common actor universe", {
  data(social_evolution_calls,      envir = environment())
  data(social_evolution_actors,     envir = environment())
  data(social_evolution_friendship, envir = environment())
  expect_named(social_evolution_calls,
               c("time", "sender", "receiver", "increment"))
  expect_named(social_evolution_friendship,
               c("time", "sender", "receiver", "replace"))
  expect_true(nrow(social_evolution_calls) > 400)
  expect_equal(nrow(social_evolution_actors), 84L)
  expect_true(all(social_evolution_calls$sender %in% social_evolution_actors$id))
  expect_true(all(social_evolution_calls$receiver %in% social_evolution_actors$id))
  expect_true(!is.unsorted(social_evolution_calls$time))
  # Time was rebased to days; first row must be exactly zero.
  expect_equal(social_evolution_calls$time[1], 0)
  expect_true(!is.null(attr(social_evolution_calls, "unix_origin")))
})

test_that("radoslaw_email loads and is sorted in days-since-first-event", {
  data(radoslaw_email, envir = environment())
  expect_named(radoslaw_email, c("time", "sender", "receiver", "weight"))
  expect_true(nrow(radoslaw_email) > 80000)
  expect_equal(radoslaw_email$time[1], 0)
  expect_true(!is.unsorted(radoslaw_email$time))
  expect_true(!is.null(attr(radoslaw_email, "unix_origin")))
})

test_that("a shipped dataset feeds simulate_relational_events-shaped pipelines", {
  # Sanity check: the events tables conform to the (sender, receiver, time)
  # contract used elsewhere in the package, so they can be passed into
  # downstream summary helpers without renaming.
  data(classroom_events, envir = environment())
  expect_true(all(c("sender", "receiver", "time") %in% names(classroom_events)))
  expect_type(classroom_events$sender, "character")
  expect_type(classroom_events$receiver, "character")
  expect_type(classroom_events$time, "double")
})
