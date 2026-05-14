# figures_smooth_effects.R
# Replicates the spirit of Juozaitiene & Wit (2024) Figure 6: fit a
# smooth (pspline) coxph model on a bundled dataset and plot the
# estimated effect curve over time for reciprocity and transitivity
# time-recent statistics. Saves paper/figures/smooth_effects.pdf.

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(survival)
})

build_cc <- function(ev, stat_set, n_controls = 3, seed = 11) {
  cc <- sample_non_events(ev, n_controls = n_controls,
                          scope = "all", mode = "one", seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = stat_set)
  for (st in stat_set) cc_feat[[st]][is.na(cc_feat[[st]])] <- 0
  cc_feat[order(cc_feat$stratum, -cc_feat$event), ]
}

extract_pspline_curve <- function(fit, var, grid) {
  # Build a synthetic data frame holding the var grid (others at their
  # median) and predict the LINEAR PREDICTOR contribution of var.
  vars <- names(coef(fit))
  base <- as.data.frame(t(rep(0, length(vars))))
  names(base) <- vars
  data.frame(x = grid,
             effect = sapply(grid, function(v) sum(coef(fit) * base[1, ])))
}

# Use 30-day Radoslaw slice (large enough to identify the smooth)
data(radoslaw_email)
re <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]
re30 <- re[re$time < 30, ]

stat_set <- c("reciprocity_time_recent", "transitivity_time_recent",
              "reciprocity_time_recent_interrupted",
              "transitivity_time_recent_interrupted")
cc_feat <- build_cc(re30, stat_set, n_controls = 3, seed = 11)
cc_feat$.surv <- Surv(rep(1, nrow(cc_feat)), cc_feat$event)

fit <- coxph(.surv ~
               pspline(reciprocity_time_recent,             df = 4) +
               pspline(transitivity_time_recent,            df = 4) +
               pspline(reciprocity_time_recent_interrupted, df = 4) +
               pspline(transitivity_time_recent_interrupted, df = 4) +
               strata(stratum),
             data = cc_feat, method = "breslow")
saveRDS(fit, "paper/figures/smooth_effects_fit.rds")
cat("AIC:", round(AIC(fit), 1), "  loglik:", round(as.numeric(logLik(fit)), 1), "\n")

# pspline's predict() returns the partial effect; use predict(..., type="terms")
te <- predict(fit, type = "terms", se.fit = TRUE)
te_fit <- as.data.frame(te$fit)
te_se  <- as.data.frame(te$se.fit)
cat("Available term names:\n")
print(names(te_fit))
col_by_var <- function(var) {
  hits <- grep(sprintf("pspline\\(%s,", var), names(te_fit), value = TRUE,
               fixed = FALSE)
  if (length(hits) != 1L) stop("Ambiguous match for ", var, ": ", paste(hits, collapse = " | "))
  hits
}
cc_feat$pred_recip   <- te_fit[[col_by_var("reciprocity_time_recent")]]
cc_feat$pred_trans   <- te_fit[[col_by_var("transitivity_time_recent")]]
cc_feat$pred_recip_i <- te_fit[[col_by_var("reciprocity_time_recent_interrupted")]]
cc_feat$pred_trans_i <- te_fit[[col_by_var("transitivity_time_recent_interrupted")]]

# Build a plotting frame: x-axis = stat value, y-axis = partial effect
mk_curve <- function(stat_col, pred_col, lab) {
  ord <- order(cc_feat[[stat_col]])
  data.frame(
    x      = cc_feat[[stat_col]][ord],
    effect = cc_feat[[pred_col]][ord],
    stat   = lab)
}
curves <- rbind(
  mk_curve("reciprocity_time_recent",              "pred_recip",   "Reciprocity (continuous)"),
  mk_curve("transitivity_time_recent",             "pred_trans",   "Transitivity (continuous)"),
  mk_curve("reciprocity_time_recent_interrupted",  "pred_recip_i", "Reciprocity (interrupted)"),
  mk_curve("transitivity_time_recent_interrupted", "pred_trans_i", "Transitivity (interrupted)"))

# Trim to non-zero stat values (the bulk of the action)
curves <- curves[curves$x > 0 & curves$x < quantile(curves$x, 0.97), ]

pdf("paper/figures/smooth_effects.pdf", width = 7.4, height = 4.6)
op <- par(mfrow = c(2, 2), mar = c(4, 4, 2.4, 1), cex.axis = 0.8, las = 1)
for (lbl in unique(curves$stat)) {
  d <- curves[curves$stat == lbl, ]
  # average duplicate x values for a cleaner curve
  agg <- aggregate(effect ~ round(x, 2), data = d, FUN = mean)
  names(agg) <- c("x", "effect")
  agg <- agg[order(agg$x), ]
  plot(agg$x, agg$effect, type = "l", col = "#1f3a5f", lwd = 2,
       xlab = "Elapsed time since formation (days)",
       ylab = "Partial effect (log-rate ratio)",
       main = lbl)
  abline(h = 0, lty = 3, col = "grey60")
}
par(op); dev.off()
cat("Wrote smooth_effects.pdf\n")

# Coefficient table for headline reporting
coef_tab <- coef(fit)
linear_coef <- coef_tab[grepl(", linear", names(coef_tab))]
names(linear_coef) <- sub(", linear", "", sub("pspline\\(", "", names(linear_coef)))
names(linear_coef) <- sub("\\)$", "", names(linear_coef))
print(round(linear_coef, 4))
saveRDS(linear_coef, "paper/figures/smooth_effects_linear_coefs.rds")
