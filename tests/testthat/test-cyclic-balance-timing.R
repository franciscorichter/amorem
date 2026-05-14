# test-cyclic-balance-timing.R
# Coverage for the six new generative timing stats:
#   cyclic_time_recent / cyclic_time_first
#   sending_balance_time_recent / sending_balance_time_first
#   receiving_balance_time_recent / receiving_balance_time_first
#
# Each pair extends the transitivity_time_* contract: state[s, r] holds the
# formation time of the most recent (or first) two-path of the relevant
# family between s and r, where a two-path is formed at the time the
# second of its two legs is first observed. Re-fires of an existing leg
# do not form new two-paths.

# Brute-force formation-time enumerator. `legs(s, r, prior, k)` must return
# TRUE iff the family's two-path s ~~ k ~~ r exists in `prior` (rows before
# the current event). Returns the per-k formation times.
formation_times <- function(legs, prior, s, r, actors) {
  out <- numeric(0)
  for (k in actors) {
    if (k == s || k == r) next
    legA <- prior$time[legs(prior, "A", s, r, k)]
    legB <- prior$time[legs(prior, "B", s, r, k)]
    if (length(legA) && length(legB)) {
      out <- c(out, max(min(legA), min(legB)))
    }
  }
  out
}

# Family descriptors: a function `legs(prior, which, s, r, k)` returning the
# logical mask selecting all rows of `prior` that are the requested leg
# (A or B) of the family's two-path between s and r through k.
families <- list(
  cyclic = list(
    leg = function(prior, which, s, r, k) {
      if (which == "A") prior$sender == r & prior$receiver == k
      else              prior$sender == k & prior$receiver == s
    }),
  sending_balance = list(
    leg = function(prior, which, s, r, k) {
      if (which == "A") prior$sender == s & prior$receiver == k
      else              prior$sender == r & prior$receiver == k
    }),
  receiving_balance = list(
    leg = function(prior, which, s, r, k) {
      if (which == "A") prior$sender == k & prior$receiver == s
      else              prior$sender == k & prior$receiver == r
    })
)

check_family <- function(family_name, recent_stat, first_stat, seed,
                          n_events = 25, n_actors = 5) {
  legs_fn <- families[[family_name]]$leg
  set.seed(seed)
  ev <- simulate_relational_events(
    n_events = n_events,
    senders = LETTERS[1:n_actors], receivers = LETTERS[1:n_actors],
    baseline_rate = 3,
    endogenous_stats = c(recent_stat, first_stat),
    endogenous_effects = setNames(c(0, 0), c(recent_stat, first_stat))
  )
  actors <- LETTERS[1:n_actors]
  for (i in seq_len(nrow(ev))) {
    prior <- ev[seq_len(i - 1L), , drop = FALSE]
    fts <- formation_times(legs_fn, prior, ev$sender[i], ev$receiver[i], actors)
    exp_recent <- if (length(fts)) ev$time[i] - max(fts) else 0
    exp_first  <- if (length(fts)) ev$time[i] - min(fts) else 0
    expect_equal(ev[[recent_stat]][i], exp_recent,
                 info = paste(family_name, "row", i, "recent"))
    expect_equal(ev[[first_stat]][i],  exp_first,
                 info = paste(family_name, "row", i, "first"))
  }
  ev
}

test_that("cyclic_time_recent / cyclic_time_first match brute force on small one-mode", {
  check_family("cyclic", "cyclic_time_recent", "cyclic_time_first", seed = 41)
})

test_that("sending_balance_time_recent / first match brute force", {
  check_family("sending_balance",
               "sending_balance_time_recent", "sending_balance_time_first",
               seed = 42)
})

test_that("receiving_balance_time_recent / first match brute force", {
  check_family("receiving_balance",
               "receiving_balance_time_recent", "receiving_balance_time_first",
               seed = 43)
})

test_that("time_first >= time_recent on every row for every new family", {
  for (fam in names(families)) {
    set.seed(101 + match(fam, names(families)))
    rec <- paste0(fam, "_time_recent")
    fst <- paste0(fam, "_time_first")
    ev <- simulate_relational_events(
      n_events = 30,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 3,
      endogenous_stats = c(rec, fst),
      endogenous_effects = setNames(c(0, 0), c(rec, fst))
    )
    expect_true(all(ev[[fst]] >= ev[[rec]]),
                info = paste("family", fam))
  }
})

test_that("the new timing stats compose with their count counterparts (zero when count is 0)", {
  set.seed(55)
  ev <- simulate_relational_events(
    n_events = 25,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("cyclic_count", "cyclic_time_recent",
                         "sending_balance_count", "sending_balance_time_recent",
                         "receiving_balance_count", "receiving_balance_time_recent"),
    endogenous_effects = c(cyclic_count = 0, cyclic_time_recent = 0,
                            sending_balance_count = 0,
                            sending_balance_time_recent = 0,
                            receiving_balance_count = 0,
                            receiving_balance_time_recent = 0)
  )
  for (pair in list(c("cyclic_count", "cyclic_time_recent"),
                    c("sending_balance_count", "sending_balance_time_recent"),
                    c("receiving_balance_count", "receiving_balance_time_recent"))) {
    zero <- ev[[pair[1]]] == 0
    expect_true(all(ev[[pair[2]]][zero] == 0),
                info = paste(pair[2], "must be 0 where", pair[1], "is 0"))
  }
})

test_that("new timing stats error on bipartite settings (one-mode required)", {
  for (st in c("cyclic_time_recent", "cyclic_time_first",
               "sending_balance_time_recent", "sending_balance_time_first",
               "receiving_balance_time_recent", "receiving_balance_time_first")) {
    expect_error(
      simulate_relational_events(
        n_events = 5,
        senders = c("a", "b"), receivers = c("x", "y", "z"),
        endogenous_stats = st,
        endogenous_effects = 0.5
      ),
      "one-mode",
      info = st
    )
  }
})

test_that("new timing stats run under tau-leap and stay non-negative", {
  for (fam in names(families)) {
    set.seed(200 + match(fam, names(families)))
    rec <- paste0(fam, "_time_recent")
    fst <- paste0(fam, "_time_first")
    ev <- simulate_relational_events(
      n_events = 30,
      senders = LETTERS[1:5], receivers = LETTERS[1:5],
      baseline_rate = 2,
      endogenous_stats = c(rec, fst),
      endogenous_effects = setNames(c(0, 0), c(rec, fst)),
      method = "tau_leap", tau = 0.02
    )
    expect_true(all(ev[[rec]] >= 0), info = paste("recent", fam))
    expect_true(all(ev[[fst]] >= 0), info = paste("first", fam))
    expect_true(all(ev[[fst]] >= ev[[rec]]), info = paste("first>=recent", fam))
  }
})

test_that("cyclic_time_recent state matches the t(adj %*% adj)-based count semantics", {
  # If cyclic_count = 0 (no cyclic two-path yet) then cyclic_time_recent = 0,
  # and vice-versa: cyclic_count > 0 -> cyclic_time_recent > 0.
  set.seed(99)
  ev <- simulate_relational_events(
    n_events = 30,
    senders = LETTERS[1:5], receivers = LETTERS[1:5],
    baseline_rate = 3,
    endogenous_stats = c("cyclic_count", "cyclic_time_recent"),
    endogenous_effects = c(cyclic_count = 0, cyclic_time_recent = 0)
  )
  expect_true(all((ev$cyclic_count == 0) == (ev$cyclic_time_recent == 0)))
})
