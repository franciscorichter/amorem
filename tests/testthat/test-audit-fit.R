# Regression tests for the fitting functions (pre-release audit of 1.3.0,
# items 5, 6, 7, 8, 16, 18, 24, 25, 27).

# Long case-k-control fixture with a known linear truth, blocked layout
# (each case followed by its controls).
.audit_cc <- function(K = 150L, m = 3L, beta = c(0.9, -0.6), seed = 1L) {
  set.seed(seed)
  do.call(rbind, lapply(seq_len(K), function(k) {
    x <- matrix(stats::rnorm(m * length(beta)), m, length(beta))
    sc <- as.numeric(x %*% beta)
    ev <- integer(m); ev[sample(m, 1L, prob = exp(sc) / sum(exp(sc)))] <- 1L
    o <- order(-ev)                                   # case first
    data.frame(event = ev[o], strat = k, x1 = x[o, 1], x2 = x[o, 2],
               z = stats::runif(m, 0.5, 2))
  }))
}

# ---- 5: the event indicator is read by value ------------------------------

test_that(".as_event01 converts every accepted encoding by value", {
  expect_identical(.as_event01(c(0, 1, 1)), c(0L, 1L, 1L))
  expect_identical(.as_event01(c(0L, 1L, NA)), c(0L, 1L, NA))
  expect_identical(.as_event01(c(FALSE, TRUE)), c(0L, 1L))
  expect_identical(.as_event01(c("1", "0")), c(1L, 0L))
  expect_identical(.as_event01(factor(c("0", "1", "1"))), c(0L, 1L, 1L))
  expect_identical(.as_event01(factor(c("1", "0"), levels = c("1", "0"))), c(1L, 0L))
  expect_identical(.as_event01(factor(c("FALSE", "TRUE"))), c(0L, 1L))
  expect_error(.as_event01(c(0, 2)), "0/1")
  expect_error(.as_event01(c("yes", "no")), "0/1")
  expect_error(.as_event01(factor(c("a", "b"))), "0/1")
})

test_that("a factor event column gives the same clogit fit as a numeric one", {
  skip_if_not_installed("survival")
  cc <- .audit_cc()
  cc$strat <- NULL                         # strata come from cumsum(case == 1)
  ccf <- cc; ccf$event <- factor(ccf$event)
  ccc <- cc; ccc$event <- as.character(ccc$event)
  ccl <- cc; ccl$event <- ccl$event == 1
  f0 <- rem(event ~ x1 + x2, data = cc, method = "clogit")
  expect_equal(coef(rem(event ~ x1 + x2, data = ccf, method = "clogit")), coef(f0))
  expect_equal(coef(rem(event ~ x1 + x2, data = ccc, method = "clogit")), coef(f0))
  expect_equal(coef(rem(event ~ x1 + x2, data = ccl, method = "clogit")), coef(f0))
})

test_that("a factor event column gives the same nn fit as a numeric one", {
  cc <- .audit_cc()
  ccf <- cc; ccf$event <- factor(ccf$event)
  ctl <- nn_control(hidden = integer(0), epochs = 40L, validation = 0, seed = 1L)
  f0 <- rem(event ~ x1 + x2, data = cc, method = "nn", stratum = "strat", nn = ctl)
  f1 <- rem(event ~ x1 + x2, data = ccf, method = "nn", stratum = "strat", nn = ctl)
  expect_equal(predict(f1$fit, cc), predict(f0$fit, cc))
})

test_that("widen_case_control() and gam auto-widening accept a factor event", {
  cc <- .audit_cc(m = 2L)
  ccf <- cc; ccf$event <- factor(ccf$event)
  expect_equal(widen_case_control(ccf, stratum = "strat"),
               widen_case_control(cc, stratum = "strat"))
  skip_if_not_installed("mgcv")
  f0 <- suppressMessages(rem(~ x1 + x2, data = cc, stratum = "strat"))
  f1 <- suppressMessages(rem(~ x1 + x2, data = ccf, stratum = "strat"))
  expect_equal(coef(f1), coef(f0))
})

test_that("an event column with values other than 0/1 is an error", {
  skip_if_not_installed("survival")
  cc <- .audit_cc()
  cc$event <- cc$event + 1L
  expect_error(rem(event ~ x1, data = cc, method = "clogit", stratum = "strat"), "0/1")
  expect_error(widen_case_control(cc, stratum = "strat"), "0/1")
})

# ---- 6: nn_uncertainty() uses the fit's case and stratum ------------------

test_that("nn_uncertainty() uses the case and stratum stored by rem()", {
  cc <- .audit_cc()
  fit <- rem(~ x1 + x2, data = cc, method = "nn", case = "event", stratum = "strat",
             nn = nn_control(hidden = integer(0), epochs = 300L, seed = 1L))
  expect_identical(fit$case, "event")
  expect_identical(fit$stratum, "strat")
  u <- nn_uncertainty(fit, cc, B = 5L, seed = 1L)
  conc_fit <- .nn_concordance(predict(fit$fit, cc), cc$strat, cc$event == 1L)
  expect_gt(conc_fit, 0.6)
  expect_gt(unname(u$concordance[2L]), 0.6)
  expect_lt(abs(unname(u$concordance[2L]) - conc_fit), 0.1)
})

# ---- 7: global covariate lookup ------------------------------------------

test_that("global covariates use the value of the last grid time at or before t", {
  g_time <- c(2, 0, 1)                         # unsorted on purpose
  g_val  <- c(30, 10, 20)
  expect_equal(.global_locf(g_time, g_val, c(-1, 0, 0.5, 1, 1.5, 2, 3)),
               c(10, 10, 10, 20, 20, 30, 30))
})

# ---- 8: offset() terms ---------------------------------------------------

test_that("clogit offset() matches survival::clogit", {
  skip_if_not_installed("survival")
  cc <- .audit_cc()
  f <- rem(event ~ x1 + offset(log(z)), data = cc, method = "clogit", stratum = "strat")
  ref <- survival::clogit(event ~ x1 + offset(log(z)) + strata(strat), data = cc)
  expect_equal(unname(coef(f)), unname(coef(ref)), tolerance = 1e-8)
  expect_equal(as.numeric(logLik(f)), as.numeric(logLik(ref)), tolerance = 1e-8)
  # and differs from the fit without the offset
  f0 <- rem(event ~ x1, data = cc, method = "clogit", stratum = "strat")
  expect_false(isTRUE(all.equal(coef(f), coef(f0))))
})

test_that("gam offset() enters as an event-minus-control difference", {
  skip_if_not_installed("mgcv")
  set.seed(2)
  n <- 300
  w <- data.frame(x_ev = rnorm(n), x_nv = rnorm(n),
                  o_ev = rnorm(n), o_nv = rnorm(n))
  f <- rem(~ x + offset(o), data = w, method = "gam")
  ref <- stats::glm(rep(1, n) ~ -1 + I(w$x_ev - w$x_nv),
                    offset = w$o_ev - w$o_nv, family = stats::binomial())
  expect_equal(unname(coef(f)), unname(coef(ref)), tolerance = 1e-6)
  expect_error(rem(~ x + offset(exp(o_ev)), data = w, method = "gam"), "bare column")
  expect_error(rem(event ~ x1 + offset(z), data = .audit_cc(), method = "nn",
                   stratum = "strat"), "offset")
})

# ---- 16: torch seeding on the first fit of a session -----------------------

test_that("the first torch fit of a session is reproducible with a seed", {
  skip_on_cran()
  skip_if_not_installed("torch")
  skip_if_not_installed("callr")
  skip_if(!torch::torch_is_installed(), "libtorch not installed")
  d <- callr::r(function(lib) {
    .libPaths(lib)
    library(amorem)
    set.seed(3)
    df <- do.call(rbind, lapply(1:60, function(k) {
      x <- rnorm(3); ev <- integer(3); ev[sample(3, 1, prob = exp(x))] <- 1L
      data.frame(event = ev, strat = k, x1 = x)
    }))
    ctl <- nn_control(hidden = integer(0), engine = "torch", batch_strata = 8L,
                      epochs = 5L, validation = 0, seed = 1L)
    p1 <- predict(rem(event ~ x1, data = df, method = "nn", stratum = "strat",
                      nn = ctl)$fit, df)
    p2 <- predict(rem(event ~ x1, data = df, method = "nn", stratum = "strat",
                      nn = ctl)$fit, df)
    max(abs(p1 - p2))
  }, args = list(lib = .libPaths()))
  expect_equal(d, 0)
})

# ---- 18: re() needs event and control levels -------------------------------

test_that("re(x) with a single column is an error", {
  skip_if_not_installed("mgcv")
  set.seed(1)
  w <- data.frame(x = rnorm(50), g = sample(letters[1:4], 50, TRUE))
  expect_error(rem(~ x + re(g), data = w, method = "gam"), "g_ev")
})

# ---- 24: gam on long data with several controls ---------------------------

test_that("gam on long data with several controls warns and points to clogit", {
  skip_if_not_installed("mgcv")
  cc <- .audit_cc(m = 3L)
  expect_warning(suppressMessages(rem(~ x1, data = cc, stratum = "strat")),
                 "only the first control.*clogit")
  cc1 <- .audit_cc(m = 2L)
  expect_no_warning(suppressMessages(rem(~ x1, data = cc1, stratum = "strat")))
})

# ---- 25: predict() on the user's wide data --------------------------------

test_that("predict() on a gam fit takes the user's wide data", {
  skip_if_not_installed("mgcv")
  set.seed(4)
  n <- 200
  w <- data.frame(x_ev = rnorm(n), x_nv = rnorm(n),
                  y_ev = runif(n), y_nv = runif(n),
                  g_ev = sample(letters[1:5], n, TRUE),
                  g_nv = sample(letters[1:5], n, TRUE),
                  time = sort(runif(n)))
  f <- rem(~ x + nl(y, k = 5) + re(g) + tv(x, k = 5), data = w, method = "gam",
           time = "time")
  lp <- as.numeric(predict(f, w))
  expect_equal(lp, as.numeric(predict(f$fit)), tolerance = 1e-8)
  # a subset in a different order, with a level set smaller than the fit's
  sub <- w[c(10, 3, 7), ]
  sub$g_ev <- "a"; sub$g_nv <- "b"
  ref <- w[c(10, 3, 7), ]
  expect_length(predict(f, sub), 3L)
  expect_equal(as.numeric(predict(f, ref)), lp[c(10, 3, 7)], tolerance = 1e-8)
})

# ---- 27: clogit records the rows it used ----------------------------------

test_that("clogit fits report the rows used in n and $rows", {
  skip_if_not_installed("survival")
  cc <- .audit_cc()
  cc$x1[c(2, 5)] <- NA
  expect_warning(f <- rem(event ~ x1, data = cc, method = "clogit", stratum = "strat"),
                 "2 of 450 rows")
  expect_equal(f$n, nrow(cc) - 2L)
  expect_identical(f$rows, !is.na(cc$x1))
  expect_equal(f$n, f$fit$n)
})

test_that("bootstrap p-values of zero are reported as a bound", {
  expect_identical(amorem:::.format_boot_p(0, 1000, "p"), "p < 0.001")
  expect_identical(amorem:::.format_boot_p(0.25, 1000, "p"), "p = 0.250")
  expect_identical(amorem:::.format_boot_p(0, 200, "p-value", 4L), "p-value < 0.005")
})
