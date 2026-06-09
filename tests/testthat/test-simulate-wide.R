test_that("wide = TRUE returns one case-1-control row per event", {
  set.seed(1)
  senders <- receivers <- paste0("a", 1:10)
  w <- simulate_relational_events(
    n_events           = 30,
    senders            = senders,
    receivers          = receivers,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6),
    wide               = TRUE
  )

  expect_s3_class(w, "data.frame")
  expect_equal(nrow(w), 30L)
  expect_identical(
    names(w),
    c("stratum", "time", "sender_ev", "receiver_ev", "sender_nv", "receiver_nv",
      "reciprocity_count_ev", "reciprocity_count_nv", "d_reciprocity_count")
  )
  # one row per stratum, strata complete and unique
  expect_equal(sort(w$stratum), 1:30)
  # actor columns are character (not factor)
  expect_type(w$sender_ev, "character")
  expect_type(w$receiver_nv, "character")
  # difference column is exactly event - control
  expect_equal(w$d_reciprocity_count,
               w$reciprocity_count_ev - w$reciprocity_count_nv)
})

test_that("wide output equals a manual reshape of the long output", {
  set.seed(42)
  senders <- receivers <- paste0("a", 1:12)
  args <- list(
    n_events           = 50,
    senders            = senders,
    receivers          = receivers,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6)
  )

  set.seed(7)
  long <- do.call(simulate_relational_events, args)
  set.seed(7)
  wide <- do.call(simulate_relational_events, c(args, list(wide = TRUE)))

  cases <- long[long$event == 1L, ]
  ctrls <- long[long$event == 0L, ]
  cases <- cases[order(cases$stratum), ]
  ctrls <- ctrls[order(ctrls$stratum), ]

  expect_equal(wide$stratum, cases$stratum)
  expect_equal(wide$sender_ev, cases$sender)
  expect_equal(wide$receiver_ev, cases$receiver)
  expect_equal(wide$sender_nv, ctrls$sender)
  expect_equal(wide$receiver_nv, ctrls$receiver)
  expect_equal(wide$reciprocity_count_ev, cases$reciprocity_count)
  expect_equal(wide$reciprocity_count_nv, ctrls$reciprocity_count)
  expect_equal(wide$d_reciprocity_count,
               cases$reciprocity_count - ctrls$reciprocity_count)
})

test_that("wide = TRUE requires exactly one control", {
  senders <- receivers <- paste0("a", 1:8)
  expect_error(
    simulate_relational_events(n_events = 5, senders = senders,
                               receivers = receivers, n_controls = 0,
                               wide = TRUE),
    "n_controls = 1"
  )
  expect_error(
    simulate_relational_events(n_events = 5, senders = senders,
                               receivers = receivers, n_controls = 2,
                               wide = TRUE),
    "n_controls = 1"
  )
})

test_that("wide = FALSE (default) leaves the long output unchanged", {
  senders <- receivers <- paste0("a", 1:8)
  set.seed(3)
  a <- simulate_relational_events(n_events = 10, senders = senders,
                                  receivers = receivers, n_controls = 1)
  set.seed(3)
  b <- simulate_relational_events(n_events = 10, senders = senders,
                                  receivers = receivers, n_controls = 1,
                                  wide = FALSE)
  expect_identical(a, b)
  expect_true(all(c("stratum", "event") %in% names(a)))
})

test_that("wide format carries multiple covariates and global covariates", {
  set.seed(11)
  senders <- receivers <- paste0("a", 1:10)
  gc <- data.frame(time_start = 0, congestion = 0.2)
  w <- simulate_relational_events(
    n_events           = 20,
    senders            = senders,
    receivers          = receivers,
    n_controls         = 1,
    endogenous_stats   = c("reciprocity_count", "reciprocity_binary"),
    endogenous_effects = c(reciprocity_count = 0.4, reciprocity_binary = 0.2),
    global_covariates  = gc,
    global_effects     = c(congestion = 0.5),
    wide               = TRUE
  )
  for (cov in c("reciprocity_count", "reciprocity_binary", "congestion")) {
    expect_true(all(paste0(cov, c("_ev", "_nv")) %in% names(w)))
    expect_true(paste0("d_", cov) %in% names(w))
    expect_equal(w[[paste0("d_", cov)]],
                 w[[paste0(cov, "_ev")]] - w[[paste0(cov, "_nv")]])
  }
})

test_that("wide = TRUE works with the tau_leap method", {
  set.seed(5)
  senders <- receivers <- paste0("a", 1:10)
  w <- simulate_relational_events(
    n_events           = 15,
    senders            = senders,
    receivers          = receivers,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6),
    method             = "tau_leap",
    tau                = 0.1,
    wide               = TRUE
  )
  expect_equal(nrow(w), 15L)
  expect_equal(w$d_reciprocity_count,
               w$reciprocity_count_ev - w$reciprocity_count_nv)
})
