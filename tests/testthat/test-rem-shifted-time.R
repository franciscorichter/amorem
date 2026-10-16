# rem() tv()/tvnl() terms when the control has its own time (time-shifted
# sampling): each row is evaluated at its own time.

shifted_wide <- function(seed = 1, n = 400) {
  set.seed(seed)
  t_ev <- sort(runif(n, 0, 100))
  data.frame(time_ev = t_ev, time_nv = pmax(0, t_ev - rexp(n, 1 / 20)),
             x_ev = rpois(n, 3), x_nv = rpois(n, 2))
}

test_that("with one shared time column the tv() formula is unchanged", {
  skip_if_not_installed("mgcv")
  set.seed(1)
  a <- paste0("a", 1:10)
  w <- simulate_relational_events(n_events = 300, senders = a, receivers = a,
                                  n_controls = 1,
                                  endogenous_stats = "reciprocity_count",
                                  endogenous_effects = c(reciprocity_count = 0.5),
                                  wide = TRUE)
  fit <- rem(~ tv(reciprocity_count), data = w, time = "time")
  expect_match(paste(deparse(fit$gam_formula), collapse = ""),
               "s(.time, by = reciprocity_count)", fixed = TRUE)
})

test_that("tv() evaluates the smooth at the event time and the control's own time", {
  skip_if_not_installed("mgcv")
  w <- shifted_wide()
  fit <- suppressWarnings(rem(~ tv(x, k = 5), data = w, time = "time"))
  sm <- fit$fit$smooth[[1]]
  expect_identical(sm$term, ".TP")
  expect_identical(sm$by, ".XI_x")
  X <- stats::model.matrix(fit$fit)[, sm$first.para:sm$last.para]
  B_ev <- mgcv::PredictMat(sm, data.frame(.TP = w$time_ev, .XI_x = w$x_ev))
  B_nv <- mgcv::PredictMat(sm, data.frame(.TP = w$time_nv, .XI_x = w$x_nv))
  expect_equal(unname(X), unname(B_ev - B_nv))
})

test_that("tvnl() uses the event and control times", {
  skip_if_not_installed("mgcv")
  w <- shifted_wide()
  fit <- suppressWarnings(rem(~ tvnl(x, k = c(4, 4)), data = w, time = "time"))
  expect_equal(unname(fit$fit$model[[".T"]]), unname(cbind(w$time_ev, w$time_nv)))
})

test_that("tv() with shifted times needs the event and control values", {
  w <- shifted_wide()
  w$d_x <- w$x_ev - w$x_nv
  w$x_ev <- NULL; w$x_nv <- NULL
  expect_error(rem(~ tv(x), data = w, time = "time"), "x_ev")
  expect_error(rem(~ tv(d), data = w, time = "clock"), "clock")
})
