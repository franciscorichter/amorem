# test-hyperedge-log.R
# Coverage for the hyperedge data-model primitives (Boschi+Lerner+Wit 2025).

test_that("hyperedge_log() validates inputs and sorts by time", {
  hl <- hyperedge_log(
    I    = list(c("b","a"), c("a","c")),
    J    = list(c("X"),      c("Y","Z")),
    time = c(2.5, 1.0))
  expect_s3_class(hl, "amorem_hyperedge_log")
  expect_equal(hl$time, c(1.0, 2.5))
  expect_equal(hl$J[[1]], c("Y", "Z"))   # sorted alongside time
  expect_true(is_hyperedge_log(hl))
})

test_that("hyperedge_log() rejects empty sender sets and non-character members", {
  expect_error(hyperedge_log(I = list(character(0)), J = list("x"), time = 1),
               "non-empty character")
  expect_error(hyperedge_log(I = list(1), J = list("x"), time = 1),
               "non-empty character")
})

test_that("undirected hyperevents (empty J) are accepted", {
  hl <- hyperedge_log(
    I    = list(c("a","b","c")),
    J    = list(character(0)),
    time = c(1.0))
  expect_equal(length(hl$J[[1]]), 0L)
})

test_that("as_hyperedge_log() round-trips a dyadic event log", {
  dy <- data.frame(sender = c("a","b","c"),
                   receiver = c("b","c","a"),
                   time = c(1,2,3),
                   stringsAsFactors = FALSE)
  h <- as_hyperedge_log(dy)
  expect_true(is_hyperedge_log(h))
  back <- as_dyadic_log(h)
  expect_equal(back$sender,   dy$sender)
  expect_equal(back$receiver, dy$receiver)
  expect_equal(back$time,     dy$time)
})

test_that("as_dyadic_log() rejects non-singleton sets", {
  hl <- hyperedge_log(
    I    = list(c("a","b")),
    J    = list("c"),
    time = c(1))
  expect_error(as_dyadic_log(hl), "non-singleton")
})

test_that("hyperedge_sizes() adds size_I and size_J", {
  hl <- hyperedge_log(
    I    = list(c("a","b"), "c"),
    J    = list(character(0), c("x","y","z")),
    time = c(1, 2))
  hl <- hyperedge_sizes(hl)
  expect_equal(hl$size_I, c(2L, 1L))
  expect_equal(hl$size_J, c(0L, 3L))
})
