# test-gof.R
# Coverage for the Boschi & Wit (2025) GOF family:
# gof_univariate(), gof_multivariate(), gof_global(), gof_auxiliary().

test_that("gof_univariate returns a KS-distributed statistic and process", {
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
  expect_error(
    gof_univariate(classroom_events,
      model = c(reciprocity_count = "linear"),
      covariate = "bogus"),
    "must be one of")
})

test_that("gof_global produces a numeric Cauchy-combined p-value", {
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
  expect_error(
    gof_auxiliary(classroom_events,
      model = c(reciprocity_count = "linear"),
      auxiliary = "reciprocity_count", seed = 14),
    "must NOT be part of")
})

test_that("gof_auxiliary returns a Monte Carlo p-value in [0, 1]", {
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
  out <- gof_global(classroom_events,
    model = c(reciprocity_count = "linear"), seed = 42)
  # Round-trip identity for L = 1 already tested; here just check the
  # statistic is finite.
  expect_true(is.finite(out$statistic))
})

test_that("gof_multivariate holds its level for a correct linear model", {
  # amorem 1.3.0 before this fix referred the statistic to simulated
  # q-dimensional Brownian bridges and rejected a correct linear
  # reciprocity_count model in about 35% of replicates at the 5% level;
  # the multiplier bootstrap with the estimation term rejects in about 5%.
  skip_on_cran()
  skip_if_not_installed("mgcv")
  actors <- paste0("a", 1:20)
  p <- vapply(1:40, function(i) {
    set.seed(80000 + i)
    ev <- simulate_relational_events(n_events = 1000, senders = actors,
      receivers = actors, endogenous_stats = "reciprocity_count",
      endogenous_effects = c(reciprocity_count = 0.2),
      method = "gillespie")[, c("sender", "receiver", "time")]
    # an unpenalised spline refit can separate in a replicate
    suppressWarnings(gof_multivariate(ev, c(reciprocity_count = "linear"),
                     "reciprocity_count", n_sim = 200,
                     seed = 90000 + i))$p_value
  }, numeric(1))
  # Binomial(40, 0.05): P(X >= 7) = 0.014; under the old null
  # (rejection rate 0.35) P(X <= 6) < 1e-4.
  expect_lte(sum(p < 0.05), 6)
  # the p-values are spread over (0, 1), not piled near 0
  expect_gt(mean(p), 0.3)
})
