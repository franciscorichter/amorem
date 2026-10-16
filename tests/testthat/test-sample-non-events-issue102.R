# Tests for the sample_non_events() risk-set edge cases of issue #102.

test_that("exclude_pairs that remove every valid pair skip the stratum instead of erroring", {
  el <- data.frame(sender = c("a", "b"), receiver = c("b", "a"), time = c(1, 2),
                   stringsAsFactors = FALSE)
  # mode = "two": the only alternative to each event is the other event's dyad.
  forbidden <- data.frame(sender = c("a", "b"), receiver = c("b", "a"))
  cc <- sample_non_events(el, n_controls = 1, mode = "two",
                          exclude_pairs = forbidden, max_attempts = 50, seed = 1)
  expect_equal(sum(cc$event == 0L), 0L)
  expect_equal(sum(cc$event == 1L), 2L)
})

test_that("a stratum whose only alternatives are concurrent events is skipped", {
  # Two tied events a->b and b->a at t = 1; in mode "two" each is the other's
  # only alternative, and both are concurrent under risk = "remove".
  el <- data.frame(sender = c("a", "b"), receiver = c("b", "a"), time = c(1, 1),
                   stringsAsFactors = FALSE)
  cc <- sample_non_events(el, n_controls = 1, mode = "two", risk = "remove",
                          max_attempts = 50, seed = 1)
  expect_equal(sum(cc$event == 0L), 0L)
})

test_that("scope = 'appearance' samples only actors from prior events", {
  set.seed(4)
  el <- data.frame(sender   = sample(letters[1:8], 60, replace = TRUE),
                   receiver = sample(letters[1:8], 60, replace = TRUE),
                   time     = sort(runif(60)), stringsAsFactors = FALSE)
  el <- el[el$sender != el$receiver, ]
  for (m in c("one", "two")) {
    cc <- sample_non_events(el, n_controls = 2, scope = "appearance", mode = m,
                            seed = 2)
    ev <- cc[cc$event == 1L, ]
    ctrl <- cc[cc$event == 0L, ]
    # The first event has no prior events, so it gets no controls.
    expect_false(1L %in% ctrl$stratum)
    seen_before <- function(k) {
      prior <- ev[ev$stratum < k, ]
      unique(c(prior$sender, prior$receiver))
    }
    ok <- mapply(function(s, r, k) all(c(s, r) %in% seen_before(k)),
                 ctrl$sender, ctrl$receiver, ctrl$stratum)
    expect_true(all(ok))
  }
})

test_that("factor actors give character columns and the same sample as character input", {
  set.seed(5)
  el <- data.frame(sender   = sample(letters[1:6], 30, replace = TRUE),
                   receiver = sample(letters[1:6], 30, replace = TRUE),
                   time     = sort(runif(30)), stringsAsFactors = FALSE)
  el <- el[el$sender != el$receiver, ]
  el_f <- el
  el_f$sender <- factor(el_f$sender)
  el_f$receiver <- factor(el_f$receiver)
  a <- sample_non_events(el, n_controls = 2, seed = 9)
  b <- sample_non_events(el_f, n_controls = 2, seed = 9)
  expect_type(b$sender, "character")
  expect_type(b$receiver, "character")
  expect_equal(a, b)
})

test_that("exclude_concurrent keeps tied event dyads out of the controls under risk = 'standard'", {
  el <- data.frame(sender   = c("a1", "a2", "a3", "a4", "a5", "a6"),
                   receiver = c("a2", "a3", "a4", "a5", "a6", "a7"),
                   time     = c(5, 5, 5, 8, 8, 9), stringsAsFactors = FALSE)
  concurrent_hits <- function(cc) {
    ev <- cc[cc$event == 1L, ]
    ctrl <- cc[cc$event == 0L, ]
    keys_by_time <- split(paste0(ev$sender, "->", ev$receiver), ev$time)
    sum(mapply(function(s, r, t) paste0(s, "->", r) %in% keys_by_time[[as.character(t)]],
               ctrl$sender, ctrl$receiver, ctrl$time))
  }
  on <- sample_non_events(el, n_controls = 6, exclude_concurrent = TRUE, seed = 3)
  expect_equal(concurrent_hits(on), 0L)
  # The default under risk = "standard" leaves tied events at risk (Breslow).
  off <- replicate(20, concurrent_hits(sample_non_events(el, n_controls = 6)))
  expect_gt(sum(off), 0L)
})

test_that("exclude_concurrent is validated", {
  el <- data.frame(sender = "a", receiver = "b", time = 1)
  expect_error(sample_non_events(el, exclude_concurrent = NA), "exclude_concurrent")
  expect_error(sample_non_events(el, exclude_concurrent = "yes"), "exclude_concurrent")
})
