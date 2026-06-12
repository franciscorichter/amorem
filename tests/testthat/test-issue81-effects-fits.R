# Tests for issue #81 modeling gaps:
#   G4 - random-effect spline term re(x) in rem()
#   G5 - extract fitted models from compare_models*() via keep_fits

test_that("G4: rem() builds an re() random-effect smooth", {
  skip_if_not_installed("mgcv")
  set.seed(1)
  w <- simulate_relational_events(
    n_events = 300, senders = paste0("a", 1:8), receivers = paste0("a", 1:8),
    n_controls = 1, endogenous_stats = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
  # re() builds the matched event/control random-effect smooth
  # s(cbind(sender_ev, sender_nv), by = c(1,-1), bs = "re").
  fit <- rem(~ reciprocity_count + re(sender), data = w, method = "degenerate")
  expect_s3_class(fit, "rem")
  expect_gt(length(fit$fit$smooth), 0L)            # the random-effect smooth
  expect_true(is.finite(logLik(fit)))
})

test_that("G4: re() default fit reproduces plain mgcv::gam; REML is opt-in (issue #88)", {
  skip_if_not_installed("mgcv")
  set.seed(3)
  w <- simulate_relational_events(
    n_events = 300, senders = paste0("a", 1:8), receivers = paste0("a", 1:8),
    n_controls = 1, endogenous_stats = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)

  fit_default <- rem(~ re(sender), data = w, method = "degenerate")
  fit_reml    <- rem(~ re(sender), data = w, method = "degenerate",
                     gam_method = "REML")

  # Tutorial reference: plain mgcv::gam with the matched +-1 factor matrix,
  # mgcv's own default smoothness selection (no method = "REML").
  n    <- nrow(w)
  fmat <- factor(c(as.character(w$sender_ev), as.character(w$sender_nv)))
  dim(fmat) <- c(n, 2L)
  df   <- list(one = rep(1, n), .I = cbind(rep(1, n), rep(-1, n)),
               .RE_sender = fmat)
  ref  <- mgcv::gam(one ~ -1 + s(.RE_sender, by = .I, bs = "re"),
                    family = stats::binomial(), data = df)

  expect_equal(unname(coef(fit_default)), unname(coef(ref)))
  expect_false(isTRUE(all.equal(coef(fit_default), coef(fit_reml))))
})

test_that("G4: re() on a missing column errors clearly; clogit rejects it", {
  skip_if_not_installed("mgcv")
  set.seed(2)
  w <- simulate_relational_events(
    n_events = 100, senders = paste0("a", 1:6), receivers = paste0("a", 1:6),
    n_controls = 1, endogenous_stats = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.5), wide = TRUE)
  expect_error(rem(~ re(nope), data = w, method = "degenerate"), "Cannot find")
  expect_error(rem(~ re(sender_ev), data = w, method = "clogit"),
               "linear terms only")
})

test_that("G5: compare_models keeps fitted models under keep_fits = TRUE", {
  data(classroom_events)
  m <- list(recip = "reciprocity_count", trans = "transitivity_count")
  res <- compare_models(classroom_events, models = m, n_controls = 1,
                        seed = 1, keep_fits = TRUE)
  fits <- attr(res, "fits")
  expect_type(fits, "list")
  expect_named(fits, c("recip", "trans"))
  expect_s3_class(fits$recip, "glm")
  # default keeps the result lightweight (no fits attached)
  res0 <- compare_models(classroom_events, models = m, n_controls = 1, seed = 1)
  expect_null(attr(res0, "fits"))
})

test_that("G5: compare_models_smooth attaches gam fits under keep_fits", {
  skip_if_not_installed("mgcv")
  data(classroom_events)
  res <- compare_models_smooth(
    classroom_events,
    models = list(lin = c(reciprocity_time_recent = "linear")),
    seed = 1, keep_fits = TRUE)
  fits <- attr(res, "fits")
  expect_named(fits, "lin")
  expect_s3_class(fits$lin, "gam")
})
