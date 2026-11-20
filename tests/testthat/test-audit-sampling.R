# Regression tests for the 1.3.0 pre-release audit (AUDIT.md), sampling and
# feature-computation items: 1, 2, 3, 4, 13, 14, 15, 17, 27 and decisions D1-D3.

muffle_repeat <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("fire more than once", conditionMessage(w))) invokeRestart("muffleWarning")
  })
}

# ---- Item 1 / D2: tied times, both engines -----------------------------

test_that("the pure-R path reads a whole timestamp before adding its events (item 1)", {
  cc <- data.frame(stratum = c(1, 1, 2, 2, 3, 3), event = c(1, 0, 1, 0, 1, 0),
                   sender = c("A", "B", "C", "B", "B", "A"),
                   receiver = c("B", "A", "D", "A", "A", "C"),
                   time = c(1, 1, 2, 2, 3, 3))
  cpp <- endogenous_features(cc, "reciprocity")$reciprocity
  r_path <- endogenous_features(cc, c("reciprocity", "reciprocity_time_recent"))$reciprocity
  expect_equal(cpp, c(0, 0, 0, 1, 1, 0))
  expect_equal(r_path, cpp)
})

test_that("tied events never see each other, with or without a mask (D2)", {
  el <- data.frame(sender = c("A", "B"), receiver = c("B", "A"), time = c(1, 1))
  expect_equal(endogenous_features(el, "reciprocity")$reciprocity, c(0L, 0L))
  expect_equal(endogenous_features(el, c("reciprocity", "reciprocity_time_recent"))$reciprocity,
               c(0L, 0L))
  expect_equal(endogenous_features(el, "reciprocity", history_log = el)$reciprocity,
               c(0L, 0L))
})

test_that("C++ and pure-R engines agree on tied logs, masked and unmasked (D2)", {
  set.seed(11)
  a <- letters[1:6]
  ev <- data.frame(sender = sample(a, 150, TRUE), receiver = sample(a, 150, TRUE),
                   time = sort(sample(1:30, 150, TRUE)), stringsAsFactors = FALSE)
  ev <- ev[ev$sender != ev$receiver, ]
  cc <- sample_non_events(ev, n_controls = 2, seed = 3)
  st <- c("sender_outdegree", "receiver_indegree", "reciprocity_count", "recency",
          "transitivity_count", "cyclic_count", "sending_balance_count",
          "receiving_balance_count", "transitivity_count_ordered")
  for (x in list(ev, cc)) {
    cpp <- endogenous_features(x, st)
    rr <- endogenous_features(x, c(st, "reciprocity_time_recent"))
    expect_equal(rr[st], cpp[st])
  }
  # Brute force: events with the same sender strictly before the row's time.
  f <- endogenous_features(cc, "sender_outdegree")
  brute <- mapply(function(s, t) sum(ev$sender == s & ev$time < t), f$sender, f$time)
  expect_equal(unname(f$sender_outdegree), unname(brute))
  srs <- endogenous_features(cc, c("sender_receivers_set", "sender_outdegree"))
  expect_true(all(lengths(srs$sender_receivers_set) <= srs$sender_outdegree))
})

# ---- Item 2: events are the case rows ----------------------------------

test_that("history_log does not count a control that equals a same-time event (item 2)", {
  E <- data.frame(sender = c("A", "C", "A"), receiver = c("B", "D", "E"), time = c(1, 1, 2))
  cc <- sample_non_events(E, 3, seed = 17)
  # the seed draws control A -> B at t = 1 for stratum 2
  expect_true(any(cc$event == 0L & cc$sender == "A" & cc$receiver == "B" & cc$time == 1))
  f <- endogenous_features(cc, "sender_outdegree", history_log = E)
  row <- which(cc$event == 1L & cc$sender == "A" & cc$receiver == "E")
  expect_equal(f$sender_outdegree[row], 1)
  # the same through prior_log
  g <- endogenous_features(cc, "sender_outdegree", history_log = E,
                           prior_log = data.frame(sender = "A", receiver = "Z", time = 0))
  expect_equal(g$sender_outdegree[row], 2)
})

test_that("a factor event column is read by its labels", {
  cc <- data.frame(event = factor(c("1", "0", "1")), sender = c("A", "A", "A"),
                   receiver = c("B", "C", "D"), time = c(1, 1, 2))
  f <- endogenous_features(cc, "sender_outdegree")
  expect_equal(f$sender_outdegree, c(0, 0, 1))
})

# ---- Item 3: appearance per timestamp ----------------------------------

test_that("scope = 'appearance' admits only actors seen strictly before t (item 3)", {
  toy <- data.frame(sender = c("A", "C", "E"), receiver = c("B", "D", "F"), time = c(1, 1, 2))
  cc <- sample_non_events(toy, 3, scope = "appearance", seed = 1)
  expect_false(any(cc$event == 0L & cc$stratum %in% 1:2))
  ctrl <- cc[cc$event == 0L, ]
  expect_true(all(c(ctrl$sender, ctrl$receiver) %in% c("A", "B", "C", "D")))

  data(classroom_events, package = "amorem", envir = environment())
  cc <- muffle_repeat(sample_non_events(classroom_events, 5, scope = "appearance", seed = 1))
  ev <- cc[cc$event == 1L, ]
  first_seen <- tapply(c(ev$time, ev$time), c(ev$sender, ev$receiver), min)
  ctrl <- cc[cc$event == 0L, ]
  expect_true(all(first_seen[ctrl$sender] < ctrl$time))
  expect_true(all(first_seen[ctrl$receiver] < ctrl$time))
})

# ---- Item 4: unsorted input --------------------------------------------

test_that("sample_non_events() orders an unsorted log by time (item 4)", {
  toy2 <- data.frame(sender = c("C", "A", "B"), receiver = c("D", "B", "A"), time = c(3, 1, 2))
  cc <- sample_non_events(toy2, 2, scope = "appearance", seed = 1)
  ev <- cc[cc$event == 1L, ]
  expect_equal(ev$time, c(1, 2, 3))
  expect_equal(ev$stratum, 1:3)
  ctrl <- cc[cc$event == 0L, ]
  # nothing had appeared before t = 1; C and D appear only at t = 3
  expect_false(any(ctrl$time == 1))
  expect_false(any(c(ctrl$sender, ctrl$receiver) %in% c("C", "D")))
  # same result as sorting first
  expect_equal(cc, sample_non_events(toy2[order(toy2$time), ], 2,
                                     scope = "appearance", seed = 1))
})

# ---- Item 13: standardize_event_log() times ----------------------------

test_that("standardize_event_log() reads factor times by label and rejects text dates (item 13)", {
  df <- data.frame(sender = c("a", "b"), receiver = c("b", "a"),
                   time = factor(c("10", "2")))
  out <- standardize_event_log(df)
  expect_equal(out$time, c(2, 10))
  expect_equal(out$sender, c("b", "a"))
  txt <- data.frame(sender = "a", receiver = "b", time = "2024-01-05")
  expect_error(standardize_event_log(txt), "not a number")
  num_txt <- data.frame(sender = c("a", "b"), receiver = c("b", "a"), time = c("1.5", "0.5"))
  expect_equal(standardize_event_log(num_txt)$time, c(0.5, 1.5))
  dt <- data.frame(sender = "a", receiver = "b", time = as.Date("2024-01-05"))
  expect_equal(standardize_event_log(dt)$time, as.numeric(as.Date("2024-01-05")))
})

# ---- Item 14: NA times --------------------------------------------------

test_that("NA times are rejected, and the compiled loop returns on NaN (item 14)", {
  ev <- data.frame(sender = c("A", "B", "C"), receiver = c("B", "A", "A"), time = c(1, 2, NA))
  expect_error(endogenous_features(ev, "reciprocity", history_log = ev), "NA")
  expect_error(endogenous_features(ev, "reciprocity"), "NA")
  ok <- ev[1:2, ]
  expect_error(endogenous_features(ok, "reciprocity", history_log = ev), "history_log")
  expect_error(endogenous_features(ok, "reciprocity", prior_log = ev), "prior_log")
  expect_error(sample_non_events(ev, 1), "NA")
  out <- amorem:::compute_features_cpp(c("A", "B", "C"), c("B", "A", "A"),
                                       c(1, NaN, NaN), "reciprocity",
                                       c(TRUE, TRUE, TRUE), NA_real_)
  expect_length(out$reciprocity, 3L)
})

# ---- Item 15: rare valid controls --------------------------------------

test_that("a valid control that rejection draws miss is found by enumeration (item 15)", {
  regions <- paste0("r", 1:200)
  el <- data.frame(sender = "sp", receiver = regions, time = seq_along(regions))
  # the last event has no region left; it is not at the start of the log
  expect_warning(
    cc <- sample_non_events(el, 1, mode = "two", risk = "remove",
                            max_attempts = 3, seed = 1),
    "1 of 200 event")
  expect_equal(attr(cc, "no_control"), 200L)
  ctrl <- cc[cc$event == 0L, ]
  expect_equal(nrow(ctrl), 199L)
  # every control is a region not yet invaded and not the event's own
  k <- as.integer(sub("r", "", ctrl$receiver))
  expect_true(all(k > ctrl$stratum))
})

# ---- Item 17: shifted sampling ------------------------------------------

test_that("shift = 'exponential' keeps Date and POSIXct times (item 17)", {
  set.seed(2)
  a <- letters[1:5]
  base <- data.frame(sender = sample(a, 40, TRUE), receiver = sample(a, 40, TRUE),
                     time = sort(runif(40, 0, 50)), stringsAsFactors = FALSE)
  base <- base[base$sender != base$receiver, ]
  d <- base; d$time <- as.Date("2020-01-01") + d$time
  cd <- suppressWarnings(sample_non_events(d, 1, shift = "exponential", seed = 1))
  expect_s3_class(cd$time, "Date")
  expect_true(all(cd$time >= min(d$time) & cd$time <= max(d$time)))
  p <- base; p$time <- as.POSIXct("2020-01-01", tz = "UTC") + p$time * 3600
  cc <- suppressWarnings(sample_non_events(p, 1, shift = "exponential", seed = 1))
  expect_s3_class(cc$time, "POSIXct")
  expect_equal(attr(cc$time, "tzone"), "UTC")
  expect_true(all(cc$time >= min(p$time) & cc$time <= max(p$time)))
  # controls carry their own (back-shifted) times
  ctrl <- cd[cd$event == 0L, ]
  expect_gt(nrow(ctrl), 0L)
})

test_that("shift = 'exponential' on a single timestamp gives no controls and warns (item 17)", {
  el <- data.frame(sender = c("a", "b", "c"), receiver = c("b", "c", "a"), time = 5)
  expect_warning(cc <- sample_non_events(el, 1, shift = "exponential", seed = 1),
                 "3 of 3 event")
  expect_equal(sum(cc$event == 0L), 0L)
  expect_equal(attr(cc, "no_control"), 1:3)
})

test_that("shift = 'exponential' emits the no-control warning (item 17)", {
  two <- data.frame(sender = c("a", "b"), receiver = c("b", "a"), time = c(1, 2))
  expect_warning(sample_non_events(two, mode = "two", seed = 1, shift = "exponential",
                                   exclude_pairs = two[, 1:2]),
                 "no valid control")
})

# ---- Item 27: n_controls -------------------------------------------------

test_that("non-integer n_controls is an error (item 27)", {
  el <- data.frame(sender = c("a", "b"), receiver = c("b", "c"), time = 1:2)
  expect_error(sample_non_events(el, 1.5), "positive integer")
  expect_error(sample_non_events(el, NA_real_), "positive integer")
  expect_silent(sample_non_events(el, 2, seed = 1))
})

# ---- D1: citation receivers ---------------------------------------------

test_that("scope = 'citation' draws cited-only papers as control receivers (D1)", {
  # p1..p20 each cite one of the classics c1..c5, which never cite anything
  set.seed(3)
  cit <- data.frame(sender = paste0("p", 1:20),
                    receiver = sample(paste0("c", 1:5), 20, TRUE), time = 1:20)
  cc <- suppressWarnings(sample_non_events(cit, 3, scope = "citation", seed = 1))
  ctrl <- cc[cc$event == 0L, ]
  expect_true(any(grepl("^c", ctrl$receiver)))
  seen <- tapply(c(cit$time, cit$time), c(cit$sender, cit$receiver), min)
  ev <- cc[cc$event == 1L, ]
  own_r <- ev$receiver[match(ctrl$stratum, ev$stratum)]
  expect_true(all(seen[ctrl$receiver] < ctrl$time | ctrl$receiver == own_r))
  expect_true(all(ctrl$sender == ev$sender[match(ctrl$stratum, ev$stratum)]))
})

# ---- D3: no-control warning at the start of the log ---------------------

test_that("the no-control warning skips the start of the log only (D3)", {
  data(classroom_events, package = "amorem", envir = environment())
  msgs <- character(0)
  cc <- withCallingHandlers(
    sample_non_events(classroom_events, 5, scope = "appearance", risk = "remove", seed = 1),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  expect_false(any(grepl("no valid control", msgs)))
  expect_true(length(attr(cc, "no_control")) > 0L)
  cc <- withCallingHandlers(
    sample_non_events(classroom_events, 5, risk = "remove", seed = 1),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  expect_false(any(grepl("no valid control", msgs)))
  # a starved event later in the log still warns
  el <- data.frame(sender = c("a", "b", "c", "a"), receiver = c("b", "c", "a", "c"),
                   time = 1:4)
  expect_warning(sample_non_events(el, 1, exclude_pairs = data.frame(
    sender = c("a", "b", "b", "c", "c"), receiver = c("b", "a", "c", "a", "b"))),
    "1 of 4 event")
})
