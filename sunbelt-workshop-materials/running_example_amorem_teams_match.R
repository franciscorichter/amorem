library(amorem)

set.seed(1234)

# -----------------------------------------------------------------------------
# 1. ACTOR ATTRIBUTES
# -----------------------------------------------------------------------------
V_S <- 4
V_R <- 4

sender_attr_vec   <- setNames(rnorm(V_S, mean = 5, sd = 1.5), paste0("S", seq_len(V_S)))
receiver_attr_vec <- setNames(rnorm(V_R, mean = 3, sd = 2.0), paste0("R", seq_len(V_R)))

# -----------------------------------------------------------------------------
# 2. POWER-SET GROUPS & COVARIATE MATRICES
# -----------------------------------------------------------------------------
power_set_nonempty <- function(elements) {
  n <- length(elements); ids <- seq_len(n)
  subsets <- vector("list", 2^n - 1)
  for (k in seq_len(2^n - 1))
    subsets[[k]] <- elements[as.logical(intToBits(k)[ids])]
  subsets
}

sender_subsets   <- power_set_nonempty(paste0("S", seq_len(V_S)))
receiver_subsets <- power_set_nonempty(paste0("R", seq_len(V_R)))
G_S <- length(sender_subsets)
G_R <- length(receiver_subsets)

sender_group_labels   <- sapply(sender_subsets,
                                function(m) paste0("{", paste(m, collapse = ","), "}"))
receiver_group_labels <- sapply(receiver_subsets,
                                function(m) paste0("{", paste(m, collapse = ","), "}"))

sender_group_cov <- matrix(
  sapply(sender_subsets,   function(m) mean(sender_attr_vec[m])),
  nrow = G_S, ncol = 1, dimnames = list(sender_group_labels, "avg_team_aggression"))

receiver_group_cov <- matrix(
  sapply(receiver_subsets, function(m) mean(receiver_attr_vec[m])),
  nrow = G_R, ncol = 1, dimnames = list(receiver_group_labels, "avg_team_vulnerability"))

cov_s <- as.vector(sender_group_cov)
cov_r <- as.vector(receiver_group_cov)

pair_grid <- expand.grid(gs = seq_len(G_S), gr = seq_len(G_R))
N_pairs   <- nrow(pair_grid)

# -----------------------------------------------------------------------------
# 3. MODEL PARAMETERS
# -----------------------------------------------------------------------------

# --- time-varying sender effect ---
# Two bursts per match day: early-game spike and late-game push
# t in [0, 2] where each unit = 1 full match day
# Peaks at ~20% (early-game) and ~80% (late-game) of each day

alpha_t <- function(t) {
  t_inday <- t %% 1
  peak1 <- 1.0 * exp(-((t_inday - 0.20)^2) / (2 * (0.08)^2))  # early-game burst
  peak2 <- 0.9 * exp(-((t_inday - 0.80)^2) / (2 * (0.10)^2))  # late-game push
  peak1 + peak2
}

# --- diminishing returns receiver effect ---
# Strong increase in targeting at low-to-mid vulnerability,
# flattens out for highly vulnerable teams (they get "farmed out")
f_x_scale  <- 1.2
f_x_offset <- -1.5
f_x_shift  <- min(cov_r) - 0.1   # shift so log argument is always > 0

f_x <- function(x) f_x_offset + f_x_scale * log(x - f_x_shift)

lambda_pairs <- function(t) {
  exp(alpha_t(t) * cov_s[pair_grid$gs] + f_x(cov_r[pair_grid$gr]))
}

# -----------------------------------------------------------------------------
# 4. SIMULATION
# -----------------------------------------------------------------------------
dt  <- 0.01
end <- 2

simdat      <- NULL
nonevents   <- NULL
event_count <- 0
tl          <- 0

cat("Simulating...\n")

while (tl < end) {
  
  tu    <- tl + dt
  mid_t <- tl + dt / 2
  l_sr  <- lambda_pairs(mid_t)
  tm    <- rexp(1, rate = sum(l_sr))
  dt_r  <- dt; tl_r <- tl
  
  while (tm < dt_r && tl_r < end) {
    
    event_count <- event_count + 1
    st      <- tl_r + tm
    pair_id <- which(rmultinom(1, 1, prob = l_sr / sum(l_sr)) == 1)
    gs_id   <- pair_grid$gs[pair_id]
    gr_id   <- pair_grid$gr[pair_id]
    
    simdat <- rbind(simdat, data.frame(
      event_id       = event_count, event_time = st,
      sender_group   = sender_group_labels[gs_id],
      receiver_group = receiver_group_labels[gr_id],
      avg_team_aggres   = cov_s[gs_id],
      avg_team_vuln = cov_r[gr_id],
      stringsAsFactors = FALSE
    ))
    
    non_id <- sample(setdiff(seq_len(N_pairs), pair_id), 1)
    ngs_id <- pair_grid$gs[non_id]
    ngr_id <- pair_grid$gr[non_id]
    
    nonevents <- rbind(nonevents, data.frame(
      event_id       = event_count, event_time = st,
      sender_group   = sender_group_labels[ngs_id],
      receiver_group = receiver_group_labels[ngr_id],
      avg_team_aggres    = cov_s[ngs_id],
      avg_team_vuln = cov_r[ngr_id],
      stringsAsFactors = FALSE
    ))
    
    tl_r <- st; dt_r <- tu - tl_r
    l_sr <- lambda_pairs(tl_r + dt_r / 2)
    tm   <- rexp(1, rate = sum(l_sr))
  }
  tl <- tu
}

simdat    <- as.data.frame(simdat)
nonevents <- as.data.frame(nonevents)
cat(sprintf("Total events simulated: %d\n", nrow(simdat)))

merged <- merge(
  simdat,
  nonevents,
  by       = c("event_id", "event_time"),
  suffixes = c("_ev", "_nv")
)

# -----------------------------------------------------------------------------
# 5. PREPARE DATA FOR MODELLING
# -----------------------------------------------------------------------------
library(knitr)

data_tve_s <- data.frame(cbind(1:nrow(merged), merged[, c(
  "event_time",
  "sender_group_ev", "receiver_group_ev",
  "sender_group_nv", "receiver_group_nv",
  "avg_team_aggres_ev", "avg_team_aggres_nv")]))

colnames(data_tve_s)[1] <- "stratum"
colnames(data_tve_s)[2] <- "time"

kable(head(data_tve_s), format = "latex", booktabs = TRUE, digits = 2)

data_nle_r <- data.frame(cbind(1:nrow(merged), merged[, c(
  "event_time",
  "sender_group_ev", "receiver_group_ev",
  "sender_group_nv", "receiver_group_nv",
  "avg_team_vuln_ev", "avg_team_vuln_nv")]))

colnames(data_nle_r)[1] <- "stratum"
colnames(data_nle_r)[2] <- "time"

kable(head(data_nle_r), format = "latex", booktabs = TRUE, digits = 2)

# -----------------------------------------------------------------------------
# 6. FIT MODELS
# -----------------------------------------------------------------------------

gam_fit_tv <- rem(~ tv(avg_team_aggres), time = "time", method = "gam",
                  data = data_tve_s)

cat("\n--- GAM summary (time-varying team aggression) ---\n")
print(summary(gam_fit_tv))

gam_fit_nl <- rem(~ nl(avg_team_vuln), method = "gam",
                  data = data_nle_r)

cat("\n--- GAM summary (non-linear team vulnerability) ---\n")
print(summary(gam_fit_nl))

# -----------------------------------------------------------------------------
# 7. PLOTS
# -----------------------------------------------------------------------------

pdf("tve_s.pdf", width = 14, height = 8)
par(mar = c(5, 5, 2, 2))
plot(gam_fit_tv,
     shade = TRUE, shade.col = adjustcolor("darkorange", 0.25),
     col = "black", lwd = 2, rug = FALSE,
     xlab = "Match time (days)",
     ylab = expression(alpha(t) ~ "(effect of avg. team aggression)"),
     cex.lab = 1.8, cex.axis = 2)
legend("topleft", c("Estimate", "Conf. interval"),
       lty = c(1, 2), lwd = c(2, 2), col = c("black", "black"),
       cex = 2, bty = "n")
dev.off()

pdf("nl_r.pdf", width = 14, height = 8)
par(mar = c(5, 5, 2, 2))
plot(gam_fit_nl,
     shade = TRUE, shade.col = adjustcolor("steelblue", 0.25),
     col = "black", lwd = 2, rug = FALSE,
     xlab = "Avg. team vulnerability",
     ylab = expression(s("avg. team vulnerability")),
     cex.lab = 1.8, cex.axis = 2)
legend("topleft", c("Estimate", "Conf. interval"),
       lty = c(1, 2), lwd = c(2, 2), col = c("black", "black"),
       cex = 1.5, bty = "n")
dev.off()