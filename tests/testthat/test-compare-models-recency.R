# compare_models(recency = ): coding of time-since statistics whose NA means
# "no earlier event".

specs <- list(
  count       = c("reciprocity_count", "transitivity_count"),
  continuous  = c("reciprocity_time_recent", "transitivity_time_recent"),
  interrupted = c("reciprocity_time_recent_interrupted",
                  "transitivity_time_recent_interrupted"))
aic_of <- function(x) setNames(x$AIC, x$model)[names(specs)]

test_that("recency = 'zero' reproduces the amorem 1.2.0 coding", {
  skip_if_not_installed("survival")
  data(classroom_events, package = "amorem", envir = environment())
  z <- compare_models(classroom_events, specs, n_controls = 3, seed = 11,
                      recency = "zero")
  expect_equal(unname(aic_of(z)), c(1321.022, 1842.273, 1732.780),
               tolerance = 1e-6)
})

test_that("recency = 'weight' (default) uses w = 2^(-delta/T) plus an indicator", {
  skip_if_not_installed("survival")
  data(classroom_events, package = "amorem", envir = environment())
  w <- compare_models(classroom_events, specs, n_controls = 3, seed = 11)
  expect_equal(unname(aic_of(w)), c(1321.022, 1124.517, 1161.376),
               tolerance = 1e-6)
  # count statistics are unaffected by the coding
  z <- compare_models(classroom_events, specs, n_controls = 3, seed = 11,
                      recency = "zero")
  expect_equal(aic_of(w)[["count"]], aic_of(z)[["count"]])
  # the same fit by hand
  cc <- sample_non_events(classroom_events, n_controls = 3, seed = 11)
  f <- endogenous_features(cc, stats = specs$continuous)
  for (s in specs$continuous) {
    d <- f[[s]]
    f[[paste0(s, "_none")]] <- as.numeric(is.na(d))
    v <- exp(-d / (2 * median(d, na.rm = TRUE)))
    v[is.na(v)] <- 0
    f[[s]] <- v
  }
  fit <- survival::coxph(survival::Surv(rep(1, nrow(f)), event) ~
    reciprocity_time_recent + reciprocity_time_recent_none +
    transitivity_time_recent + transitivity_time_recent_none +
    strata(stratum), data = f, method = "breslow")
  expect_equal(aic_of(w)[["continuous"]], stats::AIC(fit), tolerance = 1e-8)
})

test_that("recency = 'weight' with a sender frailty", {
  skip_on_cran()
  skip_if_not_installed("survival")
  data(classroom_events, package = "amorem", envir = environment())
  w <- suppressWarnings(compare_models(classroom_events, specs, n_controls = 3,
                                       seed = 11, random_effects = "sender"))
  expect_equal(unname(aic_of(w)), c(1086.259, 905.024, 812.363),
               tolerance = 1e-5)
})

test_that("recency coding on the n_controls = 1 path and in the helpers", {
  data(classroom_events, package = "amorem", envir = environment())
  w <- compare_models(classroom_events, specs[1:2], seed = 11)
  z <- compare_models(classroom_events, specs[1:2], seed = 11, recency = "zero")
  expect_equal(aic_of(w)[["count"]], aic_of(z)[["count"]])
  expect_false(isTRUE(all.equal(aic_of(w)[["continuous"]],
                                aic_of(z)[["continuous"]])))
  expect_error(compare_models(classroom_events, specs[1], recency = "none"),
               "should be one of")
  expect_true(amorem:::.is_time_since_stat("recency"))
  expect_true(amorem:::.is_time_since_stat("cyclic_time_first_ordered"))
  expect_false(amorem:::.is_time_since_stat("reciprocity_exp_decay"))
  feat <- data.frame(recency = c(NA, 1, 3, NA), reciprocity_count = c(NA, 1, 2, 0))
  rc <- amorem:::.code_recency(feat, c("recency", "reciprocity_count"), "weight")
  expect_equal(rc$data$recency, c(0, exp(-1 / 4), exp(-3 / 4), 0))
  expect_equal(rc$data$recency_none, c(1, 0, 0, 1))
  expect_equal(rc$data$reciprocity_count, c(0, 1, 2, 0))
  expect_equal(rc$none, c(recency = "recency_none"))
  rz <- amorem:::.code_recency(feat, c("recency", "reciprocity_count"), "zero")
  expect_equal(rz$data$recency, c(0, 1, 3, 0))
  expect_null(rz$data$recency_none)
})

test_that("compare_models_smooth takes recency and adds the indicator", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  data(classroom_events, package = "amorem", envir = environment())
  m <- list(nl = c(reciprocity_time_recent = "nl"))
  w <- compare_models_smooth(classroom_events, m, seed = 11, keep_fits = TRUE)
  z <- compare_models_smooth(classroom_events, m, seed = 11, recency = "zero",
                             keep_fits = TRUE)
  expect_true("d_reciprocity_time_recent_none" %in%
                names(coef(attr(w, "fits")$nl)))
  expect_false(any(grepl("_none", names(coef(attr(z, "fits")$nl)))))
})
