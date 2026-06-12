# Tests for rem(method = "nn"): the pure-R neural conditional-logistic
# backend. The analytic gradients are verified against numerical
# differentiation; recovery tests check the net learns planted structure
# a linear conditional logit cannot.

# Build S strata of (1 event + 1 control) where the event is chosen by a
# softmax over a true score function eta(x). Returns the long case-control
# data.frame rem() expects.
make_nn_cc <- function(S, eta, p = 2L, seed = 1) {
  set.seed(seed)
  rows <- vector("list", S)
  for (s in seq_len(S)) {
    X <- matrix(rnorm(2L * p), 2L, p)
    sc <- apply(X, 1L, eta)
    pr <- exp(sc - max(sc)); pr <- pr / sum(pr)
    ev <- sample(1:2, 1L, prob = pr)
    d <- as.data.frame(X); names(d) <- paste0("x", seq_len(p))
    d$event <- as.integer(seq_len(2L) == ev)
    d$stratum <- s
    rows[[s]] <- d[order(-d$event), ]      # case first, then control
  }
  do.call(rbind, rows)
}

# top-1 concordance of arbitrary scores under the stratum structure
concordance <- function(scores, strat, event) {
  top <- tapply(seq_along(scores), strat,
                function(ix) ix[which.max(scores[ix])])
  mean(event[as.integer(top)] == 1L)
}

test_that("nn backend: analytic gradients match numerical differentiation", {
  set.seed(42)
  n <- 12L; p <- 3L
  X <- matrix(rnorm(n * p), n, p)
  strat <- rep(1:4, each = 3L)                  # strata of size 3
  is_event <- as.logical(ave(rnorm(n), strat,
                             FUN = function(z) z == max(z)))
  l2 <- 1e-3
  layers <- amore:::.nn_init(p, c(5L), seed = 7)

  loss_at <- function(layers) {
    fw <- amore:::.nn_forward(layers, X, "tanh")
    base <- amore:::.nn_loss_grad(fw$scores, strat, is_event)$loss
    pen <- sum(vapply(layers, function(l) sum(l$W^2), numeric(1)))
    base + 0.5 * l2 * pen
  }

  fw <- amore:::.nn_forward(layers, X, "tanh")
  lg <- amore:::.nn_loss_grad(fw$scores, strat, is_event)
  grads <- amore:::.nn_backward(layers, fw$acts, lg$grad, "tanh", l2)

  eps <- 1e-6
  for (l in seq_along(layers)) {
    for (nm in c("W", "b")) {
      theta <- layers[[l]][[nm]]
      idx <- seq_len(min(6L, length(theta)))   # spot-check several entries
      for (i in idx) {
        pert <- layers
        pert[[l]][[nm]][i] <- pert[[l]][[nm]][i] + eps
        up <- loss_at(pert)
        pert[[l]][[nm]][i] <- pert[[l]][[nm]][i] - 2 * eps
        dn <- loss_at(pert)
        num <- (up - dn) / (2 * eps)
        expect_equal(grads[[l]][[nm]][i], num, tolerance = 1e-4)
      }
    }
  }
})

test_that("nn backend recovers a planted linear effect", {
  cc <- make_nn_cc(S = 400L, eta = function(x) 1.5 * x[1], seed = 2)
  fit <- rem(event ~ x1 + x2, data = cc, method = "nn",
             nn = nn_control(hidden = c(8L), epochs = 200L, seed = 3))
  expect_s3_class(fit, "rem")
  expect_equal(fit$method, "nn")
  expect_true(is.finite(logLik(fit)))
  expect_gt(fit$fit$concordance$all, 0.6)
  # higher x1 should score higher (monotone learned effect)
  nd_lo <- data.frame(x1 = -1, x2 = 0); nd_hi <- data.frame(x1 = 1, x2 = 0)
  expect_gt(predict(fit, nd_hi), predict(fit, nd_lo))
})

test_that("nn backend learns an interaction a linear clogit cannot", {
  skip_if_not_installed("survival")
  cc <- make_nn_cc(S = 500L, eta = function(x) 2.5 * x[1] * x[2], seed = 4)
  fit_nn <- rem(event ~ x1 + x2, data = cc, method = "nn",
                nn = nn_control(hidden = c(16L, 8L), epochs = 400L,
                                lr = 5e-3, seed = 5))
  fit_lin <- rem(event ~ x1 + x2, data = cc, method = "clogit",
                 stratum = "stratum")
  eta_lin <- as.matrix(cc[, c("x1", "x2")]) %*% coef(fit_lin)
  c_lin <- concordance(drop(eta_lin), cc$stratum, cc$event)
  c_nn  <- fit_nn$fit$concordance$all
  expect_gt(c_nn, 0.6)          # the net finds the interaction structure
  expect_gt(c_nn, c_lin + 0.05) # and clearly beats the linear fit
})

test_that("nn backend API errors are informative", {
  cc <- make_nn_cc(S = 20L, eta = function(x) x[1], seed = 6)
  expect_error(rem(event ~ nl(x1), data = cc, method = "nn"),
               "bare covariate names")
  expect_error(rem(~ x1, data = cc, method = "nn"),
               "event indicator")
  expect_error(rem(event ~ x1, data = cc, method = "nn", nn = list()),
               "nn_control")
  cc$x1 <- as.character(cc$x1)
  expect_error(rem(event ~ x1, data = cc, method = "nn"),
               "numeric covariates")
})

test_that("nn fit methods: print/summary/coef/logLik/predict/plot", {
  cc <- make_nn_cc(S = 60L, eta = function(x) x[1], seed = 7)
  fit <- rem(event ~ x1 + x2, data = cc, method = "nn",
             nn = nn_control(hidden = c(4L), epochs = 50L, seed = 8))
  expect_output(print(fit), "method : nn")
  expect_output(summary(fit), "concordance")
  expect_message(cf <- coef(fit), "no coefficients")
  expect_null(cf)
  ll <- logLik(fit)
  expect_true(is.finite(ll))
  expect_gt(attr(ll, "df"), 0)
  pr <- predict(fit, cc)
  expect_length(pr, nrow(cc))
  grDevices::pdf(NULL)
  expect_silent(plot(fit$fit, type = "loss"))
  expect_silent(plot(fit$fit, type = "pdp"))
  grDevices::dev.off()
})
