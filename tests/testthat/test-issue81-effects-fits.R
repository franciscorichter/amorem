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
  # an actor RE in a matched design can be weakly identified (mgcv may warn);
  # we only check the term is built and the object is well-formed.
  fit <- suppressWarnings(
    rem(~ reciprocity_count + re(sender_ev), data = w, method = "degenerate"))
  expect_s3_class(fit, "rem")
  expect_gt(length(fit$fit$smooth), 0L)            # the random-effect smooth
  expect_true(any(grepl("sender_ev", names(coef(fit)))))
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
