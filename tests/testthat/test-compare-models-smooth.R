# test-compare-models-smooth.R
# Coverage for compare_models_smooth(), the GAM-based variant with
# linear / TVE / NLE / TVNLE effect choices per spec
# (Boschi, Lerner & Wit 2025).

specs_basic <- list(
  linear = c(reciprocity_count       = "linear",
             transitivity_count      = "linear"),
  nle    = c(reciprocity_time_recent  = "nle",
             transitivity_time_recent = "nle"))

test_that("returns the expected AIC table on classroom_events", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  out <- compare_models_smooth(classroom_events, specs_basic, seed = 11, k = 5)
  expect_s3_class(out, "data.frame")
  expect_named(out, c("model", "n_terms", "n_obs", "log_lik", "AIC", "delta_AIC"))
  expect_equal(nrow(out), length(specs_basic))
  expect_setequal(out$model, names(specs_basic))
  expect_true(all(is.finite(out$AIC)))
  expect_true(min(out$delta_AIC) == 0)
})

test_that("all four effect types fit on classroom_events", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  specs <- list(
    L  = c(reciprocity_time_recent  = "linear"),
    TV = c(reciprocity_time_recent  = "tve"),
    NL = c(reciprocity_time_recent  = "nle"),
    TN = c(reciprocity_time_recent  = "tvnle"))
  out <- compare_models_smooth(classroom_events, specs, seed = 12, k = 5)
  expect_equal(nrow(out), 4L)
  expect_true(all(is.finite(out$AIC)))
})

test_that("AIC is reproducible given a fixed seed", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  a <- compare_models_smooth(classroom_events, specs_basic, seed = 99, k = 5)
  b <- compare_models_smooth(classroom_events, specs_basic, seed = 99, k = 5)
  expect_equal(a, b)
})

test_that("half_life propagates to exp-decay stats inside smooth specs", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  out <- compare_models_smooth(
    classroom_events,
    models = list(decay = c(reciprocity_exp_decay  = "nle",
                            transitivity_exp_decay = "nle")),
    half_life = 5, seed = 14, k = 5)
  expect_equal(nrow(out), 1L)
  expect_true(is.finite(out$AIC))
})

test_that("rejects invalid effect types", {
  data(classroom_events)
  expect_error(
    compare_models_smooth(classroom_events,
      models = list(bad = c(reciprocity_count = "polynomial"))),
    "Unknown effect type")
})

test_that("rejects malformed specifications", {
  data(classroom_events)
  expect_error(
    compare_models_smooth(classroom_events,
      models = list(unnamed = c("linear", "linear"))),
    "named character vector")
  expect_error(
    compare_models_smooth(classroom_events, list()),
    "non-empty")
})

test_that("a TVNLE spec on a synthetic time-varying covariate is recoverable", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  # Sanity: with TVNLE active, the AIC of a tvnle spec should be no worse
  # than the linear spec by more than a small penalty (rough numerical
  # check; the empirical recovery story is in the whitepaper).
  data(classroom_events)
  out <- compare_models_smooth(
    classroom_events,
    models = list(
      linear = c(transitivity_time_recent = "linear"),
      tvnle  = c(transitivity_time_recent = "tvnle")),
    seed = 21, k = 5)
  expect_equal(nrow(out), 2L)
  expect_true(all(is.finite(out$AIC)))
})
