# test-compare-models.R
# Coverage for compare_models(), the one-call AIC comparison helper.

specs_small <- list(
  count       = c("reciprocity_count", "transitivity_count"),
  continuous  = c("reciprocity_time_recent", "transitivity_time_recent"),
  interrupted = c("reciprocity_time_recent_interrupted",
                  "transitivity_time_recent_interrupted"))

test_that("returns a tidy AIC table with the expected columns and types", {
  data(classroom_events)
  out <- compare_models(classroom_events, specs_small, seed = 11)
  expect_s3_class(out, "data.frame")
  expect_named(out, c("model", "n_terms", "n_obs", "log_lik", "AIC", "delta_AIC"))
  expect_equal(nrow(out), length(specs_small))
  expect_type(out$model, "character")
  expect_type(out$n_terms, "integer")
  expect_type(out$n_obs, "integer")
  expect_type(out$log_lik, "double")
  expect_type(out$AIC, "double")
  expect_setequal(out$model, names(specs_small))
  # delta_AIC ordering: rows sorted by AIC ascending, smallest delta = 0
  expect_true(min(out$delta_AIC) == 0)
  expect_true(!is.unsorted(out$AIC))
})

test_that("all specifications use the same case-control rows", {
  # The AIC values would be incomparable if each spec saw a different
  # case-control sample. We verify by re-running with the same seed:
  # the result should be deterministic AND the n_obs column should be
  # identical across rows (since the sample is shared).
  data(classroom_events)
  a <- compare_models(classroom_events, specs_small, seed = 11)
  b <- compare_models(classroom_events, specs_small, seed = 11)
  expect_equal(a, b)
  expect_equal(length(unique(a$n_obs)), 1L)
})

test_that("union of stats is deduplicated -- specs may share stats", {
  data(classroom_events)
  out <- compare_models(
    classroom_events,
    models = list(
      A = c("reciprocity_count"),
      B = c("reciprocity_count", "transitivity_count")),
    seed = 12)
  expect_equal(nrow(out), 2)
})

test_that("AIC matches a manual glm fit on the same case-control sample", {
  data(classroom_events)
  set.seed(13)
  cc <- sample_non_events(classroom_events, n_controls = 1, scope = "all",
                          mode = "one", seed = 13)
  feat <- compute_endogenous_features(cc, stats = specs_small$count)
  feat$reciprocity_count[is.na(feat$reciprocity_count)] <- 0
  feat$transitivity_count[is.na(feat$transitivity_count)] <- 0
  cases <- feat[feat$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- feat[feat$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  d <- data.frame(one = rep(1, nrow(cases)),
                  d_reciprocity_count  = cases$reciprocity_count - ctrls$reciprocity_count,
                  d_transitivity_count = cases$transitivity_count - ctrls$transitivity_count)
  manual <- glm(one ~ d_reciprocity_count + d_transitivity_count - 1,
                family = "binomial", data = d)
  helper <- compare_models(classroom_events,
                            list(count = specs_small$count), seed = 13)
  expect_equal(helper$AIC[helper$model == "count"], AIC(manual),
               tolerance = 1e-9)
  expect_equal(helper$log_lik[helper$model == "count"], as.numeric(logLik(manual)),
               tolerance = 1e-9)
})

test_that("half_life is propagated to exp-decay specs", {
  data(classroom_events)
  out <- compare_models(
    classroom_events,
    models = list(
      decay = c("reciprocity_exp_decay", "transitivity_exp_decay")),
    half_life = 0.5,
    seed = 14)
  expect_equal(nrow(out), 1L)
  expect_true(is.finite(out$AIC))
})

test_that("rejects invalid arguments with informative messages", {
  data(classroom_events)
  expect_error(compare_models(classroom_events, list()), "non-empty")
  empty_named <- setNames(list(c("reciprocity_count")), "")
  expect_error(compare_models(classroom_events, empty_named),
               "non-empty name")
  expect_error(compare_models(classroom_events,
                              list(A = 1, B = 2)),
               "character vector")
  expect_error(compare_models(classroom_events, specs_small,
                              n_controls = 2),
               "n_controls = 1")
  expect_error(compare_models(list(), specs_small),
               "data.frame")
})

test_that("works on a bundled real-world dataset and orders by AIC", {
  data(radoslaw_email)
  re <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]
  re30 <- re[re$time < 30, ]
  out <- compare_models(re30, specs_small, seed = 11)
  expect_equal(nrow(out), 3L)
  # On Radoslaw the count spec wins among these three (whitepaper §6.2).
  expect_equal(out$model[1], "count")
})

test_that("output is reproducible given a fixed seed", {
  data(classroom_events)
  a <- compare_models(classroom_events, specs_small, seed = 99)
  b <- compare_models(classroom_events, specs_small, seed = 99)
  expect_identical(a, b)
})
