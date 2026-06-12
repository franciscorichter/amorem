# test-martingale-residuals.R

test_that("residuals sum to zero within stratum and have expected shape", {
  data(classroom_events)
  res <- martingale_residuals(
    classroom_events,
    model = c(reciprocity_count  = "linear",
              transitivity_count = "linear"),
    seed = 7)
  # Two rows per stratum (case + control).
  expect_equal(nrow(res), 2 * nrow(classroom_events))
  expect_named(res, c("stratum", "role", "sender", "receiver",
                      "time", "eta", "fitted_prob", "residual"))
  # The two roles per stratum sum to zero in residual.
  by_stratum <- tapply(res$residual, res$stratum, sum)
  expect_true(all(abs(by_stratum) < 1e-10))
  # Fitted probs in (0, 1) and sum to 1 within stratum.
  expect_true(all(res$fitted_prob > 0 & res$fitted_prob < 1))
  by_stratum <- tapply(res$fitted_prob, res$stratum, sum)
  expect_true(all(abs(by_stratum - 1) < 1e-10))
})

test_that("a well-calibrated model has approximately mean-zero residuals", {
  data(classroom_events)
  res <- martingale_residuals(
    classroom_events,
    model = c(reciprocity_count  = "linear",
              transitivity_count = "linear"),
    seed = 7)
  # Mean across all observations (cases and controls) is exactly zero
  # by construction of the case-control logistic fit.
  expect_lt(abs(mean(res$residual)), 1e-10)
  # Mean residual for cases equals -mean for controls.
  m_case <- mean(res$residual[res$role == "case"])
  m_ctrl <- mean(res$residual[res$role == "control"])
  expect_lt(abs(m_case + m_ctrl), 1e-10)
})

test_that("reproducible under fixed seed", {
  data(classroom_events)
  spec <- c(reciprocity_count = "linear")
  a <- martingale_residuals(classroom_events, spec, seed = 42)
  b <- martingale_residuals(classroom_events, spec, seed = 42)
  expect_equal(a, b)
})

test_that("rejects malformed inputs", {
  data(classroom_events)
  expect_error(martingale_residuals(list(), c(reciprocity_count = "linear")),
               "must be a data.frame")
  expect_error(martingale_residuals(classroom_events, character(0)),
               "non-empty")
  expect_error(martingale_residuals(classroom_events, c("linear")),
               "non-empty name")
  expect_error(martingale_residuals(classroom_events,
                                     c(reciprocity_count = "nl")),
               "linear")
})
