# test-interrupted-triadic.R
# Post-hoc engine support for the count / binary / exp_decay variants
# of the *_interrupted family across transitivity, cyclic, sending-
# balance, and receiving-balance. Pins the new stats against a
# brute-force reference on a fixed event log.
#
# Semantics (matches compute_triadic in R/preprocess.R):
#   `interrupted` counts intermediaries k whose chain (per the family's
#   leg pairing) formed strictly after the last (s, r) closure event.
#   Each k contributes once per closure window.

# Brute-force per-row computation. Given the event prefix `prior`, the
# focal (s, r) pair, candidate intermediaries, and per-family leg
# directions, return the vector of per-k formation times that fall in
# the current interrupted window.
interrupted_window_formations <- function(prior, s, r, actors,
                                          leg1_dir, leg2_dir) {
  # Most recent (s, r) closure before this event.
  sr_times <- prior$time[prior$sender == s & prior$receiver == r]
  t_closure <- if (length(sr_times)) max(sr_times) else -Inf
  out <- numeric(0)
  for (k in actors) {
    if (k == s || k == r) next
    e1 <- leg1_dir(k, s, r)
    e2 <- leg2_dir(k, s, r)
    t1 <- prior$time[prior$sender == e1[1] & prior$receiver == e1[2]]
    t2 <- prior$time[prior$sender == e2[1] & prior$receiver == e2[2]]
    if (!length(t1) || !length(t2)) next
    # Per-compute_triadic convention: per-k formation time is the
    # later of the two legs' earliest occurrences.
    formation <- max(min(t1), min(t2))
    if (formation > t_closure) out <- c(out, formation)
  }
  out
}

fam_dirs <- list(
  transitivity = list(
    leg1 = function(k, s, r) c(s, k),  # s -> k
    leg2 = function(k, s, r) c(k, r)), # k -> r
  cyclic = list(
    leg1 = function(k, s, r) c(r, k),
    leg2 = function(k, s, r) c(k, s)),
  sending_balance = list(
    leg1 = function(k, s, r) c(s, k),
    leg2 = function(k, s, r) c(r, k)),
  receiving_balance = list(
    leg1 = function(k, s, r) c(k, s),
    leg2 = function(k, s, r) c(k, r))
)

ev_fixture <- data.frame(
  sender   = c("A","B","C","A","B","C","A","D","B","C","A","D","C","B","A","D"),
  receiver = c("B","C","A","C","A","B","D","B","D","D","B","A","B","A","C","C"),
  time     = seq_len(16) * 1.25,
  stringsAsFactors = FALSE)
actors <- sort(unique(c(ev_fixture$sender, ev_fixture$receiver)))
half_life <- 4

run_family_check <- function(family) {
  stats <- c(paste0(family, "_count_interrupted"),
             paste0(family, "_binary_interrupted"),
             paste0(family, "_exp_decay_interrupted"))
  out <- compute_endogenous_features(ev_fixture, stats = stats,
                                      half_life = half_life)
  dirs <- fam_dirs[[family]]
  for (i in seq_len(nrow(ev_fixture))) {
    prior <- ev_fixture[seq_len(i - 1L), , drop = FALSE]
    forms <- interrupted_window_formations(prior,
              ev_fixture$sender[i], ev_fixture$receiver[i],
              actors, dirs$leg1, dirs$leg2)
    exp_count  <- length(forms)
    exp_binary <- as.integer(exp_count > 0L)
    t_now <- ev_fixture$time[i]
    exp_decay  <- if (exp_count) {
      sum(exp(-(t_now - forms) * log(2) / half_life))
    } else 0
    expect_equal(out[[stats[1]]][i], as.numeric(exp_count),
                 info = paste(family, "row", i, "count"))
    expect_equal(out[[stats[2]]][i], exp_binary,
                 info = paste(family, "row", i, "binary"))
    expect_equal(out[[stats[3]]][i], exp_decay, tolerance = 1e-9,
                 info = paste(family, "row", i, "exp_decay"))
  }
}

test_that("transitivity_*_interrupted (count/binary/exp_decay) match brute force", {
  run_family_check("transitivity")
})

test_that("cyclic_*_interrupted match brute force", {
  run_family_check("cyclic")
})

test_that("sending_balance_*_interrupted match brute force", {
  run_family_check("sending_balance")
})

test_that("receiving_balance_*_interrupted match brute force", {
  run_family_check("receiving_balance")
})

test_that("binary_interrupted equals (count_interrupted > 0) for every family", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    out <- compute_endogenous_features(ev_fixture,
      stats = c(paste0(family, "_count_interrupted"),
                paste0(family, "_binary_interrupted")))
    expect_equal(out[[paste0(family, "_binary_interrupted")]],
                 as.integer(out[[paste0(family, "_count_interrupted")]] > 0),
                 info = family)
  }
})

test_that("count_interrupted is <= unordered count on every row", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    out <- compute_endogenous_features(ev_fixture,
      stats = c(paste0(family, "_count"),
                paste0(family, "_count_interrupted")))
    expect_true(all(out[[paste0(family, "_count_interrupted")]] <=
                    out[[paste0(family, "_count")]]),
                info = family)
  }
})

test_that("exp_decay_interrupted requires half_life", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    expect_error(
      compute_endogenous_features(ev_fixture,
        stats = paste0(family, "_exp_decay_interrupted")),
      regexp = "half_life")
  }
})

test_that("exp_decay_interrupted is finite and non-negative", {
  for (family in c("transitivity", "cyclic",
                   "sending_balance", "receiving_balance")) {
    col <- paste0(family, "_exp_decay_interrupted")
    out <- compute_endogenous_features(ev_fixture,
      stats = col, half_life = 4)
    v <- out[[col]]
    expect_true(all(is.finite(v)) && all(v >= 0), info = family)
  }
})
