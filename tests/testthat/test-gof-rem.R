# gof_rem(): martingale-residual goodness of fit on a fitted rem() model, with
# a multiplier bootstrap that accounts for the estimated coefficients.

gof_wide <- function(seed, f, p = 15, n = 800) {
  set.seed(seed)
  d <- matrix(runif(p * p, 0, 6), p, p); diag(d) <- NA
  ids <- which(!is.na(d)); hz <- exp(f(d[ids]))
  ev <- sample(ids, n, replace = TRUE, prob = hz)
  nv <- vapply(ev, function(e) sample(ids[ids != e], 1), 0)
  data.frame(time = cumsum(rexp(n, sum(hz))), x_ev = d[ev], x_nv = d[nv],
             x = d[ev] - d[nv])
}
f_nl <- function(x) sin(x) - 0.3 * (x - 3)

test_that("the functional-form test rejects a linear fit to a non-linear effect", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(7, f_nl)
  lin <- rem(~ x, data = w, method = "gam", time = "time")
  nl  <- rem(~ nl(x), data = w, method = "gam", time = "time")
  expect_lt(gof_rem(lin, "x", "functional_form", data = w, n_sim = 300, seed = 1)$p_value, 0.01)
  expect_lt(gof_rem(lin, "x", "functional_form_score", data = w, n_sim = 300, seed = 1)$p_value, 0.01)
  expect_gt(gof_rem(nl, "x", "functional_form", n_sim = 300, seed = 1)$p_value, 0.05)
  expect_gt(gof_rem(nl, "x", "functional_form_score", n_sim = 300, seed = 1)$p_value, 0.05)
})

test_that("the time test runs over all columns of a smooth term", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(3, f_nl)
  nl <- rem(~ nl(x), data = w, method = "gam", time = "time")
  g <- gof_rem(nl, "x", "time", data = w, n_sim = 200, seed = 2)
  expect_s3_class(g, "rem_gof")
  expect_equal(dim(g$process_sim), c(length(g$x), 200L))
  expect_true(g$p_value >= 0 && g$p_value <= 1)
  expect_equal(g$statistic, max(g$process))
})

test_that("the time column defaults to the one given to rem()", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(4, function(x) 0.5 * x)
  fit <- rem(~ x, data = w, method = "gam", time = "time")
  expect_equal(gof_rem(fit, "x", "time", data = w, n_sim = 100, seed = 3)$p_value,
               gof_rem(fit, "x", "time", data = w, time = "time", n_sim = 100, seed = 3)$p_value)
})

test_that("results are reproducible with a seed and leave the caller's RNG alone", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(5, function(x) 0.5 * x)
  fit <- rem(~ x, data = w, method = "gam", time = "time")
  set.seed(42); before <- stats::runif(1)
  set.seed(42)
  a <- gof_rem(fit, "x", "functional_form", data = w, n_sim = 100, seed = 9)
  after <- stats::runif(1)
  b <- gof_rem(fit, "x", "functional_form", data = w, n_sim = 100, seed = 9)
  expect_identical(a$p_value, b$p_value)
  expect_identical(before, after)
})

test_that("print() and plot() work", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(6, function(x) 0.5 * x)
  fit <- rem(~ x, data = w, method = "gam", time = "time")
  g <- gof_rem(fit, "x", "functional_form", data = w, n_sim = 50, seed = 1)
  expect_output(print(g), "p-value")
  pdf(NULL); on.exit(grDevices::dev.off())
  expect_invisible(plot(g))
})

test_that("inputs are validated", {
  skip_if_not_installed("mgcv")
  w <- gof_wide(8, function(x) 0.5 * x)
  fit <- rem(~ x, data = w, method = "gam", time = "time")
  expect_error(gof_rem(list(), "x"), "method = \"gam\"")
  expect_error(gof_rem(fit, "y", data = w), "not a term")
  expect_error(gof_rem(fit, "x", "functional_form"), "needs `data`")
  expect_error(gof_rem(fit, "x", "time", data = w[1:10, ]), "rows")
})

test_that("gof_rem() keeps the rows rem() used when data has missing values", {
  set.seed(3)
  n <- 400
  w <- data.frame(x_ev = rnorm(n, 0.5), x_nv = rnorm(n), z_ev = rnorm(n), z_nv = rnorm(n),
                  time = sort(runif(n)))
  w$z_ev[c(5, 50, 300)] <- NA
  expect_warning(fit <- rem(~ x + z, data = w, method = "gam"), "3 of 400 rows")
  expect_equal(fit$n, 397)
  g <- gof_rem(fit, "x", test = "functional_form", data = w, n_sim = 200, seed = 1)
  expect_true(is.finite(g$p_value))
  g2 <- gof_rem(fit, "x", test = "time", data = w, time = "time", n_sim = 200, seed = 1)
  expect_true(is.finite(g2$p_value))
})
