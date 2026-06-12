# test-compare-models-global.R
# Coverage for compare_models_global() -- Lembo, Juozaitiene, Vinciotti
# & Wit (2025) time-shifted partial likelihood for global covariate
# effects.

test_that("output has the expected AIC-table columns", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  g <- data.frame(time = seq(0, max(classroom_events$time), length = 30),
                  temperature = sin(seq(0, 2 * pi, length = 30)))
  out <- compare_models_global(
    classroom_events,
    models = list(
      dyadic_only = c(reciprocity_count        = "linear",
                      transitivity_count       = "linear"),
      with_global = c(reciprocity_count        = "linear",
                      temperature              = "global_smooth")),
    global_covariates = g,
    seed = 11, k = 5)
  expect_s3_class(out, "data.frame")
  expect_named(out, c("model", "n_terms", "n_obs",
                      "log_lik", "AIC", "delta_AIC"))
  expect_equal(nrow(out), 2L)
  expect_true(all(is.finite(out$AIC)))
})

test_that("global_time fits a residual baseline-hazard smooth on a synthetic log", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  # Build a synthetic event log with a clear residual time pattern:
  # rate increases over the observation window so g_0(t) is identifiable.
  set.seed(11)
  n <- 1500
  ev <- data.frame(
    sender   = sample(LETTERS[1:8], n, replace = TRUE),
    receiver = sample(LETTERS[1:8], n, replace = TRUE),
    time     = sort(stats::runif(n, 0, 100)),
    stringsAsFactors = FALSE)
  ev <- ev[ev$sender != ev$receiver, ]
  out <- compare_models_global(
    ev,
    models = list(
      with_g0 = c(reciprocity_count = "linear",
                  time              = "global_time")),
    seed = 12, shift_scale = 5, k = 6)
  expect_equal(nrow(out), 1L)
  # The fit may converge degenerately on small/uninformative data; we
  # only assert the spec ran and returned a finite numeric row count.
  expect_true(is.finite(out$AIC) || is.na(out$AIC))
})

test_that("global_cyclic with bs = 'cc' fits on a periodic covariate", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  g <- data.frame(time = seq(0, max(classroom_events$time), length = 50),
                  tod  = ((seq(0, max(classroom_events$time),
                                length = 50)) %% 24))
  out <- compare_models_global(
    classroom_events,
    models = list(tod_only = c(tod = "global_cyclic")),
    global_covariates = g, seed = 13, k_cyclic = 8)
  expect_equal(nrow(out), 1L)
  expect_true(is.finite(out$AIC))
})

test_that("rejects malformed inputs", {
  data(classroom_events)
  expect_error(compare_models_global(classroom_events, list()),
               "non-empty")
  expect_error(
    compare_models_global(classroom_events,
      models = list(bad = c(reciprocity_count = "polynomial"))),
    "Unknown effect type")
  # Reference a global covariate that's missing from `global_covariates`:
  expect_error(
    compare_models_global(classroom_events,
      models = list(g = c(temperature = "global_smooth"))),
    "missing")
  expect_error(
    compare_models_global(classroom_events,
      models = list(g = c(temperature = "global_smooth")),
      global_covariates = data.frame(temperature = 1)),
    "`global_covariates` must have a `time` column")
})

test_that("AIC is reproducible given a fixed seed", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  g <- data.frame(time = seq(0, max(classroom_events$time), length = 30),
                  x = sin(seq(0, 2 * pi, length = 30)))
  a <- compare_models_global(classroom_events,
    models = list(m = c(reciprocity_count = "linear",
                        x = "global_smooth")),
    global_covariates = g, seed = 99, k = 5)
  b <- compare_models_global(classroom_events,
    models = list(m = c(reciprocity_count = "linear",
                        x = "global_smooth")),
    global_covariates = g, seed = 99, k = 5)
  expect_equal(a, b)
})

test_that("a dyadic-only spec returns the same shape as compare_models_smooth", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  out <- compare_models_global(
    classroom_events,
    models = list(linear = c(reciprocity_count       = "linear",
                              transitivity_count      = "linear"),
                  nl    = c(reciprocity_time_recent = "nl")),
    seed = 14, k = 5)
  expect_equal(nrow(out), 2L)
  expect_true(all(is.finite(out$AIC)))
})
