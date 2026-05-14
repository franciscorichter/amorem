## Experiment 2: Non-linear distance recovery.
## True per-dyad log-rate contribution: f(d) = sin(-d/1.5), where d is
## a rescaled log-distance (log meters / 6).  We simulate then fit
## a GAM with a smooth in mgcv.

suppressPackageStartupMessages({
  devtools::load_all("/Users/pancho/Projects/amore", quiet = TRUE)
  library(mgcv)
})

set.seed(20260514)

d_full <- amore::dist_matrix
keep <- c("California", "Texas", "New York", "Florida", "Illinois",
          "Pennsylvania", "Ohio", "Georgia", "Michigan", "North Carolina",
          "New Jersey", "Virginia")
d_sub <- d_full[keep, keep]

## Build a scalar "distance score" per dyad on a friendly scale.
## Use log(d + 1) / scale, then evaluate f(d) = sin(-d/1.5).
log_d <- log(d_sub + 1) / 3   # range roughly 0..5
diag(log_d) <- 0
f_dist <- function(x) sin(-x / 1.5)

contribution_logits <- f_dist(log_d)
diag(contribution_logits) <- -Inf  # no loops

cc <- simulate_relational_events(
  n_events = 2000,
  senders = keep,
  receivers = keep,
  baseline_rate = 1.0,
  contribution_logits = contribution_logits,
  n_controls = 3
)

cat("nrow(cc) =", nrow(cc), "\n")
cat("events:", sum(cc$event == 1), "  controls:", sum(cc$event == 0), "\n")

## Attach dyad log-distance to each row
dist_lookup <- function(s, r) log_d[cbind(s, r)]
cc$log_d <- dist_lookup(cc$sender, cc$receiver)

## Fit a smooth via clogit-style: stratified binary GAM is awkward, so we
## use survival::clogit with a penalised smooth basis from mgcv.
library(survival)
## Construct cubic regression spline basis in log_d.
sm <- smoothCon(s(log_d, bs = "cr", k = 8), data = cc,
                absorb.cons = TRUE)[[1]]
X <- sm$X
colnames(X) <- paste0("b", seq_len(ncol(X)))
cc_aug <- cbind(cc, as.data.frame(X))

f <- as.formula(paste0(
  "event ~ ", paste(colnames(X), collapse = " + "),
  " + strata(stratum)"))
fit <- clogit(f, data = cc_aug)

## Predict smooth on a grid
grid <- data.frame(log_d = seq(0, max(log_d), length.out = 200))
Xg <- PredictMat(sm, grid)
beta_hat <- coef(fit)
pred <- as.numeric(Xg %*% beta_hat)

## Center both estimated and true curves to remove the within-stratum
## additive constant (only contrasts are identified).
pred_c <- pred - mean(pred)
true   <- f_dist(grid$log_d)
true_c <- true - mean(true)

rmse <- sqrt(mean((pred_c - true_c)^2))
cor_pt <- cor(pred_c, true_c)
cat(sprintf("RMSE (centered) = %.4f,  cor(true, pred) = %.4f\n",
            rmse, cor_pt))

## Save figure
pdf("/Users/pancho/Projects/amore/paper/figures/exp2_distance.pdf",
    width = 6, height = 4)
par(mar = c(4, 4, 1.5, 1))
plot(grid$log_d, true_c, type = "l", lwd = 2, col = "black",
     xlab = "log-distance (rescaled)", ylab = "Centered contribution",
     ylim = range(c(pred_c, true_c)))
lines(grid$log_d, pred_c, lwd = 2, col = "tomato", lty = 2)
legend("topright", c("True f(d) = sin(-d/1.5)", "Estimated GAM smooth"),
       lwd = 2, col = c("black", "tomato"), lty = c(1, 2), bty = "n")
invisible(dev.off())

cat("Figure written to paper/figures/exp2_distance.pdf\n")
