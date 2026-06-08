set.seed(1234)

# -----------------------------------------------------------------------------
# 1. ACTOR ATTRIBUTES
# -----------------------------------------------------------------------------
V_S <- 4
V_R <- 4

sender_attr_vec   <- setNames(rnorm(V_S, mean = 5, sd = 1.5), paste0("S", seq_len(V_S)))
receiver_attr_vec <- setNames(rnorm(V_R, mean = 3, sd = 2.0),
                              paste0("R", seq_len(V_R)))

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
G_S <- length(sender_subsets)    # 15
G_R <- length(receiver_subsets)  # 15

sender_group_labels   <- sapply(sender_subsets,
                                function(m) paste0("{", paste(m, collapse = ","), "}"))
receiver_group_labels <- sapply(receiver_subsets,
                                function(m) paste0("{", paste(m, collapse = ","), "}"))

sender_group_cov <- matrix(
  sapply(sender_subsets,   function(m) mean(sender_attr_vec[m])),
  nrow = G_S, ncol = 1, dimnames = list(sender_group_labels, "avg_activity_level"))
receiver_group_cov <- matrix(
  sapply(receiver_subsets, function(m) mean(receiver_attr_vec[m])),
  nrow = G_R, ncol = 1, dimnames = list(receiver_group_labels, "avg_receptivity_score"))

cov_s <- as.vector(sender_group_cov)
cov_r <- as.vector(receiver_group_cov)

pair_grid <- expand.grid(gs = seq_len(G_S), gr = seq_len(G_R))
N_pairs   <- nrow(pair_grid)   # 225

# -----------------------------------------------------------------------------
# 3. MODEL PARAMETERS
# -----------------------------------------------------------------------------

# --- time-varying sender effect ---
amp  <- 1.0
freq <- 2.0
alpha_t <- function(t) amp * sin(freq * t)

# --- non-linear receiver effect ---
f_x_A      <- 2.0
f_x_mu     <- (min(cov_r) + max(cov_r)) / 2   
f_x_sigma  <- 2.0
f_x_offset <- -4.0
f_x <- function(x) f_x_offset + 
  f_x_A * exp(-((x - f_x_mu)^2) / (2 * f_x_sigma^2))

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
      event_id = event_count, event_time = st,
      sender_group   = sender_group_labels[gs_id],
      receiver_group = receiver_group_labels[gr_id],
      cov_sender     = cov_s[gs_id],
      cov_receiver   = cov_r[gr_id],
      stringsAsFactors = FALSE
    ))
    
    # Non-event: UNIFORM sample from all other pairs
    non_id <- sample(setdiff(seq_len(N_pairs), pair_id), 1)
    ngs_id <- pair_grid$gs[non_id]
    ngr_id <- pair_grid$gr[non_id]
    
    nonevents <- rbind(nonevents, data.frame(
      event_id = event_count, event_time = st,
      sender_group   = sender_group_labels[ngs_id],
      receiver_group = receiver_group_labels[ngr_id],
      cov_sender     = cov_s[ngs_id],
      cov_receiver   = cov_r[ngr_id],
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
  by     = c("event_id", "event_time"),
  suffixes = c("_ev", "_nv")
)

head(merged)


library(knitr)
ncc_data1 <- merged[,c("event_time",
                       "sender_group_ev",
                       "receiver_group_ev",
                       "sender_group_nv",
                       "receiver_group_nv",
                       "cov_sender_ev",
                       "cov_sender_nv")]
ncc_data1$delta_cov_sender <- ncc_data1$cov_sender_ev -
  ncc_data1$cov_sender_nv
ncc_data1$y <- 1
ncc_data1$one <- 1
tab1 <- head(ncc_data1)
kable(tab1, format = "latex", booktabs = TRUE, digits = 2)

ncc_data2 <- merged[,c("event_time",
                       "sender_group_ev",
                       "receiver_group_ev",
                       "sender_group_nv",
                       "receiver_group_nv",
                       "cov_receiver_ev",
                       "cov_receiver_nv")]
ncc_data2$y <- 1
ncc_data2$one <- 1
tab2 <- head(ncc_data2)
kable(tab2, format = "latex", booktabs = TRUE, digits = 2)

# -----------------------------------------------------------------------------
# 5. GAM FIT
# -----------------------------------------------------------------------------
library(mgcv)

data_ev  <- simdat
data_nv  <- nonevents
time     <- data_ev$event_time
W        <- cbind(rep(1,  nrow(data_ev)), rep(-1, nrow(data_ev)))
cov_tve  <- data_ev$cov_sender  - data_nv$cov_sender
cov_nle  <- cbind(data_ev$cov_receiver, data_nv$cov_receiver)
event    <- rep(1, nrow(data_ev))

gam_fit <- gam(
  event ~ -1 + s(time, by = cov_tve) + s(cov_nle, by = W),
  family = binomial(link = "logit")
)

cat("\n--- GAM summary ---\n")
print(summary(gam_fit))

# -----------------------------------------------------------------------------
# 6. GAM PLOTS WITH TRUE FUNCTION
# -----------------------------------------------------------------------------

t_grid <- seq(0, end, length.out = 300)
plot(gam_fit, select = 1,
     shade = TRUE, shade.col = adjustcolor("darkorange", 0.25),
     col = "darkorange", lwd = 2, rug = FALSE,
     xlab = "time  t",
     ylab = expression(alpha(t)),
     main = expression("Covariate with TVE"))
lines(t_grid,
      sapply(t_grid, alpha_t), col = "red", lwd = 2, lty = 2)

x_grid <- seq(min(cov_r), max(cov_r), length.out = 200)
plot(gam_fit, select = 2,
     shade = TRUE, shade.col = adjustcolor("steelblue", 0.25),
     col = "steelblue", lwd = 2, rug = FALSE, ylim=c(-0.3,0.3),
     xlab = expression(cov[r] ~ " (Receiver covariate)"),
     ylab = expression(s(cov[r])),
     main = expression("Covariate with NLE"))
lines(x_grid,
      (sapply(x_grid, f_x)+2.1), col = "red", lwd = 2, lty = 2)


