test_that("bundled hyperedge logs satisfy hyperedge_log()'s distinct-actor rule", {
  data(congress_bills_118, package = "amorem", envir = environment())
  x <- congress_bills_118
  expect_false(any(vapply(x$I, function(v) anyDuplicated(v) > 0, logical(1))))
  expect_false(any(vapply(x$J, function(v) anyDuplicated(v) > 0, logical(1))))
  expect_no_error(hyperedge_log(I = x$I, J = x$J, time = x$time))
})
