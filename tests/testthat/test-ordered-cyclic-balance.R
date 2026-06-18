# test-ordered-cyclic-balance.R
# Post-hoc engine support for ordered variants of the cyclic / sending-
# balance / receiving-balance closure families. The simulator does not
# yet generate from these stats; this file pins the post-hoc semantics
# against a brute-force reference. Mirrors the per-family ordering
# convention used by transitivity_*_ordered: an "ordered" instance
# (s, k, r) requires that leg2 fires strictly after the earliest leg1.

# Brute-force reference. Given the event prefix `prior` (rows strictly
# before the current row), the focal (s, r) pair, and the candidate set
# of intermediaries `actors`, return the per-k validation times for the
# ordered chain. `leg1_dir` and `leg2_dir` each take a (k, s, r) triple
# and return c(from, to) so we look up the right slice of `prior`.
validated_ordered <- function(prior, s, r, actors, leg1_dir, leg2_dir) {
  out <- numeric(0)
  for (k in actors) {
    if (k == s || k == r) next
    e1 <- leg1_dir(k, s, r)
    e2 <- leg2_dir(k, s, r)
    t1 <- prior$time[prior$sender == e1[1] & prior$receiver == e1[2]]
    t2 <- prior$time[prior$sender == e2[1] & prior$receiver == e2[2]]
    if (!length(t1) || !length(t2)) next
    valid <- t2[t2 > min(t1)]
    if (length(valid)) out <- c(out, min(valid))
  }
  out
}

# Family direction maps: leg1 / leg2 in the same convention used by
# compute_triadic() inside R/preprocess.R.
fam_dirs <- list(
  cyclic = list(
    leg1 = function(k, s, r) c(r, k),  # r -> k
    leg2 = function(k, s, r) c(k, s)), # k -> s
  sending_balance = list(
    leg1 = function(k, s, r) c(s, k),  # s -> k
    leg2 = function(k, s, r) c(r, k)), # r -> k
  receiving_balance = list(
    leg1 = function(k, s, r) c(k, s),  # k -> s
    leg2 = function(k, s, r) c(k, r))  # k -> r
)

# Hand-built event log with enough density to exercise every family.
ev_fixture <- data.frame(
  sender   = c("A","B","C","A","B","C","A","D","B","C","A","D","C","B","A"),
  receiver = c("B","C","A","C","A","B","D","B","D","D","B","A","B","A","C"),
  time     = seq_len(15) * 1.5,
  stringsAsFactors = FALSE)
actors <- sort(unique(c(ev_fixture$sender, ev_fixture$receiver)))

run_family_check <- function(family) {
  prefix <- family
  stats <- c(paste0(prefix, "_count_ordered"),
             paste0(prefix, "_binary_ordered"),
             paste0(prefix, "_time_recent_ordered"),
             paste0(prefix, "_time_first_ordered"))
  out <- endogenous_features(ev_fixture, stats = stats)
  dirs <- fam_dirs[[family]]
  for (i in seq_len(nrow(ev_fixture))) {
    prior <- ev_fixture[seq_len(i - 1L), , drop = FALSE]
    s <- ev_fixture$sender[i]
    r <- ev_fixture$receiver[i]
    val <- validated_ordered(prior, s, r, actors, dirs$leg1, dirs$leg2)
    exp_count  <- length(val)
    exp_binary <- as.integer(exp_count > 0L)
    exp_recent <- if (exp_count) ev_fixture$time[i] - max(val) else NA_real_
    exp_first  <- if (exp_count) ev_fixture$time[i] - min(val) else NA_real_
    expect_equal(out[[paste0(prefix, "_count_ordered")]][i],
                 as.numeric(exp_count),
                 info = paste(family, "row", i, "count"))
    expect_equal(out[[paste0(prefix, "_binary_ordered")]][i],
                 exp_binary,
                 info = paste(family, "row", i, "binary"))
    expect_equal(out[[paste0(prefix, "_time_recent_ordered")]][i],
                 exp_recent,
                 info = paste(family, "row", i, "recent"))
    expect_equal(out[[paste0(prefix, "_time_first_ordered")]][i],
                 exp_first,
                 info = paste(family, "row", i, "first"))
  }
}

test_that("cyclic_*_ordered match brute-force semantics on a fixed event log", {
  run_family_check("cyclic")
})

test_that("sending_balance_*_ordered match brute-force semantics on a fixed event log", {
  run_family_check("sending_balance")
})

test_that("receiving_balance_*_ordered match brute-force semantics on a fixed event log", {
  run_family_check("receiving_balance")
})

test_that("ordered_count <= unordered_count for every family on every row", {
  for (prefix in c("cyclic", "sending_balance", "receiving_balance")) {
    out <- endogenous_features(ev_fixture,
      stats = c(paste0(prefix, "_count"),
                paste0(prefix, "_count_ordered")))
    expect_true(all(out[[paste0(prefix, "_count_ordered")]] <=
                    out[[paste0(prefix, "_count")]]),
                info = prefix)
  }
})

test_that("binary_ordered equals (count_ordered > 0) on every row", {
  for (prefix in c("cyclic", "sending_balance", "receiving_balance")) {
    out <- endogenous_features(ev_fixture,
      stats = c(paste0(prefix, "_count_ordered"),
                paste0(prefix, "_binary_ordered")))
    expect_equal(out[[paste0(prefix, "_binary_ordered")]],
                 as.integer(out[[paste0(prefix, "_count_ordered")]] > 0),
                 info = prefix)
  }
})

test_that("exp_decay_ordered requires half_life", {
  expect_error(
    endogenous_features(ev_fixture,
      stats = "cyclic_exp_decay_ordered"),
    regexp = "half_life")
  expect_error(
    endogenous_features(ev_fixture,
      stats = "sending_balance_exp_decay_ordered"),
    regexp = "half_life")
  expect_error(
    endogenous_features(ev_fixture,
      stats = "receiving_balance_exp_decay_ordered"),
    regexp = "half_life")
})

test_that("exp_decay_ordered is finite and non-negative when supplied", {
  for (prefix in c("cyclic", "sending_balance", "receiving_balance")) {
    col <- paste0(prefix, "_exp_decay_ordered")
    out <- endogenous_features(ev_fixture,
      stats = col, half_life = 5)
    v <- out[[col]]
    expect_true(all(is.finite(v)) && all(v >= 0), info = prefix)
  }
})

test_that("time_first_ordered >= time_recent_ordered on every non-NA row", {
  for (prefix in c("cyclic", "sending_balance", "receiving_balance")) {
    out <- endogenous_features(ev_fixture,
      stats = c(paste0(prefix, "_time_recent_ordered"),
                paste0(prefix, "_time_first_ordered")))
    recent <- out[[paste0(prefix, "_time_recent_ordered")]]
    first  <- out[[paste0(prefix, "_time_first_ordered")]]
    ok <- !is.na(recent) & !is.na(first)
    expect_true(all(first[ok] >= recent[ok]), info = prefix)
  }
})
