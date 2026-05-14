# test-interrupted-triadic-timing.R
# Coverage for the eight interrupted triadic-family timing stats:
#   transitivity_time_recent_interrupted, transitivity_time_first_interrupted
#   cyclic_time_recent_interrupted,       cyclic_time_first_interrupted
#   sending_balance_time_recent_interrupted, _time_first_interrupted
#   receiving_balance_time_recent_interrupted, _time_first_interrupted
#
# An interrupted variant has the same formation-time semantics as its
# unordered counterpart but resets the firing dyad's state to NA on
# every (s, r) event (= closure event; paper §2.2.2).

# Family-specific leg masks for the brute-force enumerator.
fam_legs <- list(
  transitivity = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == s & prior$receiver == k
    else              prior$sender == k & prior$receiver == r
  },
  cyclic = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == r & prior$receiver == k
    else              prior$sender == k & prior$receiver == s
  },
  sending_balance = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == s & prior$receiver == k
    else              prior$sender == r & prior$receiver == k
  },
  receiving_balance = function(prior, which, s, r, k) {
    if (which == "A") prior$sender == k & prior$receiver == s
    else              prior$sender == k & prior$receiver == r
  })

# Brute-force expected interrupted timing value at (s, r, t_now) given
# the prior event log. `which = "recent"` returns t_now - max formation
# time among formations strictly after the most recent (s, r) event;
# `which = "first"` returns t_now - min of those formations. Returns 0
# if there are no qualifying formations (matches the simulator's
# NA -> 0 convention).
brute_force_int_triadic <- function(prior, s, r, t_now, family,
                                     which = c("recent", "first"),
                                     actors) {
  which <- match.arg(which)
  legs_fn <- fam_legs[[family]]
  # Most recent (s, r) event before t_now -> the most recent closure.
  closures <- prior$time[prior$sender == s & prior$receiver == r]
  t_close <- if (length(closures)) max(closures) else -Inf
  formations <- numeric(0)
  for (k in actors) {
    if (k == s || k == r) next
    legA <- prior$time[legs_fn(prior, "A", s, r, k)]
    legB <- prior$time[legs_fn(prior, "B", s, r, k)]
    if (!length(legA) || !length(legB)) next
    formation_k <- max(min(legA), min(legB))
    if (formation_k > t_close) formations <- c(formations, formation_k)
  }
  if (!length(formations)) return(0)
  if (which == "recent") t_now - max(formations)
  else                    t_now - min(formations)
}

run_check <- function(family, seed, n_events = 25, n_actors = 5) {
  recent_nm <- paste0(family, "_time_recent_interrupted")
  first_nm  <- paste0(family, "_time_first_interrupted")
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = 3,
    endogenous_stats = c(recent_nm, first_nm),
    endogenous_effects = setNames(c(0, 0), c(recent_nm, first_nm)))
  actors <- LETTERS[1:n_actors]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    exp_recent <- brute_force_int_triadic(
      prior, ev$sender[i], ev$receiver[i], ev$time[i], family, "recent", actors)
    exp_first  <- brute_force_int_triadic(
      prior, ev$sender[i], ev$receiver[i], ev$time[i], family, "first",  actors)
    expect_equal(ev[[recent_nm]][i], exp_recent, tolerance = 1e-9,
                 info = paste(family, "row", i, "recent"))
    expect_equal(ev[[first_nm]][i],  exp_first,  tolerance = 1e-9,
                 info = paste(family, "row", i, "first"))
  }
}

test_that("transitivity interrupted timing matches brute force", {
  run_check("transitivity", seed = 71)
})

test_that("cyclic interrupted timing matches brute force", {
  run_check("cyclic", seed = 72)
})

test_that("sending_balance interrupted timing matches brute force", {
  run_check("sending_balance", seed = 73)
})

test_that("receiving_balance interrupted timing matches brute force", {
  run_check("receiving_balance", seed = 74)
})

test_that("interrupted state is 0 immediately after a closure event", {
  # Hand-crafted: A->B opens an s->k->r chain via B; then A->C closes
  # any open triad rooted at (A, C). Re-firing of any leg must NOT
  # revive the interrupted state.
  set.seed(75)
  ev <- simulate_relational_events(
    n_events = 50,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_time_recent_interrupted",
                         "transitivity_time_recent"),
    endogenous_effects = c(transitivity_time_recent_interrupted = 0,
                            transitivity_time_recent = 0))
  for (i in seq_len(nrow(ev))) {
    # Check: if the dyad has fired before row i with any formation
    # happening before the most recent prior firing of the same dyad,
    # the interrupted value must be 0.
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    prev_same <- prior$time[prior$sender == ev$sender[i] &
                              prior$receiver == ev$receiver[i]]
    if (length(prev_same)) {
      # Was every formation of two-paths s->k->r before max(prev_same)?
      # If so, interrupted must be 0.
      t_close <- max(prev_same)
      any_post <- FALSE
      for (k in LETTERS[1:5]) {
        if (k == ev$sender[i] || k == ev$receiver[i]) next
        leg1 <- prior$time[prior$sender == ev$sender[i] & prior$receiver == k]
        leg2 <- prior$time[prior$sender == k & prior$receiver == ev$receiver[i]]
        if (!length(leg1) || !length(leg2)) next
        if (max(min(leg1), min(leg2)) > t_close) { any_post <- TRUE; break }
      }
      if (!any_post) {
        expect_equal(ev$transitivity_time_recent_interrupted[i], 0,
                     info = paste("row", i, "must be 0 post-closure"))
      }
    }
  }
})

test_that("first >= recent on every row for every interrupted triadic family", {
  for (fam in c("transitivity", "cyclic",
                "sending_balance", "receiving_balance")) {
    set.seed(80 + match(fam, c("transitivity", "cyclic",
                                 "sending_balance", "receiving_balance")))
    rec <- paste0(fam, "_time_recent_interrupted")
    fst <- paste0(fam, "_time_first_interrupted")
    ev <- simulate_relational_events(
      n_events = 30,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 3,
      endogenous_stats = c(rec, fst),
      endogenous_effects = setNames(c(0, 0), c(rec, fst)))
    expect_true(all(ev[[fst]] >= ev[[rec]]),
                info = paste(fam, "first must be >= recent"))
  }
})

test_that("interrupted variants are <= their continuous counterparts", {
  set.seed(91)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("transitivity_time_recent",
                         "transitivity_time_recent_interrupted",
                         "cyclic_time_recent",
                         "cyclic_time_recent_interrupted",
                         "sending_balance_time_recent",
                         "sending_balance_time_recent_interrupted",
                         "receiving_balance_time_recent",
                         "receiving_balance_time_recent_interrupted"),
    endogenous_effects = setNames(rep(0, 8),
                                    c("transitivity_time_recent",
                                      "transitivity_time_recent_interrupted",
                                      "cyclic_time_recent",
                                      "cyclic_time_recent_interrupted",
                                      "sending_balance_time_recent",
                                      "sending_balance_time_recent_interrupted",
                                      "receiving_balance_time_recent",
                                      "receiving_balance_time_recent_interrupted")))
  for (fam in c("transitivity", "cyclic",
                "sending_balance", "receiving_balance")) {
    c_nm <- paste0(fam, "_time_recent")
    i_nm <- paste0(fam, "_time_recent_interrupted")
    expect_true(all(ev[[i_nm]] <= ev[[c_nm]] + 1e-9),
                info = paste(fam, "interrupted_recent <= continuous_recent"))
  }
})

test_that("interrupted triadic timing runs under tau-leap", {
  set.seed(95)
  stats_vec <- c("transitivity_time_recent_interrupted",
                  "transitivity_time_first_interrupted",
                  "cyclic_time_recent_interrupted",
                  "cyclic_time_first_interrupted",
                  "sending_balance_time_recent_interrupted",
                  "sending_balance_time_first_interrupted",
                  "receiving_balance_time_recent_interrupted",
                  "receiving_balance_time_first_interrupted")
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 2,
    endogenous_stats = stats_vec,
    endogenous_effects = setNames(rep(0, length(stats_vec)), stats_vec),
    method = "tau_leap", tau = 0.02)
  for (st in stats_vec) expect_true(all(ev[[st]] >= 0), info = st)
})
