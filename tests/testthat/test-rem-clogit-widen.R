# Tests for rem(method = "clogit") and widen_case_control() (issue #84).

make_long_cc <- function(seed = 1, n = 200, n_controls = 20, beta = 0.8) {
  set.seed(seed)
  a <- paste0("a", 1:15)
  simulate_relational_events(
    n_events = n, senders = a, receivers = a, baseline_rate = 1,
    n_controls = n_controls,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = beta))
}

test_that("rem(clogit) fits a case-k-control conditional logit and recovers the effect", {
  skip_if_not_installed("survival")
  cc <- make_long_cc()                    # long, event/stratum columns, 20 controls
  fit <- rem(event ~ reciprocity_count, data = cc,
             method = "clogit", case = "event", stratum = "stratum")

  expect_s3_class(fit, "rem")
  expect_equal(fit$method, "clogit")
  cf <- coef(fit)
  expect_named(cf, "reciprocity_count")
  expect_gt(cf[["reciprocity_count"]], 0)        # positive planted effect
  expect_true(is.finite(logLik(fit)))
  expect_output(print(fit), "method : clogit")
})

test_that("rem(clogit) derives the stratum by cumsum when none is given", {
  skip_if_not_installed("survival")
  # hand-blocked: each case (1) immediately followed by its 2 controls (0)
  blocked <- data.frame(
    IS_OBSERVED = rep(c(1, 0, 0), 30),
    x = c(rbind(rnorm(30, 1), rnorm(30, 0), rnorm(30, 0))),
    stringsAsFactors = FALSE)
  fit <- rem(IS_OBSERVED ~ x, data = blocked, method = "clogit")  # stratum = NULL
  expect_named(coef(fit), "x")
  expect_true(is.finite(coef(fit)[["x"]]))
})

test_that("rem(clogit) rejects smooth terms", {
  skip_if_not_installed("survival")
  cc <- make_long_cc(n = 50)
  expect_error(
    rem(event ~ tve(reciprocity_count), data = cc, method = "clogit",
        case = "event", stratum = "stratum", time = "time"),
    "linear terms only")
})

test_that("widen_case_control() produces ev/nv/diff columns, one row per case", {
  blocked <- data.frame(
    IS_OBSERVED = rep(c(1, 0, 0), 5),
    x = c(rbind(rep(2, 5), rep(0, 5), rep(1, 5))),
    y = rnorm(15),
    stringsAsFactors = FALSE)
  w <- widen_case_control(blocked, control_index = 1)
  expect_equal(nrow(w), 5L)                       # 5 cases
  expect_true(all(c("x_ev", "x_nv", "d_x", "y_ev", "y_nv", "d_y") %in% names(w)))
  expect_equal(w$d_x, w$x_ev - w$x_nv)
  # control_index = 1 picks the first control (x = 0) for every case (x = 2)
  expect_true(all(w$x_ev == 2))
  expect_true(all(w$x_nv == 0))
  expect_true(all(w$d_x == 2))
})

test_that("widen + rem(degenerate) round-trips on a simulated case-k-control log", {
  skip_if_not_installed("mgcv")
  cc <- make_long_cc(n = 150, n_controls = 5)
  w <- widen_case_control(cc, case = "event", stratum = "stratum",
                          covariates = "reciprocity_count", control_index = 1)
  expect_true(all(c("reciprocity_count_ev", "reciprocity_count_nv",
                    "d_reciprocity_count") %in% names(w)))
  fit <- rem(~ reciprocity_count, data = w, method = "degenerate")
  expect_named(coef(fit), "reciprocity_count")
})

test_that("undirected logs (no receiver column) work for clogit and widen", {
  # senders only; covariate columns are all that matter
  und <- data.frame(
    IS_OBSERVED = rep(c(1, 0, 0), 8),
    SOURCE = paste0("|", sample(LETTERS, 24, TRUE), "|"),
    activity = c(rbind(rnorm(8, 1), rnorm(8, 0), rnorm(8, 0))),
    stringsAsFactors = FALSE)
  expect_silent(w <- widen_case_control(und, covariates = "activity"))
  expect_equal(nrow(w), 8L)
  skip_if_not_installed("survival")
  fit <- rem(IS_OBSERVED ~ activity, data = und, method = "clogit")
  expect_named(coef(fit), "activity")
})
