library(amore)
suppressPackageStartupMessages(library(survival))

# parameters
N_SIM     <- 100
N_EVENTS  <- 1000
TRUE_BETA <- 0.6
SENDERS   <- paste0("a", 1:20)
RECEIVERS <- paste0("a", 1:20)

# storage
coefs <- data.frame(
  clogit_1       = numeric(N_SIM),  # conditional logit,   1 control (original data)
  glm_1          = numeric(N_SIM),  # degenerate logistic, 1 control (original data)
  glm_1_resampled = numeric(N_SIM)  # degenerate logistic, 1 control (resampled non-events)
)

for (i in seq_len(N_SIM)) {
  
  set.seed(i)
  
  # simulate case-1-control dataset
  raw_data <- simulate_relational_events(
    n_events           = N_EVENTS,
    senders            = SENDERS,
    receivers          = RECEIVERS,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = TRUE_BETA)
  )
  
  # clogit on original data
  fit_clogit <- clogit(event ~ reciprocity_count + strata(stratum),
                       data = raw_data)
  coefs$clogit_1[i] <- coef(fit_clogit)[["reciprocity_count"]]
  
  # degenerate GLM on original data
  cases <- raw_data[raw_data$event == 1L, ]
  ctrls <- raw_data[raw_data$event == 0L, ]
  cases <- cases[order(cases$stratum), ]
  ctrls <- ctrls[order(ctrls$stratum), ]
  
  ncc <- data.frame(
    d_reciprocity_count = 
      cases$reciprocity_count - ctrls$reciprocity_count,
    one = 1L
  )
  
  fit_glm <- glm(one ~ d_reciprocity_count - 1,
                 family = binomial, data = ncc)
  coefs$glm_1[i] <- coef(fit_glm)[["d_reciprocity_count"]]
  
  # resample non-events + recompute covariates, then degenerate GLM 
  cc <- sample_non_events(
    raw_data[raw_data$event == 1L, c("sender", "receiver", "time")],
    n_controls = 1,
    scope      = "all",
    mode       = "one"
  )
  cc_feat <- compute_endogenous_features(cc, stats = "reciprocity_count")
  
  cases_r <- cc_feat[cc_feat$event == 1L, ]
  ctrls_r <- cc_feat[cc_feat$event == 0L, ]
  cases_r <- cases_r[order(cases_r$stratum), ]
  ctrls_r <- ctrls_r[order(ctrls_r$stratum), ]
  
  ncc_resampled <- data.frame(
    d_reciprocity_count = cases_r$reciprocity_count - ctrls_r$reciprocity_count,
    one = 1L
  )
  
  fit_glm_r <- glm(one ~ d_reciprocity_count - 1,
                   family = binomial, data = ncc_resampled)
  coefs$glm_1_resampled[i] <- coef(fit_glm_r)[["d_reciprocity_count"]]
  
  if (i %% 10 == 0) message(sprintf("  Completed %d / %d replications", i, N_SIM))
}

coefs_long <- stack(coefs)
levels(coefs_long$ind) <- c(
  "Cond. logit\n(1 control)",
  "Logistic\n(1 control)",
  "Logistic\n(resampled)"
)

cols <- c("#4E79A7", "#F28E2B", "#59A14F")

boxplot(
  values ~ ind,
  data       = coefs_long,
  col        = cols,
  border     = adjustcolor(cols, red.f = 0.6, green.f = 0.6, blue.f = 0.6),
  outcol     = cols,
  outpch     = 16,
  cex        = 0.6,
  las        = 1,
  xlab       = "",
  ylab       = expression(hat(beta)),
  main       = expression(
    "Estimated "*beta*" for reciprocity_count across 100 replications  ("*m==1*")"
  ),
  cex.main   = 1.0,
  cex.lab    = 0.95,
  frame.plot = FALSE
)

abline(h = TRUE_BETA, lty = 2, lwd = 1.8, col = "black")

