# test-transform-recency.R

test_that("median rule maps zero to 1 and median to exp(-1/2)", {
  x <- c(0, 1, 2, 3, 4)
  w <- transform_recency(x)
  expect_equal(w[1], 1)
  expect_equal(w[3], exp(-1/2), tolerance = 1e-12)
  expect_true(all(w > 0 & w <= 1))
  expect_true(all(diff(w) < 0))
})

test_that("explicit half_life overrides the median rule", {
  x <- c(0, 1, 2, 4, 8)
  w <- transform_recency(x, half_life = 4)
  expect_equal(w, exp(-x / 4), tolerance = 1e-12)
})

test_that("reference argument fixes the scale", {
  train  <- c(1, 2, 3, 4, 5)
  newobs <- c(0, 2.5, 5, 10)
  m <- stats::median(train)
  expect_equal(transform_recency(newobs, reference = train),
               exp(-newobs / (2 * m)), tolerance = 1e-12)
})

test_that("NAs in delta propagate, NAs in reference are dropped", {
  x <- c(0, 1, NA_real_, 4)
  w <- transform_recency(x)
  expect_true(is.na(w[3]))
  expect_true(all(is.finite(w[-3])))
  expect_equal(transform_recency(c(0, 1),
                                  reference = c(1, NA, 3)),
               exp(-c(0, 1) / (2 * 2)), tolerance = 1e-12)
})

test_that("rejects malformed inputs", {
  expect_error(transform_recency("a"), "must be a numeric")
  expect_error(transform_recency(c(1, -1)), "non-negative")
  expect_error(transform_recency(c(1, 2), half_life = -1), "positive finite")
  expect_error(transform_recency(c(1, 2), half_life = c(1, 2)), "positive finite")
  expect_error(transform_recency(c(1, 2), reference = c(0, 0)),
               "must be positive and finite")
})
