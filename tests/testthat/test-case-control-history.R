# endogenous_features() on case-control data: sampled controls read the
# network history but never enter it, unless history_log says otherwise.

cc_fixture <- function(seed = 1, n = 400) {
  set.seed(seed)
  a <- paste0("a", 1:8)
  ev <- simulate_relational_events(n_events = n, senders = a, receivers = a,
                                   baseline_rate = 1)[, c("sender", "receiver", "time")]
  list(ev = ev, cc = sample_non_events(ev, n_controls = 2, seed = seed))
}

stats_set <- c("reciprocity_count", "transitivity_count", "sender_outdegree",
               "recency")

test_that("on case-control data only the events build the history by default", {
  f <- cc_fixture()
  dflt <- endogenous_features(f$cc, stats = stats_set)
  hist <- endogenous_features(f$cc, stats = stats_set, history_log = f$ev)
  expect_equal(dflt, hist)
  # Brute force for one statistic: reverse-dyad events strictly before t.
  brute <- mapply(function(s, r, t) sum(f$ev$sender == r & f$ev$receiver == s & f$ev$time < t),
                  dflt$sender, dflt$receiver, dflt$time)
  expect_equal(unname(dflt$reciprocity_count), unname(brute))
})

test_that("history_log = event_log still treats every row as an event", {
  f <- cc_fixture()
  all_rows <- endogenous_features(f$cc, stats = "sender_outdegree",
                                  history_log = f$cc)
  dflt <- endogenous_features(f$cc, stats = "sender_outdegree")
  expect_gt(max(all_rows$sender_outdegree), max(dflt$sender_outdegree))
})

test_that("the default also holds on the pure-R path and with prior_log", {
  f <- cc_fixture()
  r_path <- endogenous_features(f$cc, stats = c("reciprocity_count", "reciprocity_time_recent"))
  hist <- endogenous_features(f$cc, stats = c("reciprocity_count", "reciprocity_time_recent"),
                              history_log = f$ev)
  expect_equal(r_path, hist)
  prior <- data.frame(sender = "a1", receiver = "a2", time = -1)
  expect_equal(
    endogenous_features(f$cc, stats = "reciprocity_count", prior_log = prior),
    endogenous_features(f$cc, stats = "reciprocity_count", prior_log = prior,
                        history_log = f$ev))
})

test_that("event logs without control rows are unchanged", {
  f <- cc_fixture()
  plain <- endogenous_features(f$ev, stats = stats_set)
  flagged <- f$ev; flagged$event <- 1L
  expect_equal(endogenous_features(flagged, stats = stats_set)[stats_set],
               plain[stats_set])
})

test_that("a reciprocity effect is recovered from default case-control statistics", {
  skip_on_cran()
  skip_if_not_installed("survival")
  a <- paste0("a", 1:12)
  set.seed(1)
  ev <- simulate_relational_events(
    n_events = 1500, senders = a, receivers = a, baseline_rate = 1,
    endogenous_stats = c("reciprocity_count", "transitivity_count"),
    endogenous_effects = c(reciprocity_count = 0.3, transitivity_count = 0.1)
  )[, c("sender", "receiver", "time")]
  cc <- sample_non_events(ev, n_controls = 1, seed = 1)
  feat <- endogenous_features(cc, stats = c("reciprocity_count", "transitivity_count"))
  fit <- survival::clogit(event ~ reciprocity_count + transitivity_count +
                            strata(stratum), data = feat)
  # Counting the controls as events gave 0.18-0.23 on such data.
  expect_lt(abs(stats::coef(fit)[["reciprocity_count"]] - 0.3), 0.08)
})

test_that("sample_non_events() defaults to mode = 'one'", {
  expect_identical(eval(formals(sample_non_events)$mode)[1], "one")
  ev <- data.frame(sender = c("a", "a", "a"), receiver = c("b", "c", "b"),
                   time = 1:3)
  cc <- sample_non_events(ev, n_controls = 50, seed = 1)
  # b and c only ever receive, yet are valid control senders in mode "one".
  expect_true(any(cc$sender[cc$event == 0L] %in% c("b", "c")))
})
