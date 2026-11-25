# gof_* over several control samples (n_samples), p-values combined with
# the Cauchy combination (Liu & Xie 2020).

m2 <- c(reciprocity_count = "linear", transitivity_count = "linear")

test_that("n_samples = 1 reproduces the single-sample results", {
  u0 <- gof_univariate(classroom_events, m2, "transitivity_count", seed = 11)
  u1 <- gof_univariate(classroom_events, m2, "transitivity_count", seed = 11,
                       n_samples = 1)
  expect_identical(u1, u0)
  # values of the single-sample test in amorem 1.3.0 before n_samples
  expect_equal(u1$statistic, 1.250424297976384, tolerance = 1e-10)
  expect_equal(u1$p_value, 0.087680219448363, tolerance = 1e-10)
  expect_null(u1$p_values)

  g1 <- gof_global(classroom_events, m2, seed = 11, n_samples = 1)
  expect_equal(g1$statistic, 1.562445311509657, tolerance = 1e-10)
  expect_equal(g1$p_value, 0.181223075552265, tolerance = 1e-10)
  expect_named(g1, c("statistic", "p_value", "components"))

  a1 <- gof_auxiliary(classroom_events, c(reciprocity_count = "linear"),
                      "transitivity_count", n_sim = 200, seed = 11,
                      n_samples = 1)
  expect_equal(a1$statistic, 1.96223567490293, tolerance = 1e-10)
  expect_named(a1, c("statistic", "p_value", "G", "u", "auxiliary", "n_sim"))
})

test_that("gof_univariate combines the p-values of seeds seed, seed + 1, ...", {
  S <- 4
  out <- gof_univariate(classroom_events, m2, "transitivity_count",
                        seed = 11, n_samples = S)
  per <- vapply(11 + 0:(S - 1), function(sd) {
    gof_univariate(classroom_events, m2, "transitivity_count", seed = sd)$p_value
  }, numeric(1))
  expect_equal(out$n_samples, S)
  expect_equal(out$p_values, per)
  T_c <- mean(tan(pi * (0.5 - per)))
  expect_equal(out$p_value, 0.5 - atan(T_c) / pi)
  # single-sample fields come from the first sample
  first <- gof_univariate(classroom_events, m2, "transitivity_count", seed = 11)
  expect_equal(out$statistic, first$statistic)
  expect_equal(out$W, first$W)
})

test_that("n_samples without a seed draws independent samples", {
  set.seed(3)
  out <- gof_univariate(classroom_events, m2, "reciprocity_count",
                        n_samples = 3)
  expect_length(out$p_values, 3L)
  expect_gt(length(unique(out$p_values)), 1L)
  expect_true(out$p_value >= 0 && out$p_value <= 1)
})

test_that("gof_global with n_samples combines across samples and covariates", {
  S <- 3
  out <- gof_global(classroom_events, m2, seed = 5, n_samples = S)
  per <- vapply(5 + 0:(S - 1), function(sd) {
    gof_global(classroom_events, m2, seed = sd)$p_value
  }, numeric(1))
  expect_equal(out$p_values, per)
  expect_equal(out$n_samples, S)
  T_c <- mean(tan(pi * (0.5 - per)))
  expect_equal(out$p_value, 0.5 - atan(T_c) / pi)
  expect_equal(out$statistic, gof_global(classroom_events, m2, seed = 5)$statistic)
})

test_that("gof_auxiliary and gof_multivariate accept n_samples", {
  a <- gof_auxiliary(classroom_events, c(reciprocity_count = "linear"),
                     "transitivity_count", n_sim = 100, seed = 2,
                     n_samples = 2)
  expect_length(a$p_values, 2L)
  expect_equal(a$n_samples, 2L)
  skip_if_not_installed("mgcv")
  mv <- gof_multivariate(classroom_events, m2, "reciprocity_count",
                         n_sim = 60, seed = 2, n_samples = 2)
  expect_length(mv$p_values, 2L)
})

test_that("n_samples is validated", {
  expect_error(gof_univariate(classroom_events, m2, "reciprocity_count",
                              seed = 1, n_samples = 0), "n_samples")
  expect_error(gof_global(classroom_events, m2, seed = 1, n_samples = 1.5),
               "n_samples")
})

test_that("Monte Carlo p-values of 0 enter the combination as 1/(n_sim + 1)", {
  n_sim <- 100
  a <- gof_auxiliary(classroom_events, c(reciprocity_count = "linear"),
                     "transitivity_count", n_sim = n_sim, seed = 11,
                     n_samples = 3)
  # transitivity is strongly missed in classroom_events: every sample has
  # p = 0 at this n_sim
  expect_true(all(a$p_values == 0))
  expect_equal(a$p_value, 1 / (n_sim + 1))
  # mixed: the floored p-values are combined, the bound holds
  pf <- pmax(a$p_values, 1 / (n_sim + 1))
  expect_gte(a$p_value, 1 / (n_sim + 1) - 1e-12)
  expect_equal(a$p_value, 0.5 - atan(mean(tan(pi * (0.5 - pf)))) / pi)
  # internal combination with a nonzero p-value next to a zero one
  run <- local({
    pv <- c(0, 0.3); k <- 0
    function(sd) { k <<- k + 1; list(p_value = pv[k], n_sim = 99) }
  })
  out <- amorem:::.gof_over_samples(run, seed = 1, n_samples = 2)
  pf <- c(1 / 100, 0.3)
  expect_equal(out$p_values, c(0, 0.3))
  expect_equal(out$p_value, 0.5 - atan(mean(tan(pi * (0.5 - pf)))) / pi)
  expect_gte(out$p_value, 1 / 100)
  # analytic (Kolmogorov) p-values are not floored
  run2 <- local({
    pv <- c(1e-6, 0.3); k <- 0
    function(sd) { k <<- k + 1; list(p_value = pv[k]) }
  })
  out2 <- amorem:::.gof_over_samples(run2, seed = 1, n_samples = 2)
  expect_equal(out2$p_value,
               0.5 - atan(mean(tan(pi * (0.5 - c(1e-6, 0.3))))) / pi)
})
