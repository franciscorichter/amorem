suppressPackageStartupMessages({devtools::load_all("."); library(mgcv)})

# ---------- Re-fit both for the final figure / table ----------
data(classroom_events); data(radoslaw_email)

fit_dataset <- function(ev, stats_list, seed = 42) {
  cc <- sample_non_events(ev, n_controls = 1, scope = "all", mode = "one", seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = stats_list)
  cases <- cc_feat[cc_feat$event == 1L, ]; cases <- cases[order(cases$stratum), ]
  ctrls <- cc_feat[cc_feat$event == 0L, ]; ctrls <- ctrls[order(ctrls$stratum), ]
  df <- data.frame(one = rep(1, nrow(cases)))
  for (s in stats_list) df[[paste0("d_", s)]] <- cases[[s]] - ctrls[[s]]
  fm <- as.formula(paste("one ~", paste(paste0("d_", stats_list), collapse = " + "), "- 1"))
  fit <- gam(fm, family = "binomial", data = df)
  tab <- summary(fit)$p.table
  rownames(tab) <- stats_list
  list(fit = fit, table = tab)
}

# ---------- Run on classroom and 30-day Radoslaw ----------
stats_list <- c("reciprocity_count", "reciprocity_time_recent",
                "transitivity_count", "transitivity_time_recent")

set.seed(2026)
cl <- fit_dataset(classroom_events, stats_list, seed = 11)

re <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]
re30 <- re[re$time < 30, ]
rd <- fit_dataset(re30, stats_list, seed = 7)

cat("==== Classroom (n=", nrow(classroom_events), ") ====\n", sep="")
print(round(cl$table, 4))
cat("\n==== Radoslaw 30-day (n=", nrow(re30), ") ====\n", sep="")
print(round(rd$table, 4))

# ---------- Figure: coefficient + 95% CI panels ----------
build_df <- function(res, ds) {
  tab <- res$table
  data.frame(
    stat     = rownames(tab),
    estimate = tab[, "Estimate"],
    lo       = tab[, "Estimate"] - 1.96 * tab[, "Std. Error"],
    hi       = tab[, "Estimate"] + 1.96 * tab[, "Std. Error"],
    dataset  = ds)
}
plotdf <- rbind(build_df(cl, "Classroom"), build_df(rd, "Radoslaw (30 d)"))
plotdf$stat <- factor(plotdf$stat, levels = rev(stats_list))

pdf("paper/figures/realdata_coefficients.pdf", width = 7, height = 3.2)
op <- par(mfrow = c(1, 2), mar = c(4, 11, 2, 1), las = 1, cex.axis = 0.85)
for (ds in c("Classroom", "Radoslaw (30 d)")) {
  d <- plotdf[plotdf$dataset == ds, ]
  d <- d[order(match(d$stat, levels(plotdf$stat))), ]
  xrange <- range(c(d$lo, d$hi, 0), na.rm = TRUE) * 1.1
  plot(d$estimate, seq_along(d$stat), xlim = xrange, yaxt = "n",
       ylab = "", xlab = "Coefficient (log-rate ratio)", pch = 19,
       main = ds, ylim = c(0.5, nrow(d) + 0.5))
  arrows(d$lo, seq_along(d$stat), d$hi, seq_along(d$stat),
         length = 0.04, angle = 90, code = 3)
  abline(v = 0, lty = 3, col = "grey60")
  axis(2, at = seq_along(d$stat), labels = d$stat)
}
par(op); dev.off()
cat("\nFigure: paper/figures/realdata_coefficients.pdf\n")

# Save numeric results for the LaTeX table
saveRDS(list(classroom = cl$table, radoslaw = rd$table,
             n_class = nrow(classroom_events), n_rad = nrow(re30)),
        "paper/figures/realdata_results.rds")
