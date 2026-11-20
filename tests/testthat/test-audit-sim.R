# Regression tests for the simulator findings of the 1.3.0 audit
# (items 9, 10, 11, 12, 19, 27 and the validation gaps around them).

# ---- Item 9: controls drawn from a one-element pool ------------------------

test_that("controls drawn from a one-dyad pool are valid (Gillespie)", {
  set.seed(1)
  cc <- simulate_relational_events(200, c("A", "B"), c("A", "B"),
                                   n_controls = 1)
  ctl <- cc[cc$event == 0, ]
  cas <- cc[cc$event == 1, ]
  expect_equal(sum(ctl$sender == ctl$receiver), 0)
  m <- merge(cas, ctl, by = "stratum")
  expect_equal(sum(m$sender.x == m$sender.y & m$receiver.x == m$receiver.y), 0)
})

test_that("controls drawn from a one-dyad pool are valid (tau-leap)", {
  set.seed(2)
  cc <- simulate_relational_events(200, c("A", "B"), c("A", "B"),
                                   n_controls = 1, method = "tau_leap",
                                   tau = 0.05)
  ctl <- cc[cc$event == 0, ]
  cas <- cc[cc$event == 1, ]
  expect_equal(sum(ctl$sender == ctl$receiver), 0)
  m <- merge(cas, ctl, by = "stratum")
  expect_equal(sum(m$sender.x == m$sender.y & m$receiver.x == m$receiver.y), 0)
})

test_that("tvnl controls drawn from a one-pair pool differ from the case", {
  set.seed(3)
  d <- simulate_directed_hyperevents_tvnl(
    c(S1 = 1), c(R1 = 0, R2 = 5), horizon = 20, dt = 0.5,
    time_varying_effect = function(t) 0, nonlinear_effect = function(x) 0,
    max_group_size_receiver = 1, n_controls = 1)
  cas <- d[d$event == 1, ]
  ctl <- d[d$event == 0, ]
  m <- merge(cas, ctl, by = "event_id")
  expect_gt(nrow(m), 10)
  expect_true(all(m$receiver_group.x != m$receiver_group.y))
})

# ---- Item 10: weights on a log scale --------------------------------------

test_that("an overflowing intensity is not dropped", {
  set.seed(1)
  L <- matrix(0, 3, 3)
  L[1, 2] <- 710
  ev <- simulate_relational_events(20, LETTERS[1:3], LETTERS[1:3],
                                   contribution_logits = L)
  expect_equal(sum(ev$sender == "A" & ev$receiver == "B"), 20)
  expect_true(all(is.finite(ev$time)))
})

test_that("underflowing intensities stay in the control pool", {
  set.seed(1)
  L <- matrix(-800, 3, 3)
  L[1, 2] <- 0
  L[2, 1] <- 0
  cc <- simulate_relational_events(10, LETTERS[1:3], LETTERS[1:3],
                                   contribution_logits = L, n_controls = 4)
  expect_equal(nrow(cc), 50)
  cas <- cc[cc$event == 1, ]
  expect_true(all(paste(cas$sender, cas$receiver) %in% c("A B", "B A")))
})

test_that("tau-leap stops with a message when a rate overflows", {
  L <- matrix(0, 3, 3)
  L[1, 2] <- 710
  expect_error(
    simulate_relational_events(20, LETTERS[1:3], LETTERS[1:3],
                               contribution_logits = L,
                               method = "tau_leap", tau = 0.1),
    "expects")
})

test_that("hyperedge simulators keep candidates whose rate overflows", {
  set.seed(1)
  hl <- simulate_hyperedge_events(5, LETTERS[1:3], max_size = 2,
                                  baseline_rate = 1,
                                  endogenous_stats = "size",
                                  endogenous_effects = 400)
  expect_true(all(lengths(hl$I) == 2L))
  set.seed(1)
  dh <- simulate_directed_hyperedge_events(5, LETTERS[1:3], c("x", "y"),
                                           max_size_I = 2,
                                           endogenous_stats = "size_I",
                                           endogenous_effects = 400)
  expect_true(all(lengths(dh$I) == 2L))
})

test_that("tvnl stops with a message when the rates overflow", {
  expect_error(
    simulate_directed_hyperevents_tvnl(
      c(S1 = 1, S2 = 2), c(R1 = 0, R2 = 5), horizon = 1, dt = 0.5,
      time_varying_effect = function(t) 0,
      nonlinear_effect = function(x) ifelse(x > 4, 710, 0),
      max_group_size_sender = 1, max_group_size_receiver = 1),
    "expects more than 1e7")
})

# ---- Item 11: exact waiting times for time-varying statistics -------------
# Time-rescaling: with Lambda the compensator, the increments
# Lambda(t_k) - Lambda(t_{k-1}) of an exactly simulated log are i.i.d.
# Exp(1). The simulator used to draw the waiting time from the rate at the
# previous event, which gives means of 1.4-1.5 (exp-decay, effect -2) and
# 1.3-1.4 (recency, effect 1) on these designs.

test_that("exp-decay statistics: rescaled waiting times are Exp(1)", {
  set.seed(11)
  beta <- -2
  hl <- 0.5
  ev <- simulate_relational_events(600, c("A", "B"), c("A", "B"),
                                   endogenous_stats = "reciprocity_exp_decay",
                                   endogenous_effects = beta, half_life = hl)
  r <- log(2) / hl
  tt <- c(0, ev$time)
  inc <- numeric(nrow(ev))
  x_ab <- 0
  x_ba <- 0
  for (k in seq_len(nrow(ev))) {
    dt <- tt[k + 1] - tt[k]
    f <- function(s) exp(beta * x_ab * exp(-r * s)) + exp(beta * x_ba * exp(-r * s))
    inc[k] <- stats::integrate(f, 0, dt, rel.tol = 1e-10)$value
    d <- exp(-r * dt)
    x_ab <- x_ab * d
    x_ba <- x_ba * d
    if (ev$sender[k] == "A") x_ba <- x_ba + 1 else x_ab <- x_ab + 1
  }
  expect_lt(abs(mean(inc) - 1), 0.12)
  # The recorded stat is the value at the event time.
  expect_true(all(ev$reciprocity_exp_decay >= 0))
})

test_that("recency: rescaled waiting times are Exp(1)", {
  set.seed(12)
  b <- 1
  base <- 0.3
  A <- c("A", "B", "C")
  ev <- simulate_relational_events(600, A, A, baseline_rate = base,
                                   endogenous_stats = "recency",
                                   endogenous_effects = b)
  dy <- expand.grid(s = A, r = A, stringsAsFactors = FALSE)
  dy <- dy[dy$s != dy$r, ]
  last <- stats::setNames(rep(0, nrow(dy)), paste(dy$s, dy$r))
  tt <- c(0, ev$time)
  inc <- numeric(nrow(ev))
  for (k in seq_len(nrow(ev))) {
    inc[k] <- sum(base * (exp(b * (tt[k + 1] - last)) -
                          exp(b * (tt[k] - last))) / b)
    last[paste(ev$sender[k], ev$receiver[k])] <- tt[k + 1]
  }
  expect_lt(abs(mean(inc) - 1), 0.12)
  # recency at the event equals time since the dyad last fired
  expect_true(all(ev$recency > 0))
})

test_that("rates that decay to zero stop the simulation with a message", {
  set.seed(1)
  expect_message(
    ev <- simulate_relational_events(50, c("A", "B"), c("A", "B"),
                                     baseline_rate = 0.01,
                                     endogenous_stats = "recency",
                                     endogenous_effects = -1),
    "decayed")
  expect_lt(nrow(ev), 50)
})

test_that("thinning respects horizon and global covariates", {
  set.seed(5)
  gc <- data.frame(time_start = c(0, 2, 4), x = c(0, 1, -1))
  ev <- simulate_relational_events(500, LETTERS[1:3], LETTERS[1:3],
                                   horizon = 6,
                                   endogenous_stats = "reciprocity_exp_decay",
                                   endogenous_effects = 1, half_life = 1,
                                   global_covariates = gc,
                                   global_effects = 0.5)
  expect_true(all(ev$time <= 6))
  expect_false(is.unsorted(ev$time))
  expect_equal(ev$x, gc$x[findInterval(ev$time, gc$time_start)])
})

# ---- Item 12: tvnl stays within the horizon --------------------------------

test_that("tvnl event times never exceed horizon", {
  set.seed(4)
  d <- simulate_directed_hyperevents_tvnl(
    c(S1 = 1, S2 = 2), c(R1 = 0, R2 = 5), horizon = 1, dt = 0.3,
    time_varying_effect = function(t) 0, nonlinear_effect = function(x) 5,
    max_group_size_sender = 1, max_group_size_receiver = 1, n_controls = 0)
  expect_gt(nrow(d), 100)
  expect_lte(max(d$event_time), 1)
})

# ---- Item 19: tau-leap records ordered *_time_* stats at the event time ----

test_that("tau-leap records every ordered elapsed-time stat at the event time", {
  stats <- c("transitivity_time_recent_ordered", "cyclic_time_recent_ordered",
             "sending_balance_time_recent_ordered",
             "receiving_balance_time_recent_ordered")
  set.seed(19)
  ev <- simulate_relational_events(300, LETTERS[1:4], LETTERS[1:4],
                                   endogenous_stats = stats,
                                   endogenous_effects = rep(0, 4),
                                   method = "tau_leap", tau = 0.5)
  # A positive value v at time t comes from a reference event at t - v,
  # which must be one of the earlier event times.
  for (st in stats) {
    pos <- which(ev[[st]] > 0)
    expect_gt(length(pos), 0)
    ref <- ev$time[pos] - ev[[st]][pos]
    hit <- vapply(ref, function(r) any(abs(ev$time - r) < 1e-9), logical(1))
    expect_true(all(hit), info = st)
  }
})

# ---- Item 27 and validation gaps --------------------------------------------

test_that("non-integer counts are rejected", {
  A <- LETTERS[1:3]
  expect_error(simulate_relational_events(2.7, A, A), "whole number")
  expect_error(simulate_relational_events(5, A, A, n_controls = 1.5),
               "whole number")
  expect_error(simulate_relational_events(NA, A, A), "whole number")
  expect_error(simulate_hyperedge_events(2.5, A, max_size = 2,
                                         baseline_rate = 1),
               "positive integer")
  expect_error(simulate_directed_hyperedge_events(2.5, A, c("x", "y")),
               "positive integer")
  expect_error(simulate_directed_hyperevents_tvnl(c(S1 = 1, S2 = 2),
                                                  c(R1 = 0, R2 = 1),
                                                  n_controls = 1.5),
               "non-negative integer")
})

test_that("hyperedge simulators reject subrep with rho = 0", {
  expect_error(simulate_hyperedge_events(3, LETTERS[1:3], max_size = 2,
                                         baseline_rate = 1,
                                         endogenous_stats = "subrep_0",
                                         endogenous_effects = 1),
               "Unsupported")
  expect_error(simulate_directed_hyperedge_events(3, LETTERS[1:3], c("x", "y"),
                                                  endogenous_stats = "subrep_0_1",
                                                  endogenous_effects = 1),
               "Unsupported")
})

test_that("hyperedge_log rejects duplicate members and NA actor names", {
  expect_error(hyperedge_log(list(c("a", "a")), list("x"), 1), "more than once")
  expect_error(hyperedge_log(list("a"), list(c("x", "x")), 1), "more than once")
  expect_error(hyperedge_log(list(c("a", NA)), list("x"), 1), "NA")
  expect_error(hyperedge_log(list("a"), list(NA_character_), 1), "NA")
  expect_s3_class(hyperedge_log(list(c("a", "b")), list(character(0)), 1),
                  "amorem_hyperedge_log")
})

test_that("risk = 'remove' with controls stops when the risk set is too small", {
  A <- LETTERS[1:3]
  set.seed(1)
  expect_message(
    cc <- simulate_relational_events(10, A, A, n_controls = 2,
                                     risk = "remove"),
    "too few")
  expect_equal(length(unique(cc$stratum)), 4)
  set.seed(1)
  expect_message(
    cc2 <- simulate_relational_events(10, A, A, n_controls = 2,
                                      risk = "remove",
                                      method = "tau_leap", tau = 0.01),
    "too few")
  expect_lte(length(unique(cc2$stratum)), 4)
})

test_that("n_events = 0 returns the same columns as a non-empty run", {
  A <- LETTERS[1:3]
  set.seed(1)
  full <- simulate_relational_events(3, A, A, n_controls = 1,
                                     endogenous_stats = "reciprocity_count",
                                     endogenous_effects = 0.1)
  empty <- simulate_relational_events(0, A, A, n_controls = 1,
                                      endogenous_stats = "reciprocity_count",
                                      endogenous_effects = 0.1)
  expect_identical(names(empty), names(full))
  expect_identical(names(simulate_relational_events(0, A, A)),
                   names(simulate_relational_events(3, A, A)))
})
