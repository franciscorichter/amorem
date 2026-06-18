# Tests for the three workshop-driven fixes (issues #92, #93, #94):
#   #92  widen_case_control() carries the sender/receiver identifiers through.
#   #93  rem(method = "gam") widens long-format input instead of fitting garbage.
#   #94  endogenous_features() gains a prior_log warm-start argument.

make_long <- function(seed = 1, n_events = 200, stat, effect, half_life = NULL) {
  set.seed(seed)
  a <- paste0("a", 1:15)
  args <- list(
    n_events           = n_events,
    senders            = a,
    receivers          = a,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = stat,
    endogenous_effects = stats::setNames(effect, stat)
  )
  if (!is.null(half_life)) args$half_life <- half_life
  do.call(simulate_relational_events, args)
}

# ---- #92 -------------------------------------------------------------------

test_that("widen_case_control carries sender/receiver ids (#92)", {
  cc <- make_long(stat = "reciprocity_count", effect = 0.5)
  w <- widen_case_control(cc, case = "event", stratum = "stratum")

  expect_true(all(c("sender_ev", "receiver_ev", "sender_nv", "receiver_nv")
                  %in% names(w)))

  # The carried event ids must match the case rows of the source log, matched
  # by stratum (robust to row ordering).
  ev <- cc[cc$event == 1L, ]
  expect_equal(w$sender_ev,   as.character(ev$sender[match(w$stratum, ev$stratum)]))
  expect_equal(w$receiver_ev, as.character(ev$receiver[match(w$stratum, ev$stratum)]))

  # The carried control ids must be the matched control's dyad.
  ct <- cc[cc$event == 0L, ]
  expect_equal(w$sender_nv,   as.character(ct$sender[match(w$stratum, ct$stratum)]))
  expect_equal(w$receiver_nv, as.character(ct$receiver[match(w$stratum, ct$stratum)]))

  # keep_ids = FALSE restores the old, id-free output.
  w0 <- widen_case_control(cc, case = "event", stratum = "stratum",
                           keep_ids = FALSE)
  expect_false(any(c("sender_ev", "receiver_ev", "sender_nv", "receiver_nv")
                   %in% names(w0)))
})

# ---- #93 -------------------------------------------------------------------

test_that("rem(method = 'gam') auto-widens long-format input (#93)", {
  skip_if_not_installed("mgcv")
  raw <- make_long(stat = "reciprocity_exp_decay", effect = 0.8, half_life = 0.1)

  wide <- widen_case_control(raw, case = "event", stratum = "stratum")
  fit_wide <- rem(~ reciprocity_exp_decay, data = wide, method = "gam")

  # Long input is detected and widened, with a message (not silently wrong).
  expect_message(
    fit_long <- rem(~ reciprocity_exp_decay, data = raw, method = "gam"),
    "long-format"
  )
  # And it then reproduces the explicitly-widened fit exactly.
  expect_equal(unname(coef(fit_long)), unname(coef(fit_wide)))

  # Already-wide data fits without any message.
  expect_silent(rem(~ reciprocity_exp_decay, data = wide, method = "gam"))
})

# ---- #94 -------------------------------------------------------------------

test_that("endogenous_features prior_log warm-starts state (#94)", {
  prior_events <- data.frame(
    sender = c("A", "B"), receiver = c("B", "C"), time = c(1, 2)
  )
  cc_log <- data.frame(
    sender   = c("A", "B", "C", "C"),
    receiver = c("C", "C", "A", "A"),
    time     = c(3,   3,   4,   4),
    event    = c(1,   0,   1,   0)
  )
  stat <- "transitivity_binary_interrupted"
  events_only <- cc_log[cc_log$event == 1L, c("sender", "receiver", "time")]

  out <- endogenous_features(
    event_log   = cc_log,
    prior_log   = prior_events,
    history_log = events_only,
    stats       = stat
  )

  # Prior rows never appear in the output; the event_log is returned intact.
  expect_equal(nrow(out), nrow(cc_log))
  expect_equal(out$sender, cc_log$sender)
  expect_equal(out$time, cc_log$time)

  # The warm-started A -> C event sees the A -> B, B -> C two-path (value 1);
  # this is the value the documented prepend-and-trim workaround produces.
  full_log <- rbind(prior_events, cc_log[, c("sender", "receiver", "time")])
  ref <- endogenous_features(
    event_log   = full_log,
    stats       = stat,
    history_log = rbind(prior_events, events_only)
  )
  ref <- ref[ref$time >= 3, ]
  expect_equal(out[[stat]], ref[[stat]])
  expect_equal(out[[stat]][1], 1L)   # A -> C is warm-started to 1
})

test_that("without prior_log the warm-start is lost (#94 motivation)", {
  prior_events <- data.frame(
    sender = c("A", "B"), receiver = c("B", "C"), time = c(1, 2)
  )
  cc_log <- data.frame(
    sender   = c("A", "B", "C", "C"),
    receiver = c("C", "C", "A", "A"),
    time     = c(3,   3,   4,   4),
    event    = c(1,   0,   1,   0)
  )
  stat <- "transitivity_binary_interrupted"
  events_only <- cc_log[cc_log$event == 1L, c("sender", "receiver", "time")]

  # Passing the prior events through history_log only (the intuitive-but-wrong
  # call) does not warm-start the state: A -> C is 0, not 1.
  wrong <- endogenous_features(
    event_log   = cc_log,
    history_log = rbind(prior_events, events_only),
    stats       = stat
  )
  expect_equal(wrong[[stat]][1], 0L)
})

test_that("prior_log is honoured for the sender_receivers_set list-column (#94)", {
  prior_events <- data.frame(
    sender = "X", receiver = "Y", time = 1
  )
  ev <- data.frame(
    sender   = c("X", "X"),
    receiver = c("Z", "Y"),
    time     = c(2,   3),
    event    = c(1,   1)
  )
  out <- endogenous_features(
    event_log = ev,
    prior_log = prior_events,
    stats     = "sender_receivers_set"
  )
  expect_equal(nrow(out), 2L)
  # Before its first in-window event, X has already reached Y (from prior_log).
  expect_equal(sort(out$sender_receivers_set[[1]]), "Y")
  # Before the second event, X has reached Y (prior) and Z (first event).
  expect_equal(sort(out$sender_receivers_set[[2]]), c("Y", "Z"))
})
