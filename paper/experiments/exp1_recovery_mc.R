# exp1_recovery_mc.R
# Monte Carlo recovery study for the case-control / clogit inference of
# the reciprocity_count coefficient. Generates paper/figures/exp1_recovery.pdf.

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(survival)
})

actors    <- paste0("a", 1:20)
beta_true <- 0.6
n_events  <- 1200
n_reps    <- 200

set.seed(20260514)
res <- data.frame(rep = integer(n_reps),
                  estimate = numeric(n_reps),
                  se = numeric(n_reps))
for (r in seq_len(n_reps)) {
  cc <- simulate_relational_events(
    n_events           = n_events,
    senders            = actors,
    receivers          = actors,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = beta_true))
  fit <- clogit(event ~ reciprocity_count + strata(stratum), data = cc)
  res$rep[r]      <- r
  res$estimate[r] <- coef(fit)[["reciprocity_count"]]
  res$se[r]       <- sqrt(vcov(fit)[1, 1])
  if (r %% 50 == 0) message("[exp1 MC] rep ", r, "/", n_reps)
}

mean_est <- mean(res$estimate)
bias     <- mean_est - beta_true
emp_sd   <- sd(res$estimate)
mean_se  <- mean(res$se)
covered  <- mean(abs(res$estimate - beta_true) / res$se <= 1.96)

write.csv(res, "paper/figures/exp1_recovery.csv", row.names = FALSE)
saveRDS(list(beta_true = beta_true, mean_est = mean_est, bias = bias,
             emp_sd = emp_sd, mean_se = mean_se, covered = covered),
        "paper/figures/exp1_recovery_summary.rds")
cat(sprintf("MC over %d reps: mean est = %.4f, bias = %+.4f, emp SD = %.4f, mean SE = %.4f, 95%% coverage = %.3f\n",
            n_reps, mean_est, bias, emp_sd, mean_se, covered))

pdf("paper/figures/exp1_recovery.pdf", width = 6.4, height = 3.4)
op <- par(mar = c(4, 4, 2.4, 1), cex.axis = 0.85, las = 1)
hist(res$estimate, breaks = 24,
     col = "#9bb7d4", border = "white",
     xlab = expression(hat(beta)["reciprocity_count"]),
     main = sprintf("Monte Carlo recovery of beta = %.2f  (%d reps)",
                    beta_true, n_reps))
abline(v = beta_true, col = "#d62728", lwd = 2)
abline(v = mean_est, col = "#1f3a5f", lwd = 2, lty = 2)
legend("topright", legend = c(sprintf("true beta = %.2f", beta_true),
                              sprintf("mean estimate = %.3f", mean_est)),
       col = c("#d62728", "#1f3a5f"), lty = c(1, 2), lwd = 2,
       bty = "n", cex = 0.85)
par(op); dev.off()
cat("Wrote exp1_recovery.pdf\n")
