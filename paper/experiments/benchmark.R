# benchmark.R
# Wall-clock benchmark suite. Times scale with n_events, n_actors,
# endogenous stat-set size, algorithm choice, and full estimation
# pipeline (compute_endogenous_features + compare_models). Outputs:
#   paper/figures/benchmark_results.csv  per-cell timing table
#   paper/figures/benchmark_*.pdf        scaling figures
#
# Usage:
#   Rscript paper/experiments/benchmark.R [LOCAL|FULL]
#     LOCAL (default) -- quick run for the host laptop, small grid.
#     FULL  -- exhaustive grid; ~30-60 min on Mac Studio M1 Max.

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else "LOCAL"
stopifnot(mode %in% c("LOCAL", "FULL"))
message(sprintf("[bench] mode = %s", mode))

suppressPackageStartupMessages({
  devtools::load_all(".")
})

timer <- function(expr) {
  t0 <- Sys.time()
  invisible(force(expr))
  as.numeric(Sys.time() - t0, units = "secs")
}

bench_one <- function(n_events, n_actors, stat_set = NULL,
                       method = "gillespie", tau = 0.02,
                       half_life = NULL, n_reps = 1) {
  times <- numeric(n_reps)
  for (r in seq_len(n_reps)) {
    set.seed(2026 + r)
    args <- list(
      n_events      = n_events,
      senders       = sprintf("a%03d", seq_len(n_actors)),
      receivers     = sprintf("a%03d", seq_len(n_actors)),
      baseline_rate = 1, allow_loops = FALSE,
      method = method)
    if (method == "tau_leap") args$tau <- tau
    if (!is.null(stat_set) && length(stat_set)) {
      args$endogenous_stats <- stat_set
      args$endogenous_effects <- setNames(rep(0, length(stat_set)),
                                          stat_set)
    }
    if (!is.null(half_life)) args$half_life <- half_life
    times[r] <- timer(do.call(simulate_relational_events, args))
  }
  median(times)
}

# ----- Sweep A: simulator scaling on (n_events x n_actors) -----------------

if (mode == "LOCAL") {
  n_actors_grid <- c(10, 20, 40)
  n_events_grid <- c(500, 1000, 2500, 5000)
} else {
  n_actors_grid <- c(10, 20, 40, 75, 100)
  n_events_grid <- c(500, 1000, 2500, 5000, 10000, 20000)
}

A_rows <- list()
for (na in n_actors_grid) {
  for (ne in n_events_grid) {
    for (m in c("gillespie", "tau_leap")) {
      t <- bench_one(n_events = ne, n_actors = na, method = m)
      A_rows[[length(A_rows) + 1L]] <- data.frame(
        sweep = "A_size_scaling",
        n_events = ne, n_actors = na, method = m, n_stats = 0L,
        seconds = t)
      message(sprintf("[A] %-9s n_actors=%-4d n_events=%-6d  %6.3fs",
                      m, na, ne, t))
    }
  }
}

# ----- Sweep B: stat-set size at fixed n_events x n_actors -----------------

all_stats <- c("reciprocity_count","reciprocity_binary",
               "reciprocity_exp_decay",
               "reciprocity_time_recent","reciprocity_time_first",
               "transitivity_count","transitivity_binary",
               "transitivity_time_recent","transitivity_time_first",
               "transitivity_count_ordered","transitivity_binary_ordered",
               "transitivity_time_recent_ordered",
               "transitivity_time_first_ordered",
               "transitivity_exp_decay","transitivity_exp_decay_ordered",
               "cyclic_count","cyclic_binary",
               "cyclic_time_recent","cyclic_time_first",
               "cyclic_exp_decay",
               "sending_balance_count","sending_balance_binary",
               "sending_balance_time_recent","sending_balance_time_first",
               "sending_balance_exp_decay",
               "receiving_balance_count","receiving_balance_binary",
               "receiving_balance_time_recent","receiving_balance_time_first",
               "receiving_balance_exp_decay",
               "transitivity_time_recent_interrupted",
               "transitivity_time_first_interrupted",
               "cyclic_time_recent_interrupted",
               "cyclic_time_first_interrupted",
               "sending_balance_time_recent_interrupted",
               "sending_balance_time_first_interrupted",
               "receiving_balance_time_recent_interrupted",
               "receiving_balance_time_first_interrupted",
               "reciprocity_count_interrupted",
               "reciprocity_binary_interrupted",
               "reciprocity_exp_decay_interrupted",
               "reciprocity_time_recent_interrupted",
               "reciprocity_time_first_interrupted")
stopifnot(length(unique(all_stats)) == 43L)  # 41 closure + 2 reciprocity dup names? check
all_stats <- unique(all_stats)
message("[B] unique stats: ", length(all_stats))

stat_levels <- if (mode == "LOCAL") c(1, 3, 5, 10, 20) else c(1, 3, 5, 10, 20, 30, length(all_stats))
B_rows <- list()
for (k in stat_levels) {
  stats_k <- all_stats[seq_len(k)]
  t <- bench_one(n_events = 1500, n_actors = 20, stat_set = stats_k,
                 half_life = 1)
  B_rows[[length(B_rows) + 1L]] <- data.frame(
    sweep = "B_stat_scaling",
    n_events = 1500, n_actors = 20, method = "gillespie",
    n_stats = k, seconds = t)
  message(sprintf("[B] n_stats=%-3d  %.3fs", k, t))
}

# ----- Sweep C: compute_endogenous_features on bundled datasets ------------

C_rows <- list()
for (dat_name in c("classroom_events", "social_evolution_calls", "radoslaw_email")) {
  data(list = dat_name)
  ev <- get(dat_name)
  ev <- ev[, c("sender", "receiver", "time")]
  if (dat_name == "radoslaw_email" && mode == "LOCAL") {
    ev <- ev[ev$time < 7, ]   # 7-day slice locally
  }
  if (dat_name == "radoslaw_email") {
    ev <- ev[ev$sender != ev$receiver, ]
  }
  for (n_stats_C in c(2, 5, 10)) {
    stats_C <- all_stats[seq_len(n_stats_C)]
    t <- timer(compute_endogenous_features(ev, stats = stats_C, half_life = 1))
    C_rows[[length(C_rows) + 1L]] <- data.frame(
      sweep = "C_posthoc_realdata",
      dataset = dat_name, n_events = nrow(ev), n_stats = n_stats_C,
      seconds = t)
    message(sprintf("[C] %-25s n=%-6d n_stats=%2d  %7.3fs",
                    dat_name, nrow(ev), n_stats_C, t))
  }
}

# ----- Save & plot ----------------------------------------------------------

A_df <- do.call(rbind, A_rows)
B_df <- do.call(rbind, B_rows)
C_df <- do.call(rbind, C_rows)

write.csv(A_df, "paper/figures/benchmark_A_size.csv", row.names = FALSE)
write.csv(B_df, "paper/figures/benchmark_B_stats.csv", row.names = FALSE)
write.csv(C_df, "paper/figures/benchmark_C_posthoc.csv", row.names = FALSE)

# Plot A: scaling with n_events for each n_actors and method
pdf("paper/figures/benchmark_simulator_scaling.pdf", width = 7.6, height = 3.4)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 2.4, 1), las = 1, cex.axis = 0.85)
cols <- hcl.colors(length(n_actors_grid), "Viridis")
for (m in c("gillespie", "tau_leap")) {
  sub <- A_df[A_df$method == m, ]
  plot(NA, xlim = range(sub$n_events), ylim = c(0.001, max(sub$seconds) * 1.1),
       log = "xy",
       xlab = "n_events", ylab = "wall-clock (s)",
       main = sprintf("Simulator scaling: method = '%s'", m))
  for (i in seq_along(n_actors_grid)) {
    ss <- sub[sub$n_actors == n_actors_grid[i], ]
    lines(ss$n_events, ss$seconds, type = "b", pch = 19, col = cols[i])
  }
  legend("topleft", legend = paste("n_actors =", n_actors_grid),
         col = cols, lty = 1, pch = 19, bty = "n", cex = 0.75)
}
par(op); dev.off()

# Plot B: scaling with stat-set size
pdf("paper/figures/benchmark_stats_scaling.pdf", width = 5.4, height = 3.4)
op <- par(mar = c(4, 4, 2.4, 1), las = 1, cex.axis = 0.85)
plot(B_df$n_stats, B_df$seconds, type = "b", pch = 19, col = "#1f3a5f", lwd = 1.5,
     xlab = "Number of active endogenous stats",
     ylab = "wall-clock (s) — Gillespie, n_events=1500, n_actors=20",
     main = "Simulator scaling with active stat count")
par(op); dev.off()

message("\nDone. CSVs and PDFs written to paper/figures/.")
