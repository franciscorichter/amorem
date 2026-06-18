# Tests for the history_log / non-event support in endogenous_features().
# The non-events must have their statistics computed against the true event
# history WITHOUT entering (polluting) that history.

make_cc <- function(seed = 1, n_events = 200, stats, effects) {
  set.seed(seed)
  senders <- receivers <- paste0("a", 1:15)
  simulate_relational_events(
    n_events           = n_events,
    senders            = senders,
    receivers          = receivers,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = stats,
    endogenous_effects = effects
  )
}

test_that("post-hoc features with history_log reproduce the simulator (events + non-events)", {
  # The simulator computes each row's endogenous stats from the realized
  # event history at that row's time -- independently of compute_*(). So a
  # correct history-aware post-hoc pass must reproduce them exactly, for
  # both event rows and (sampled) non-event rows.
  cc <- make_cc(stats = c("reciprocity_count", "transitivity_count"),
                effects = c(reciprocity_count = 0.5, transitivity_count = 0.2))

  df <- cc[, c("sender", "receiver", "time")]
  df$row_id <- seq_len(nrow(df))
  events_only <- cc[cc$event == 1L, c("sender", "receiver", "time")]

  rec <- endogenous_features(
    df,
    stats       = c("reciprocity_count", "transitivity_count"),
    history_log = events_only
  )
  rec <- rec[order(rec$row_id), ]

  expect_equal(rec$reciprocity_count, cc$reciprocity_count)
  expect_equal(rec$transitivity_count, cc$transitivity_count)
})

test_that("without history_log the non-events DO pollute the history (the bug)", {
  # Same data, but treat every row as an event. The non-events now enter the
  # history, so the recomputed stats must differ from the simulator's truth.
  cc <- make_cc(stats = "reciprocity_count", effects = c(reciprocity_count = 0.5))
  df <- cc[, c("sender", "receiver", "time")]
  df$row_id <- seq_len(nrow(df))

  bug <- endogenous_features(df, stats = "reciprocity_count")
  bug <- bug[order(bug$row_id), ]

  expect_false(isTRUE(all.equal(bug$reciprocity_count, cc$reciprocity_count)))
})

test_that("event rows are identical whether or not non-events are present", {
  # Computing features on the events alone must equal the event rows of a
  # history-aware pass over events + non-events.
  cc <- make_cc(stats = "reciprocity_count", effects = c(reciprocity_count = 0.5))
  events_only <- cc[cc$event == 1L, c("sender", "receiver", "time")]

  feat_events <- endogenous_features(events_only, stats = "reciprocity_count")

  df <- cc[, c("sender", "receiver", "time")]
  df$is_ev <- cc$event == 1L
  full <- endogenous_features(df, stats = "reciprocity_count",
                                      history_log = events_only)
  ev_rows <- full[full$is_ev, ]
  ev_rows <- ev_rows[order(ev_rows$time), ]
  feat_events <- feat_events[order(feat_events$time), ]

  expect_equal(ev_rows$reciprocity_count, feat_events$reciprocity_count)
})

test_that("a non-event reads reverse-dyad history strictly before its time", {
  # Hand-built example: events a->b at t=1, a->b at t=2, b->a (reverse) only
  # via history. Non-event b->a at t=3 should see reciprocity_count = 2
  # (two prior a->b events), but must not itself update the history.
  events <- data.frame(
    sender   = c("a", "a"),
    receiver = c("b", "b"),
    time     = c(1, 2),
    stringsAsFactors = FALSE
  )
  combined <- rbind(
    events,
    data.frame(sender = "b", receiver = "a", time = 3, stringsAsFactors = FALSE)
  )
  res <- endogenous_features(combined, stats = "reciprocity_count",
                                     history_log = events)
  res <- res[order(res$time), ]
  # the b->a row at t=3 sees 2 prior a->b events
  expect_equal(res$reciprocity_count[res$time == 3], 2)
  # and the b->a non-event did not create reverse history for anyone else:
  # recomputing a->b at a later time still sees 0 reverse (b->a) events
  combined2 <- rbind(combined,
                     data.frame(sender = "a", receiver = "b", time = 4,
                                stringsAsFactors = FALSE))
  res2 <- endogenous_features(combined2, stats = "reciprocity_count",
                                      history_log = events)
  expect_equal(res2$reciprocity_count[res2$time == 4], 0)
})

test_that("history_log is validated", {
  events <- data.frame(sender = "a", receiver = "b", time = 1,
                       stringsAsFactors = FALSE)
  expect_error(
    endogenous_features(events, stats = "reciprocity_count",
                                history_log = list(1, 2)),
    "must be a data.frame"
  )
  expect_error(
    endogenous_features(events, stats = "reciprocity_count",
                                history_log = data.frame(sender = "a")),
    "missing required column"
  )
})
