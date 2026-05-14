# paper_replication.R
#
# Fits the paper-preferred Table 3 specifications for Classroom and
# Radoslaw on case-control samples drawn from amore's bundled
# datasets, using survival::coxph for stratified conditional logistic
# regression (linear and pspline-smoothed). Produces
# `paper/figures/paper_replication_aic.csv` and
# `paper/figures/paper_replication_results.rds`.
#
# Caveat
#
# The AIC ranking produced here does NOT match Juozaitiene & Wit
# (2024) Table 3 (which selects the timing specifications): with a
# minimal Cox stratified fit and no actor random effects the
# count-based baseline wins by hundreds of AIC points. The paper's
# ranking depends on sender + receiver random effects (frailty terms
# in coxph parlance), which our case-control wrapper does not
# currently inject. A proper replication would require either
# coxph's frailty() terms with full sender/receiver factors, or
# mgcv::gam with smooth + random effects on a richer design matrix.
# Out of scope for this script -- captured here so the gap is
# explicit and the experiment is reproducible.

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(mgcv); library(survival)
})

fit_clogit <- function(cc_feat, stat_set, smooth = FALSE) {
  cc_feat$.surv <- Surv(rep(1, nrow(cc_feat)), cc_feat$event)
  rhs <- if (smooth) {
    parts <- vapply(stat_set, function(s) {
      if (grepl("time_|exp_decay", s)) sprintf("pspline(%s, df = 3)", s)
      else s
    }, character(1))
    paste(parts, collapse = " + ")
  } else {
    paste(stat_set, collapse = " + ")
  }
  fm <- as.formula(paste(".surv ~", rhs, "+ strata(stratum)"))
  coxph(fm, data = cc_feat, method = "breslow")
}

build_cc <- function(ev, stat_set, n_controls = 3, seed = 11, half_life = 1) {
  cc <- sample_non_events(ev, n_controls = n_controls,
                          scope = "all", mode = "one", seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = stat_set,
                                          half_life = half_life)
  for (st in stat_set) cc_feat[[st]][is.na(cc_feat[[st]])] <- 0
  cc_feat[order(cc_feat$stratum, -cc_feat$event), ]
}

run_dataset <- function(ev, name, specA, specB, half_life = 1) {
  cat("\n==", name, "(n =", nrow(ev), ") ==\n")
  cc_feat <- build_cc(ev, unique(c(specA, specB)),
                      n_controls = 3, seed = 11, half_life = half_life)
  fitA <- fit_clogit(cc_feat, specA, smooth = FALSE)
  fitB_lin <- fit_clogit(cc_feat, specB, smooth = FALSE)
  fitB_sm  <- fit_clogit(cc_feat, specB, smooth = TRUE)
  data.frame(
    dataset = name,
    spec    = c("A: count baseline", "B: paper, linear", "B: paper, smooth"),
    AIC     = c(AIC(fitA), AIC(fitB_lin), AIC(fitB_sm)),
    n_terms = c(length(specA), length(specB), length(specB)))
}

# Classroom
data(classroom_events)
res_class <- run_dataset(
  classroom_events, "Classroom",
  specA = c("reciprocity_count", "transitivity_count"),
  specB = c("reciprocity_time_recent_interrupted",
            "transitivity_time_recent_interrupted",
            "cyclic_time_recent",
            "sending_balance_time_recent",
            "receiving_balance_exp_decay"),
  half_life = 1)
print(res_class)

# Radoslaw 30-day slice
data(radoslaw_email)
re <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]
re30 <- re[re$time < 30, ]
res_rad <- run_dataset(
  re30, "Radoslaw 30 d",
  specA = c("reciprocity_count", "transitivity_count"),
  specB = c("reciprocity_time_recent",
            "transitivity_time_recent_interrupted",
            "cyclic_time_recent",
            "sending_balance_time_recent_interrupted",
            "receiving_balance_time_recent_interrupted"),
  half_life = 1)
print(res_rad)

all_res <- rbind(res_class, res_rad)
all_res$delta_AIC <- ave(all_res$AIC, all_res$dataset, FUN = function(x) x - min(x))
print(all_res)
saveRDS(all_res, "paper/figures/paper_replication_results.rds")
write.csv(all_res, "paper/figures/paper_replication_aic.csv", row.names = FALSE)
