suppressPackageStartupMessages({
  devtools::load_all(".")
  library(mgcv)
})

fit_cc <- function(ev, stat_set, seed = 42, half_life = 1) {
  cc <- sample_non_events(ev, n_controls = 1, scope = "all", mode = "one", seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = stat_set, half_life = half_life)
  for (st in stat_set) cc_feat[[st]][is.na(cc_feat[[st]])] <- 0
  cases <- cc_feat[cc_feat$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc_feat[cc_feat$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(one = rep(1, nrow(cases)))
  for (st in stat_set) df[[paste0("d_", st)]] <- cases[[st]] - ctrls[[st]]
  fm <- as.formula(paste("one ~", paste(paste0("d_", stat_set), collapse = " + "), "- 1"))
  fit <- gam(fm, family = "binomial", data = df)
  list(aic = AIC(fit), table = summary(fit)$p.table, n = nrow(df))
}

specs <- list(
  "count"        = c("reciprocity_count", "transitivity_count"),
  "continuous"   = c("reciprocity_time_recent", "transitivity_time_recent"),
  "interrupted"  = c("reciprocity_time_recent_interrupted",
                     "transitivity_time_recent_interrupted"))

data(classroom_events); data(radoslaw_email)
re <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]
re30 <- re[re$time < 30, ]

datasets <- list(Classroom = classroom_events, "Radoslaw (30 d)" = re30)
aic_tab <- matrix(0, nrow = length(specs), ncol = length(datasets),
                  dimnames = list(names(specs), names(datasets)))
for (di in seq_along(datasets)) {
  for (si in seq_along(specs)) {
    f <- fit_cc(datasets[[di]], specs[[si]], seed = 11)
    aic_tab[si, di] <- f$aic
  }
}
# Save the comparison table
write.csv(aic_tab, "paper/figures/realdata_v2_aic_table.csv")
cat("AIC table:\n"); print(round(aic_tab, 1))

# Plot: paired bar chart of relative AIC (against best spec per dataset).
rel_aic <- sweep(aic_tab, 2, apply(aic_tab, 2, min), `-`)
pdf("paper/figures/realdata_v2_aic.pdf", width = 6.4, height = 3.4)
op <- par(mar = c(4, 4, 1.5, 1), cex.axis = 0.9)
barplot(rel_aic, beside = TRUE,
        col = c("grey60", "grey85", "grey20"),
        ylab = expression(Delta * "AIC vs best spec on this dataset"),
        legend.text = c("count", "continuous time", "interrupted time"),
        args.legend = list(x = "topright", bty = "n", cex = 0.85))
par(op); dev.off()
cat("Figure: paper/figures/realdata_v2_aic.pdf\n")

# Combined model on Radoslaw
big <- fit_cc(re30,
  c("reciprocity_time_recent", "reciprocity_time_recent_interrupted",
    "transitivity_time_recent", "transitivity_time_recent_interrupted"),
  seed = 11)
saveRDS(list(aic_tab = aic_tab, combined = big), "paper/figures/realdata_v2_results.rds")
cat("Combined-model AIC on Radoslaw:", round(big$aic, 1), "\n")
print(round(big$table, 4))
