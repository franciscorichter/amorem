## Experiment 4: Composition smoke test.
## Both endogenous (reciprocity_count, beta_r=0.6) and global covariate
## (weekday, beta_w=0.8) are active.  The global multiplier cancels in
## case-control ratios, so partial-likelihood inference should still
## recover the reciprocity coefficient.

suppressPackageStartupMessages({
  devtools::load_all("/Users/pancho/Projects/amore", quiet = TRUE)
  library(survival)
})

set.seed(20260514)

actors <- paste0("a", 1:8)
beta_r <- 0.6
beta_w <- 0.8

## Interval length 0.01 keeps the average inter-event time of similar
## order, so events scatter across many intervals.
L <- 0.01
global_df <- data.frame(
  time_start = seq(0, by = L, length.out = 4000),
  weekday    = rep(c(0, 1), length.out = 4000)
)

cc <- simulate_relational_events(
  n_events = 1500,
  senders = actors,
  receivers = actors,
  baseline_rate = 1.0,
  horizon = max(global_df$time_start) + L,
  n_controls = 1,
  endogenous_stats = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = beta_r),
  global_covariates = global_df,
  global_effects = c(weekday = beta_w)
)

cat("nrow(cc) =", nrow(cc), "\n")
cat("table(event):\n"); print(table(cc$event))

fit <- clogit(event ~ reciprocity_count + strata(stratum), data = cc)
b_hat <- coef(fit)[["reciprocity_count"]]
se_hat <- sqrt(vcov(fit)[1, 1])
cat(sprintf("Recovered beta_r = %.4f (SE %.4f) [true = %.2f]\n",
            b_hat, se_hat, beta_r))
cat(sprintf("z = %.3f\n", (b_hat - beta_r) / se_hat))

## Report the share of events landing in weekday=1 intervals.  With
## endogenous reciprocity active the per-step rate is no longer
## time-homogeneous within an interval (it scales with the accumulated
## reciprocity state), so the analytic exp(beta)/(1+exp(beta)) limit
## does not strictly apply; we report the observed share for transparency.
obs_share <- mean(cc$weekday[cc$event == 1] == 1)
expected_share <- exp(beta_w) / (1 + exp(beta_w))
cat(sprintf("Weekday share among events: observed %.4f (homogeneous-rate limit %.4f)\n",
            obs_share, expected_share))
