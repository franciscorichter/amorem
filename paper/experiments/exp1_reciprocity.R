## Experiment 1: Linear reciprocity recovery.
## True beta = 0.6. Simulate >= 1000 events with one control per event.
## Fit a conditional logistic regression on reciprocity_count (stratified).

suppressPackageStartupMessages({
  devtools::load_all("/Users/pancho/Projects/amore", quiet = TRUE)
  library(survival)
})

set.seed(20260514)

actors <- paste0("a", 1:20)
beta_true <- 0.6
n_events <- 1200

cc <- simulate_relational_events(
  n_events = n_events,
  senders = actors,
  receivers = actors,
  baseline_rate = 1.0,
  n_controls = 1,
  endogenous_stats = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = beta_true)
)

cat("nrow(cc) =", nrow(cc), "\n")
cat("table(event):\n"); print(table(cc$event))

fit <- clogit(event ~ reciprocity_count + strata(stratum), data = cc)
b_hat <- coef(fit)[["reciprocity_count"]]
se_hat <- sqrt(vcov(fit)[1, 1])

cat(sprintf("Estimated beta = %.4f (SE %.4f)  [true = %.2f]\n",
            b_hat, se_hat, beta_true))
cat(sprintf("z statistic (b_hat - true)/SE = %.3f\n",
            (b_hat - beta_true) / se_hat))
