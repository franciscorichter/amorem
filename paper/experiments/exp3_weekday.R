## Experiment 3: Weekday rate switching via piecewise global covariate.
## Alternating 0/1 weekday indicator with coefficient beta.  Each interval
## has equal length L.  Time spent in weekday=1 intervals equals time spent
## in weekday=0 intervals (50/50).  Expected share of events landing in
## weekday=1 is exp(beta) / (1 + exp(beta)).

suppressPackageStartupMessages({
  devtools::load_all("/Users/pancho/Projects/amore", quiet = TRUE)
})

set.seed(20260514)

actors <- paste0("a", 1:10)
beta_w <- 0.8
L <- 1.0
n_intervals <- 400  # total span = 400, weekday/weekend evenly split

global_df <- data.frame(
  time_start = seq(0, by = L, length.out = n_intervals),
  weekday    = rep(c(0, 1), length.out = n_intervals)
)

ev <- simulate_relational_events(
  n_events = 4000,
  senders = actors,
  receivers = actors,
  baseline_rate = 1.0,
  horizon = max(global_df$time_start) + L,
  global_covariates = global_df,
  global_effects = c(weekday = beta_w)
)

obs <- mean(ev$weekday == 1)
expected <- exp(beta_w) / (1 + exp(beta_w))
n <- nrow(ev)
se <- sqrt(expected * (1 - expected) / n)

cat(sprintf("Events realized: %d\n", n))
cat(sprintf("Expected share in weekday=1 intervals: %.4f\n", expected))
cat(sprintf("Observed share: %.4f  (SE %.4f)\n", obs, se))
cat(sprintf("z = %.3f\n", (obs - expected) / se))
