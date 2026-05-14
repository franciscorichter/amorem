## Experiment 5: Performance microbenchmark for the four simulator modes.
## Modes:  plain | endogenous | global | both
## Sizes:  (500 events x 10 actors) and (3000 events x 30 actors)

suppressPackageStartupMessages({
  devtools::load_all("/Users/pancho/Projects/amore", quiet = TRUE)
})

set.seed(20260514)

run_case <- function(n_ev, n_act, mode) {
  actors <- paste0("a", seq_len(n_act))
  args <- list(
    n_events = n_ev,
    senders  = actors,
    receivers = actors,
    baseline_rate = 1.0
  )
  if (mode %in% c("endogenous", "both")) {
    args$endogenous_stats   <- "reciprocity_count"
    args$endogenous_effects <- c(reciprocity_count = 0.3)
  }
  if (mode %in% c("global", "both")) {
    args$global_covariates <- data.frame(
      time_start = seq(0, by = 0.01, length.out = 4000),
      weekday    = rep(c(0, 1), length.out = 4000)
    )
    args$global_effects <- c(weekday = 0.5)
    args$horizon <- 4000 * 0.01
  }
  t0 <- proc.time()[["elapsed"]]
  invisible(do.call(simulate_relational_events, args))
  proc.time()[["elapsed"]] - t0
}

sizes <- list(
  small = list(n_ev = 500, n_act = 10),
  large = list(n_ev = 3000, n_act = 30)
)
modes <- c("plain", "endogenous", "global", "both")

reps <- 3
results <- data.frame()
for (snm in names(sizes)) {
  s <- sizes[[snm]]
  for (m in modes) {
    times <- replicate(reps, run_case(s$n_ev, s$n_act, m))
    results <- rbind(results, data.frame(
      size = snm, n_events = s$n_ev, n_actors = s$n_act,
      mode = m, median_s = median(times), min_s = min(times),
      max_s = max(times)))
  }
}

print(results, row.names = FALSE)
