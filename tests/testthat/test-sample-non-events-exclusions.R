# Tests for sample_non_events() control exclusions (issue #81):
#   G1  - exclude_pairs (static structural exclusions)
#   G1b - risk = "remove" must keep same-timestamp concurrent events out of
#         the control pool.

ev_log <- function() {
  data.frame(
    sender   = c("a1", "a2", "a3", "a4", "a5", "a6"),
    receiver = c("a2", "a3", "a4", "a5", "a6", "a7"),
    time     = c(5, 5, 5, 8, 8, 9),      # ties at t=5 (x3) and t=8 (x2)
    stringsAsFactors = FALSE)
}

test_that("G1: exclude_pairs are never sampled as controls", {
  el <- ev_log()
  forbidden <- data.frame(sender = c("a1", "a3"), receiver = c("a5", "a7"),
                          stringsAsFactors = FALSE)
  cc <- sample_non_events(el, n_controls = 6, scope = "all", mode = "two",
                          risk = "standard", exclude_pairs = forbidden, seed = 1)
  ctrl_keys <- with(cc[cc$event == 0L, ], paste0(sender, "->", receiver))
  expect_false(any(ctrl_keys %in% c("a1->a5", "a3->a7")))
})

test_that("G1: exclude_pairs accepts a two-column matrix / positional columns", {
  el <- ev_log()
  forbidden <- as.matrix(data.frame(s = "a1", r = "a4"))   # no sender/receiver names
  cc <- sample_non_events(el, n_controls = 6, scope = "all", mode = "two",
                          risk = "standard", exclude_pairs = forbidden, seed = 2)
  ctrl_keys <- with(cc[cc$event == 0L, ], paste0(sender, "->", receiver))
  expect_false("a1->a4" %in% ctrl_keys)
})

test_that("G1b: a concurrent event dyad is never a control under risk = 'remove'", {
  el <- ev_log()
  cc <- sample_non_events(el, n_controls = 4, scope = "all", mode = "two",
                          risk = "remove", seed = 7)
  ev   <- cc[cc$event == 1L, ]
  ctrl <- cc[cc$event == 0L, ]
  keys_by_time <- split(paste0(ev$sender, "->", ev$receiver), ev$time)
  concurrent_hit <- mapply(
    function(s, r, t) paste0(s, "->", r) %in% keys_by_time[[as.character(t)]],
    ctrl$sender, ctrl$receiver, ctrl$time)
  expect_false(any(concurrent_hit))
})

test_that("G1b leaves distinct-timestamp behaviour unchanged (reproducible)", {
  # With unique event times there are no concurrent groups, so risk='remove'
  # output is identical with and without the new machinery (same seed).
  set.seed(1)
  el <- simulate_relational_events(n_events = 40, senders = paste0("a", 1:10),
                                   receivers = paste0("a", 1:10))
  el <- el[, c("sender", "receiver", "time")]
  a <- sample_non_events(el, n_controls = 2, risk = "remove", seed = 3)
  b <- sample_non_events(el, n_controls = 2, risk = "remove", seed = 3)
  expect_equal(a, b)
})

test_that("exclude_pairs is validated", {
  el <- ev_log()
  expect_error(
    sample_non_events(el, exclude_pairs = c("a1", "a2")),
    "two-column")
})
