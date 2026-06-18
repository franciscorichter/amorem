# Tests for the torch training engine and the bootstrap uncertainty helper.

# build a small case-control fixture with a known linear truth
.cc_fixture <- function(K = 200L, m = 4L, beta = c(0.9, -0.6), seed = 1L) {
  set.seed(seed)
  do.call(rbind, lapply(seq_len(K), function(k) {
    x <- matrix(stats::rnorm(m * length(beta)), m, length(beta))
    sc <- as.numeric(x %*% beta)
    ev <- integer(m); ev[sample(m, 1L, prob = exp(sc) / sum(exp(sc)))] <- 1L
    data.frame(event = ev, strat = k, x1 = x[, 1], x2 = x[, 2])
  }))
}

test_that("nn_control records the engine and rejects bad values", {
  expect_equal(nn_control()$engine, "r")
  expect_equal(nn_control(engine = "torch")$engine, "torch")
  expect_error(nn_control(engine = "keras"))
})

test_that("torch engine fits and tracks the R engine on a linear fixture", {
  skip_on_cran()
  skip_if_not_installed("torch")
  skip_if(!torch::torch_is_installed(), "libtorch not installed")
  df <- .cc_fixture()
  fr <- rem(event ~ x1 + x2, data = df, method = "nn", stratum = "strat",
            nn = nn_control(hidden = integer(0), engine = "r",
                            epochs = 150L, validation = 0.2, seed = 1L))
  ft <- rem(event ~ x1 + x2, data = df, method = "nn", stratum = "strat",
            nn = nn_control(hidden = integer(0), engine = "torch",
                            epochs = 150L, validation = 0.2, seed = 1L))
  expect_s3_class(ft$fit, "rem_nn_fit")
  pr <- stats::predict(fr$fit, df); pt <- stats::predict(ft$fit, df)
  expect_gt(stats::cor(pr, pt), 0.95)          # same model, near-identical scores
  expect_true(is.finite(ft$fit$logLik))
})

test_that("torch engine errors clearly on unequal strata", {
  skip_on_cran()
  skip_if_not_installed("torch")
  skip_if(!torch::torch_is_installed(), "libtorch not installed")
  df <- .cc_fixture(K = 30L)
  df <- df[-1L, ]                               # break equal-sized strata
  expect_error(
    rem(event ~ x1 + x2, data = df, method = "nn", stratum = "strat",
        nn = nn_control(engine = "torch", epochs = 5L, seed = 1L)),
    "equal-sized strata")
})

test_that("nn_uncertainty returns valid bands and a concordance interval", {
  df <- .cc_fixture(K = 150L)
  fit <- rem(event ~ x1 + x2, data = df, method = "nn", stratum = "strat",
             nn = nn_control(engine = "r", epochs = 100L, validation = 0.2, seed = 1L))
  u <- nn_uncertainty(fit, df, B = 20L, stratum = "strat", seed = 7L)
  expect_s3_class(u, "nn_uncertainty")
  expect_equal(length(u$bands), 2L)
  expect_named(u$bands[[1L]], c("x", "lo", "med", "hi"))
  expect_true(all(u$bands$x1$hi >= u$bands$x1$lo))
  expect_length(u$concordance, 3L)
  expect_true(all(u$concordance >= 0 & u$concordance <= 1))
  expect_error(nn_uncertainty(structure(list(method = "clogit"), class = "rem"), df),
               "method = \"nn\"")
})
