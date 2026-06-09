make_attrs <- function() {
  list(
    sa = setNames(c(5, 4, 6, 5.5), paste0("S", 1:4)),
    ra = setNames(c(3, 1, 4, 2.5), paste0("R", 1:4))
  )
}

test_that("output has the documented case-control structure", {
  a <- make_attrs()
  set.seed(1)
  d <- simulate_directed_hyperevents_tvnl(a$sa, a$ra, horizon = 2, n_controls = 1)

  expect_s3_class(d, "data.frame")
  expect_identical(
    names(d),
    c("event_id", "event_time", "event", "sender_group", "receiver_group",
      "cov_sender", "cov_receiver")
  )
  expect_true(all(d$event %in% c(0L, 1L)))
  expect_gt(nrow(d), 0)
  # one event + one control per stratum
  n_events <- sum(d$event == 1L)
  expect_equal(sum(d$event == 0L), n_events)              # n_controls = 1
  expect_equal(length(unique(d$event_id)), n_events)
  # event_time non-decreasing
  expect_false(is.unsorted(d$event_time))
  # truth attribute carried for plotting against fitted smooths
  truth <- attr(d, "truth")
  expect_true(is.function(truth$time_varying_effect))
  expect_true(is.function(truth$nonlinear_effect))
})

test_that("group covariates equal the mean of member attributes", {
  a <- make_attrs()
  set.seed(2)
  d <- simulate_directed_hyperevents_tvnl(a$sa, a$ra, horizon = 1.5)
  # decode a sender group label like "{S1,S3}" and recompute its mean
  decode <- function(lbl) strsplit(gsub("[{}]", "", lbl), ",")[[1]]
  for (i in sample(seq_len(nrow(d)), min(10, nrow(d)))) {
    s_mean <- mean(a$sa[decode(d$sender_group[i])])
    r_mean <- mean(a$ra[decode(d$receiver_group[i])])
    expect_equal(d$cov_sender[i], unname(s_mean))
    expect_equal(d$cov_receiver[i], unname(r_mean))
  }
})

test_that("n_controls controls the case-control ratio", {
  a <- make_attrs()
  set.seed(3)
  d <- simulate_directed_hyperevents_tvnl(a$sa, a$ra, horizon = 1.5, n_controls = 3)
  n_events <- sum(d$event == 1L)
  expect_equal(sum(d$event == 0L), 3L * n_events)
})

test_that("max_group_size = 1 reduces to single-actor (dyadic) groups", {
  a <- make_attrs()
  set.seed(4)
  d <- simulate_directed_hyperevents_tvnl(
    a$sa, a$ra, horizon = 1.5,
    max_group_size_sender = 1, max_group_size_receiver = 1
  )
  # every group is a single actor, e.g. "{S2}"
  expect_true(all(grepl("^\\{[^,]+\\}$", d$sender_group)))
  expect_true(all(grepl("^\\{[^,]+\\}$", d$receiver_group)))
})

test_that("the simulation is reproducible under a fixed seed", {
  a <- make_attrs()
  set.seed(99); d1 <- simulate_directed_hyperevents_tvnl(a$sa, a$ra, horizon = 1.5)
  set.seed(99); d2 <- simulate_directed_hyperevents_tvnl(a$sa, a$ra, horizon = 1.5)
  expect_equal(d1, d2)
})

test_that("inputs are validated", {
  a <- make_attrs()
  expect_error(simulate_directed_hyperevents_tvnl(unname(a$sa), a$ra),
               "named numeric")
  expect_error(simulate_directed_hyperevents_tvnl(a$sa, a$ra, dt = 5, horizon = 2),
               "smaller than")
  expect_error(
    simulate_directed_hyperevents_tvnl(a$sa, a$ra, time_varying_effect = 1),
    "must be functions"
  )
})
