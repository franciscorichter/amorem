# Tests for the sender_receivers_set statistic (issue #81, G2/G3): the set of
# receivers each sender has reached before a row, as a list-column, honouring
# history_log so it can be computed for non-events without polluting history.

test_that("G2: sender_receivers_set returns prior receivers per sender", {
  el <- data.frame(sender   = c("a", "a", "b", "a"),
                   receiver = c("x", "y", "x", "z"),
                   time     = 1:4, stringsAsFactors = FALSE)
  r <- compute_endogenous_features(el, stats = "sender_receivers_set")
  expect_type(r$sender_receivers_set, "list")
  expect_equal(r$sender_receivers_set[[1]], character(0))      # a, nothing prior
  expect_setequal(r$sender_receivers_set[[2]], "x")           # a -> {x}
  expect_equal(r$sender_receivers_set[[3]], character(0))      # b, nothing prior
  expect_setequal(r$sender_receivers_set[[4]], c("x", "y"))   # a -> {x, y}
})

test_that("G2: the set is de-duplicated and combines with other stats", {
  el <- data.frame(sender = "a", receiver = c("x", "x", "y", "z"), time = 1:4,
                   stringsAsFactors = FALSE)
  r <- compute_endogenous_features(
    el, stats = c("reciprocity_count", "sender_receivers_set"))
  expect_true(all(c("reciprocity_count", "sender_receivers_set") %in% names(r)))
  expect_type(r$sender_receivers_set, "list")
  # the set is evaluated *before* each row: row 3 (a -> y) sees {x}, de-duplicated
  # despite the two earlier a -> x events
  expect_setequal(r$sender_receivers_set[[3]], "x")
  expect_setequal(r$sender_receivers_set[[4]], c("x", "y"))    # then {x, y}
})

test_that("G3: non-events read the true history and do not pollute it", {
  combined <- data.frame(
    sender   = c("a", "a", "a", "a"),
    receiver = c("x", "z", "y", "w"),
    time     = c(1, 1.5, 2, 3),         # a->z @1.5 is a sampled non-event
    stringsAsFactors = FALSE)
  hist <- data.frame(sender = "a", receiver = c("x", "y", "w"),
                     time = c(1, 2, 3), stringsAsFactors = FALSE)  # real events only
  r <- compute_endogenous_features(combined, stats = "sender_receivers_set",
                                   history_log = hist)
  r <- r[order(r$time), ]
  # the non-event a->z @1.5 sees only the real prior receiver {x}
  expect_setequal(r$sender_receivers_set[[which(r$time == 1.5)]], "x")
  # the later real event a->w @3 sees {x, y} -- the non-event z did NOT pollute
  expect_setequal(r$sender_receivers_set[[which(r$time == 3)]], c("x", "y"))
})

test_that("G3: concurrent rows all read the pre-timestamp set (time-grouped)", {
  combined <- data.frame(sender = "a", receiver = c("x", "y", "q"),
                         time = c(1, 1, 1), stringsAsFactors = FALSE)
  hist <- data.frame(sender = "a", receiver = c("x", "y"), time = c(1, 1),
                     stringsAsFactors = FALSE)        # q is a non-event
  r <- compute_endogenous_features(combined, stats = "sender_receivers_set",
                                   history_log = hist)
  # nothing fires before t = 1, so every row's set is empty (no concurrent leak)
  for (i in seq_len(nrow(r))) expect_equal(r$sender_receivers_set[[i]], character(0))
})
