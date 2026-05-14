# figures_simulation.R
# Renders illustrative figures for the Simulation chapter:
#   sim_plain.pdf       - plain Gillespie stream (event timeline + cumulative)
#   sim_endogenous.pdf  - reciprocity_count buildup with positive effect
#   sim_global.pdf      - weekday/weekend rate switching with shaded regions
#   sim_gillespie_vs_tauleap.pdf - QQ-plot of inter-event times
#   sim_exogenous.pdf   - effect of dyad-level covariate on firing intensity
#   sim_remove.pdf      - dyad-level extinction under risk = "remove"

suppressPackageStartupMessages({
  devtools::load_all(".")
})

# ---------- 1. Plain Gillespie stream ----------------------------------------

set.seed(2026)
ev <- simulate_relational_events(
  n_events = 300, senders = LETTERS[1:6], receivers = LETTERS[1:6],
  baseline_rate = 1, allow_loops = FALSE)
ev$dyad <- paste0(ev$sender, "->", ev$receiver)
ev$dyad_id <- as.integer(factor(ev$dyad))

pdf("paper/figures/sim_plain.pdf", width = 7.2, height = 3.0)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
plot(ev$time, ev$dyad_id, pch = 20, cex = 0.4, col = "#1f3a5f",
     xlab = "Time", ylab = "Dyad index",
     main = "Plain Gillespie: 300 events, 6 actors")
plot(sort(ev$time), seq_len(nrow(ev)), type = "s", col = "#1f3a5f",
     lwd = 1, xlab = "Time", ylab = "Cumulative events",
     main = sprintf("Mean rate = %.1f events / unit time",
                    nrow(ev) / diff(range(ev$time))))
par(op); dev.off()
cat("Wrote sim_plain.pdf\n")

# ---------- 2. Endogenous reciprocity buildup --------------------------------

set.seed(7)
ev_endo <- simulate_relational_events(
  n_events = 500, senders = LETTERS[1:8], receivers = LETTERS[1:8],
  baseline_rate = 1, allow_loops = FALSE,
  endogenous_stats   = "reciprocity_count",
  endogenous_effects = 0.4)
ev_endo$dyad <- paste0(ev_endo$sender, "->", ev_endo$receiver)
ev_endo$dyad_id <- as.integer(factor(ev_endo$dyad))

# Tag whether each event is itself a reciprocal response (i.e., the
# reverse dyad fired before)
seen <- character(0)
ev_endo$reciprocated <- FALSE
for (i in seq_len(nrow(ev_endo))) {
  rev_key <- paste0(ev_endo$receiver[i], "->", ev_endo$sender[i])
  if (rev_key %in% seen) ev_endo$reciprocated[i] <- TRUE
  seen <- c(seen, ev_endo$dyad[i])
}

pdf("paper/figures/sim_endogenous.pdf", width = 7.2, height = 3.2)
op <- par(mfrow = c(1, 2), mar = c(4, 4.2, 2.4, 1), cex.axis = 0.85, las = 1)
# Left: scatter of reciprocity_count over event index (each point = one event)
plot(seq_len(nrow(ev_endo)), ev_endo$reciprocity_count, pch = 20, cex = 0.6,
     col = ifelse(ev_endo$reciprocated, "#d62728", "#1f3a5f"),
     xlab = "Event index", ylab = "reciprocity_count at event time",
     main = "Effect beta = +0.4 builds reciprocity into the dynamics")
legend("topleft", legend = c("non-reverse event", "reverse-dyad event"),
       col = c("#1f3a5f", "#d62728"), pch = 20, bty = "n", cex = 0.8)
# Right: empirical hazard ratio of reciprocated vs non-reciprocated dyads
br <- cut(seq_len(nrow(ev_endo)), breaks = 10)
agg <- aggregate(reciprocated ~ br, data = ev_endo, FUN = mean)
plot(seq_along(agg$br), agg$reciprocated, type = "b", pch = 19,
     col = "#1f3a5f", ylim = c(0, max(agg$reciprocated) * 1.05),
     xlab = "Event-index decile", ylab = "Fraction reverse-dyad events",
     main = "Reciprocity rate rises as history accrues")
abline(h = 1 / (8 * 7), lty = 3, col = "grey60")
text(1, 1 / (8 * 7), "baseline rate", pos = 3, cex = 0.7, col = "grey40")
par(op); dev.off()
cat("Wrote sim_endogenous.pdf\n")

# ---------- 3. Global weekday/weekend covariate ------------------------------

set.seed(11)
gc <- data.frame(time_start = seq(0, 20, by = 1),
                 weekday    = rep(c(0, 1), length.out = 21))
ev_glob <- simulate_relational_events(
  n_events = 600, senders = letters[1:6], receivers = letters[1:6],
  baseline_rate = 0.4, allow_loops = FALSE,
  horizon = 21,
  global_covariates = gc, global_effects = c(weekday = 1.6))

pdf("paper/figures/sim_global.pdf", width = 7.2, height = 3.0)
op <- par(mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
# Shade weekday=1 strips
plot(NA, xlim = c(0, 21), ylim = c(0, nrow(ev_glob)),
     xlab = "Time", ylab = "Cumulative events",
     main = "Global covariate weekday: rate is 1.6x higher when weekday = 1")
for (k in 0:20) {
  if (gc$weekday[k + 1] == 1)
    rect(k, 0, k + 1, nrow(ev_glob), col = "#fdebd0", border = NA)
}
lines(sort(ev_glob$time), seq_len(nrow(ev_glob)), col = "#1f3a5f", lwd = 1.3)
legend("topleft", legend = "weekday = 1 intervals",
       fill = "#fdebd0", bty = "n", cex = 0.8)
par(op); dev.off()
cat("Wrote sim_global.pdf\n")

# ---------- 4. Gillespie vs tau-leap -----------------------------------------

set.seed(21)
ev_g <- simulate_relational_events(
  n_events = 1000, senders = LETTERS[1:8], receivers = LETTERS[1:8],
  baseline_rate = 1, allow_loops = FALSE, method = "gillespie")
set.seed(21)
ev_t <- simulate_relational_events(
  n_events = 1000, senders = LETTERS[1:8], receivers = LETTERS[1:8],
  baseline_rate = 1, allow_loops = FALSE,
  method = "tau_leap", tau = 0.02)

iet_g <- diff(sort(ev_g$time))
iet_t <- diff(sort(ev_t$time))

pdf("paper/figures/sim_gillespie_vs_tauleap.pdf", width = 7.2, height = 3.0)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
plot(sort(iet_g), sort(iet_t), pch = 20, cex = 0.5, col = "#1f3a5f",
     xlab = "Gillespie inter-event time (quantile)",
     ylab = "tau-leap (tau = 0.02) inter-event time (quantile)",
     main = "QQ-plot of inter-event times")
abline(0, 1, lty = 2, col = "grey60")
ks <- ks.test(iet_g, iet_t)
mtext(sprintf("KS p = %.2f", ks$p.value), side = 3, line = -1.4, cex = 0.8)

# Cumulative events overlay
plot(sort(ev_g$time), seq_along(ev_g$time), type = "s", col = "#1f3a5f",
     xlab = "Time", ylab = "Cumulative events",
     main = "Cumulative count: both algorithms")
lines(sort(ev_t$time), seq_along(ev_t$time), col = "#d62728", lty = 2)
legend("topleft", legend = c("Gillespie", "tau-leap"),
       col = c("#1f3a5f", "#d62728"), lty = c(1, 2), bty = "n", cex = 0.85)
par(op); dev.off()
cat("Wrote sim_gillespie_vs_tauleap.pdf\n")

# ---------- 5. Exogenous dyadic effect ---------------------------------------

set.seed(31)
p <- 10
x <- matrix(rnorm(p * p), nrow = p, ncol = p)
diag(x) <- -Inf  # no self-loops in effect
contribution <- 0.8 * x

ev_exo <- simulate_relational_events(
  n_events = 1500, senders = LETTERS[1:p], receivers = LETTERS[1:p],
  baseline_rate = 0.1, allow_loops = FALSE,
  contribution_logits = contribution)

# Empirical firing count per dyad vs expected log-rate
tab <- table(paste0(ev_exo$sender, "->", ev_exo$receiver))
dyad_keys <- unique(paste0(rep(LETTERS[1:p], each = p),
                           "->", rep(LETTERS[1:p], times = p)))
keep <- !grepl("(.)->\\1", dyad_keys)
dyad_keys <- dyad_keys[keep]
expected <- contribution[cbind(
  as.integer(factor(sub("->.*", "", dyad_keys), levels = LETTERS[1:p])),
  as.integer(factor(sub(".*->", "", dyad_keys), levels = LETTERS[1:p])))]
empirical <- as.numeric(tab[dyad_keys])
empirical[is.na(empirical)] <- 0

pdf("paper/figures/sim_exogenous.pdf", width = 5.4, height = 3.4)
op <- par(mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
plot(expected, log1p(empirical), pch = 20, cex = 0.7, col = "#1f3a5f",
     xlab = "True log-intensity (beta * x)",
     ylab = "log(1 + observed event count)",
     main = "Exogenous dyad effects translate into observed counts")
fit <- lm(log1p(empirical) ~ expected)
abline(fit, col = "#d62728", lwd = 1.2)
mtext(sprintf("slope = %.2f", coef(fit)[2]),
      side = 3, line = -1.4, cex = 0.85)
par(op); dev.off()
cat("Wrote sim_exogenous.pdf\n")

# ---------- 6. Risk = "remove" -----------------------------------------------

set.seed(41)
ev_rem <- simulate_relational_events(
  n_events = 80, senders = LETTERS[1:10], receivers = LETTERS[1:10],
  baseline_rate = 5, allow_loops = FALSE, risk = "remove")

# Track admissible-dyad count over event index
n_dyads <- 10 * 10 - 10  # excluding self-loops
admissible <- n_dyads - seq_len(nrow(ev_rem))

pdf("paper/figures/sim_remove.pdf", width = 5.4, height = 3.2)
op <- par(mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
plot(seq_along(admissible), admissible, type = "s", col = "#1f3a5f",
     xlab = "Event index", ylab = "Admissible dyads remaining",
     main = "risk = 'remove': each dyad fires at most once")
abline(h = 0, lty = 3, col = "grey60")
par(op); dev.off()
cat("Wrote sim_remove.pdf\n")
