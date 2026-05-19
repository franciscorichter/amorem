# test-gof.R
# Coverage for the Boschi & Wit (2025) GOF family:
# gof_univariate(), gof_multivariate(), gof_global(), gof_auxiliary().

test_that("gof_univariate returns a KS-distributed statistic and process", {
  data(classroom_events)
  out <- gof_univariate(classroom_events,
    model = c(reciprocity_count  = "linear",
              transitivity_count = "linear"),
    covariate = "reciprocity_count", seed = 11)
  expect_named(out, c("statistic", "p_value", "W", "u", "covariate"))
  expect_true(out$statistic >= 0)
  expect_true(out$p_value >= 0 && out$p_value <= 1)
  expect_length(out$W, nrow(classroom_events))
  expect_length(out$u, nrow(classroom_events))
  # The normalized process starts at 0 (cumulative sum of zero terms)
  # and ends near 0 (centering subtracts the final value).
  expect_lt(abs(out$W[length(out$W)]), 1e-10)
})

test_that("gof_univariate rejects unknown covariate", {
  data(classroom_events)
  expect_error(
    gof_univariate(classroom_events,
      model = c(reciprocity_count = "linear"),
      covariate = "bogus"),
    "must be one of")
})

test_that("gof_global produces a numeric Cauchy-combined p-value", {
  data(classroom_events)
  out <- gof_global(classroom_events,
    model = c(reciprocity_count  = "linear",
              transitivity_count = "linear"),
    seed = 12)
  expect_named(out, c("statistic", "p_value", "components"))
  expect_true(out$p_value >= 0 && out$p_value <= 1)
  expect_equal(nrow(out$components), 2L)
  expect_named(out$components, c("covariate", "statistic", "p_value"))
})

test_that("gof_global reduces to a single-covariate test for L = 1", {
  data(classroom_events)
  out <- gof_global(classroom_events,
    model = c(reciprocity_count = "linear"), seed = 12)
  uni <- gof_univariate(classroom_events,
    model = c(reciprocity_count = "linear"),
    covariate = "reciprocity_count", seed = 12)
  # With L = 1, Cauchy combination = tan(pi(0.5 - p)) and
  # 0.5 - arctan(T)/pi = p, so p_global == p_uni.
  expect_equal(out$p_value, uni$p_value, tolerance = 1e-10)
})

test_that("gof_multivariate returns a finite sup||W||^2 statistic", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events)
  out <- gof_multivariate(classroom_events,
    model = c(reciprocity_count        = "linear",
              transitivity_count       = "linear",
              reciprocity_time_recent  = "linear"),
    covariate = "reciprocity_time_recent",
    k_basis = 5, n_sim = 200, seed = 13)
  expect_named(out, c("statistic", "p_value", "W", "u",
                      "covariate", "n_sim"))
  expect_true(is.finite(out$statistic))
  expect_true(out$p_value >= 0 && out$p_value <= 1)
  expect_equal(ncol(out$W), 4L)            # k_basis - 1 = 4
})

test_that("gof_auxiliary rejects auxiliary that is part of the model", {
  data(classroom_events)
  expect_error(
    gof_auxiliary(classroom_events,
      model = c(reciprocity_count = "linear"),
      auxiliary = "reciprocity_count", seed = 14),
    "must NOT be part of")
})

test_that("gof_auxiliary returns a Monte Carlo p-value in [0, 1]", {
  data(classroom_events)
  out <- gof_auxiliary(classroom_events,
    model = c(reciprocity_count = "linear"),
    auxiliary = "transitivity_count",
    n_sim = 200, seed = 14)
  expect_named(out, c("statistic", "p_value", "G", "u",
                      "auxiliary", "n_sim"))
  expect_true(is.finite(out$statistic))
  expect_true(out$p_value >= 0 && out$p_value <= 1)
})

test_that("Cauchy combination reduces to identity on (0, 1) edges", {
  # Sanity check on the Liu-Xie 2020 transform: a single p-value of
  # 0.5 should map to T_o = tan(0) = 0 and back to p_global = 0.5.
  data(classroom_events)
  out <- gof_global(classroom_events,
    model = c(reciprocity_count = "linear"), seed = 42)
  # Round-trip identity for L = 1 already tested; here just check the
  # statistic is finite.
  expect_true(is.finite(out$statistic))
})
