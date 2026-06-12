# Tests for rem() `gam` backend (issue #85). Uses
# simulate_relational_events(wide = TRUE) as a self-contained wide
# case-1-control fixture (<cov>_ev / <cov>_nv / d_<cov> + time).

make_wide <- function(seed = 1, n = 300) {
  set.seed(seed)
  a <- paste0("a", 1:12)
  simulate_relational_events(
    n_events = n, senders = a, receivers = a, baseline_rate = 1,
    n_controls = 1,
    endogenous_stats   = c("reciprocity_count", "reciprocity_binary"),
    endogenous_effects = c(reciprocity_count = 0.6, reciprocity_binary = 0.2),
    wide = TRUE)
}

test_that("rem() fits a linear degenerate-logistic model and exposes coef/summary", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ reciprocity_count, data = w, method = "gam")

  expect_s3_class(fit, "rem")
  expect_equal(fit$method, "gam")
  expect_equal(fit$n, nrow(w))
  cf <- coef(fit)
  expect_length(cf, 1L)                       # one linear term, no intercept
  expect_true(is.finite(cf[[1]]))
  # sign should recover the positive reciprocity effect used to simulate
  expect_gt(cf[[1]], 0)
  expect_s3_class(summary(fit), "summary.gam")
  expect_output(print(fit), "Relational event model")
})

test_that("rem() accepts multiple linear terms", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ reciprocity_count + reciprocity_binary, data = w,
             method = "gam")
  expect_length(coef(fit), 2L)
})

test_that("rem() builds a tv (time-varying) smooth term", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ tv(reciprocity_count), data = w, method = "gam",
             time = "time")
  expect_s3_class(fit, "rem")
  # a smooth term shows up in the fitted gam
  expect_gt(length(fit$fit$smooth), 0L)
  expect_s3_class(logLik(fit), "logLik")
})

test_that("rem() builds an nl (non-linear) smooth term from _ev/_nv columns", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ nl(reciprocity_count), data = w, method = "gam")
  expect_gt(length(fit$fit$smooth), 0L)
})

test_that("rem() mixes linear and smooth terms", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ reciprocity_binary + tv(reciprocity_count),
             data = w, method = "gam", time = "time")
  expect_s3_class(fit, "rem")
  expect_gt(length(fit$fit$smooth), 0L)
})

test_that("rem() errors helpfully on bad input", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  expect_error(rem("notaformula", data = w), "must be a formula")
  expect_error(rem(~ 1, data = w), "at least one term")
  expect_error(rem(~ tv(reciprocity_count), data = w, method = "gam"),
               "time")                                  # missing `time`
  expect_error(rem(~ no_such_cov, data = w, method = "gam"),
               "Cannot find")
  # clogit needs the 0/1 event indicator: a one-sided formula errors helpfully
  expect_error(rem(~ reciprocity_count, data = w, method = "clogit"),
               "event indicator")
  # ... and an indicator named (via the LHS) but absent errors clearly
  expect_error(rem(nope ~ reciprocity_count, data = w, method = "clogit"),
               "case column")
})
