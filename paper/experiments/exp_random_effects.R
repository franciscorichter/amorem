# exp_random_effects.R
# Repeats the continuous-vs-interrupted AIC comparison from whitepaper
# §7.2 with and without sender random effects, demonstrating that the
# Juozaitiene & Wit (2024) Table 3 ranking only emerges once the
# actor-heterogeneity correction is in place.

suppressPackageStartupMessages({
  devtools::load_all(".")
})

data(classroom_events)
specs <- list(
  count       = c("reciprocity_count", "transitivity_count"),
  continuous  = c("reciprocity_time_recent", "transitivity_time_recent"),
  interrupted = c("reciprocity_time_recent_interrupted",
                  "transitivity_time_recent_interrupted"))

cat("== Classroom =====================================\n")
cat("\n[no random effects]\n")
print(compare_models(classroom_events, specs, n_controls = 3, seed = 11))
cat("\n[sender random effect]\n")
print(compare_models(classroom_events, specs, n_controls = 3, seed = 11,
                      random_effects = "sender"))

# Persist the result for the whitepaper.
res <- list(
  no_re = compare_models(classroom_events, specs, n_controls = 3, seed = 11),
  sender_re = compare_models(classroom_events, specs, n_controls = 3, seed = 11,
                              random_effects = "sender"))
saveRDS(res, "paper/figures/exp_random_effects_classroom.rds")
cat("\nSaved paper/figures/exp_random_effects_classroom.rds\n")
