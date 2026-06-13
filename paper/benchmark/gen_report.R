# Generate the cross-machine benchmark figure + LaTeX table fragment
# from data/timings_<machine>.csv. Run from paper/benchmark/.
machines <- c("air", "studio", "whitebox")
labels   <- c(air = "Air (M4)", studio = "Studio (M1 Max)", whitebox = "Whitebox (Ryzen 9)")
cols     <- c(air = "#2c6e63", studio = "#7fb2aa", whitebox = "#c97b4a")

dat <- do.call(rbind, lapply(machines, function(m) {
  f <- file.path("data", paste0("timings_", m, ".csv"))
  if (file.exists(f)) read.csv(f) else NULL
}))
dat <- dat[dat$experiment != "compile_warmup", ]
exps <- c("exp1_recovery", "exp2_smooth", "exp3_frailty",
          "exp4_scaling", "exp5_parity", "exp6_nn")
enames <- c("E1 recovery", "E2 smooth", "E3 frailty",
            "E4 scaling", "E5 parity", "E6 neural")

M <- sapply(machines, function(m)
  sapply(exps, function(e) {
    v <- dat$seconds[dat$machine == m & dat$experiment == e]
    if (length(v)) v[1] else NA
  }))

# ---- figure: grouped bars, log scale ----
png("figs/benchmark-times.png", width = 1150, height = 500, res = 110)
par(mar = c(4.2, 4.5, 2.5, 1))
bp <- barplot(t(M), beside = TRUE, log = "y", names.arg = enames,
              col = cols[machines], border = NA,
              ylab = "wall-clock seconds (log scale)",
              main = "amore validation experiments: wall-clock by machine",
              ylim = c(0.05, max(M, na.rm = TRUE) * 2.2))
legend("topleft", labels[machines], fill = cols[machines], bty = "n", cex = 0.95)
txt <- ifelse(t(M) < 10, sprintf("%.1f", t(M)), sprintf("%.0f", t(M)))
text(bp, t(M) * 1.25, txt, cex = 0.62, xpd = NA)
dev.off()

# ---- LaTeX table fragment ----
rel <- sweep(M, 1, M[, "air"], "/")   # ratio vs air
rows <- sapply(seq_along(exps), function(i) {
  sprintf("%s & %.1f & %.1f & %.1f & %.2f & %.2f \\\\",
          enames[i], M[i, "air"], M[i, "studio"], M[i, "whitebox"],
          rel[i, "studio"], rel[i, "whitebox"])
})
tot <- colSums(M, na.rm = TRUE)
rows <- c(rows, "\\midrule",
          sprintf("\\textbf{Total} & \\textbf{%.1f} & \\textbf{%.1f} & \\textbf{%.1f} & %.2f & %.2f \\\\",
                  tot["air"], tot["studio"], tot["whitebox"],
                  tot["studio"] / tot["air"], tot["whitebox"] / tot["air"]))
writeLines(rows, "table-times.tex")
cat("written figs/benchmark-times.png and table-times.tex\n")
print(round(M, 2))
