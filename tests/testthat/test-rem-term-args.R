# Tests for per-term basis arguments in rem() formulas (issue #91):
# tv(x, k = , bs = ), nl(x, k = , bs = ), tvnl(x, k = , bs = ) and the global
# k / bs defaults.

make_wide <- function(seed = 1, n = 400) {
  set.seed(seed)
  a <- paste0("a", 1:12)
  simulate_relational_events(
    n_events = n, senders = a, receivers = a, baseline_rate = 1,
    n_controls = 1,
    endogenous_stats   = c("reciprocity_count", "reciprocity_binary"),
    endogenous_effects = c(reciprocity_count = 0.6, reciprocity_binary = 0.2),
    wide = TRUE)
}

smooth_info <- function(fit) {
  lapply(fit$fit$smooth, function(s) list(label = s$label, dim = s$bs.dim,
                                          class = class(s)[1]))
}

test_that("each smooth term takes its own k and bs", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ tv(reciprocity_count, k = 6, bs = "cr") +
               nl(reciprocity_count, k = 4, bs = "ps"),
             data = w, method = "gam", time = "time")
  si <- smooth_info(fit)
  expect_length(si, 2L)
  expect_equal(si[[1]]$dim, 6L)
  expect_equal(si[[1]]$class, "cr.smooth")
  expect_equal(si[[2]]$dim, 4L)
  expect_equal(si[[2]]$class, "pspline.smooth")
})

test_that("global k / bs fill in for terms that do not set their own", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ tv(reciprocity_binary) + nl(reciprocity_count, k = 4),
             data = w, method = "gam", time = "time", k = 7, bs = "cr")
  si <- smooth_info(fit)
  expect_equal(si[[1]]$dim, 7L)              # global k
  expect_equal(si[[2]]$dim, 4L)              # term k wins over global k
  expect_equal(si[[1]]$class, "cr.smooth")   # global bs reaches both terms
  expect_equal(si[[2]]$class, "cr.smooth")
})

test_that("a global k gives the same fit as before per-term arguments existed", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  a <- rem(~ nl(reciprocity_count), data = w, method = "gam", k = 5)
  b <- rem(~ nl(reciprocity_count, k = 5), data = w, method = "gam")
  expect_equal(deparse(a$gam_formula), deparse(b$gam_formula))
  expect_equal(coef(a), coef(b))
  expect_match(paste(deparse(a$gam_formula), collapse = ""), "k = 5")
})

test_that("tvnl takes one k / bs per margin", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  fit <- rem(~ tvnl(reciprocity_count, k = c(5, 4), bs = c("tp", "cr")),
             data = w, method = "gam", time = "time")
  sm <- fit$fit$smooth[[1]]
  expect_s3_class(sm, "tensor.smooth")
  expect_equal(vapply(sm$margin, function(m) m$bs.dim, numeric(1)), c(5, 4))
  expect_equal(vapply(sm$margin, function(m) class(m)[1], character(1)),
               c("tprs.smooth", "cr.smooth"))
})

test_that("term arguments are evaluated in the formula's environment", {
  skip_if_not_installed("mgcv")
  w <- make_wide()
  kk <- 4
  fit <- rem(~ nl(reciprocity_count, k = kk), data = w, method = "gam")
  expect_equal(fit$fit$smooth[[1]]$bs.dim, 4L)
  expect_equal(fit$terms[[1]]$var, "reciprocity_count")
  expect_equal(fit$terms[[1]]$args, list(k = 4))
})

test_that("malformed term arguments are rejected", {
  w <- make_wide(n = 50)
  expect_error(rem(~ nl(reciprocity_count, 5), data = w), "named arguments")
  expect_error(rem(~ nl(reciprocity_count, by = reciprocity_binary), data = w),
               "`by`")
  expect_error(rem(~ re(sender, k = 3), data = w), "re\\(\\) takes no")
  expect_error(rem(~ nl(log(reciprocity_count)), data = w), "column name")
})

test_that("clogit still rejects smooth terms that carry arguments", {
  w <- make_wide(n = 50)
  expect_error(rem(event ~ nl(reciprocity_count, k = 4), data = w,
                   method = "clogit"), "linear terms only")
})
