library(amore)
suppressPackageStartupMessages(library(survival))

n_reps   <- 100
true_val <- 0.6

results <- data.frame(
  rep     = integer(0),
  model   = character(0),
  coef    = numeric(0)
)

for (i in seq_len(n_reps)) {
  
  set.seed(i)
  
  # 1. Simulate data
  raw_data <- simulate_relational_events(
    n_events           = 1000,
    senders            = paste0("a", 1:20),
    receivers          = paste0("a", 1:20),
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6)
  )
  
  # 2. clogit
  fit_clogit <- clogit(event ~ reciprocity_count + strata(stratum),
                       data = raw_data)
  results <- rbind(results, data.frame(
    rep   = i,
    model = "clogit",
    coef  = as.numeric(coef(fit_clogit))
  ))
  
  # 3. Manual GLM on simulated data 
  cases_direct <- raw_data[raw_data$event == 1L, ]
  ctrls_direct <- raw_data[raw_data$event == 0L, ]
  cases_direct <- cases_direct[order(cases_direct$stratum), ]
  ctrls_direct <- ctrls_direct[order(ctrls_direct$stratum), ]
  diff_direct  <- data.frame(
    d_reciprocity_count = cases_direct$reciprocity_count -
      ctrls_direct$reciprocity_count,
    one = 1
  )
  fit_direct <- glm(one ~ d_reciprocity_count - 1,
                    family = "binomial", data = diff_direct)
  results <- rbind(results, data.frame(
    rep   = i,
    model = "GLM (simulated data)",
    coef  = as.numeric(coef(fit_direct))
  ))
  
  # 4. sample_non_events + compute_endogenous_features + GLM 
  cc <- sample_non_events(
    raw_data[raw_data$event == 1, c("sender", "receiver", "time")],
    n_controls = 1, scope = "all", mode = "one"
  )
  cc_feat <- compute_endogenous_features(cc, stats = "reciprocity_count")
  
  cases_post <- cc_feat[cc_feat$event == 1L, ]
  ctrls_post <- cc_feat[cc_feat$event == 0L, ]
  cases_post <- cases_post[order(cases_post$stratum), ]
  ctrls_post <- ctrls_post[order(ctrls_post$stratum), ]
  diff_post  <- data.frame(
    d_reciprocity_count = cases_post$reciprocity_count -
      ctrls_post$reciprocity_count,
    one = 1
  )
  fit_post <- glm(one ~ d_reciprocity_count - 1,
                  family = "binomial", data = diff_post)
  results <- rbind(results, data.frame(
    rep   = i,
    model = "GLM (recomputed stats)",
    coef  = as.numeric(coef(fit_post))
  ))
  
  if (i %% 10 == 0) cat("Completed rep", i, "\n")
}

# Plot
model_order  <- c("clogit", "GLM (simulated data)", "GLM (recomputed stats)")
model_labels <- c("clogit", "Manual GLM\n(simulated data)", "Manual GLM\n(recomputed stats)")
results$model <- factor(results$model, levels = model_order)

cols <- c(
  "clogit"                = "#2E86AB",
  "GLM (simulated data)"  = "#E84855",
  "GLM (recomputed stats)"= "#3BB273"
)

par(
  mar     = c(5, 5, 4, 2),
  family  = "sans",
  bg      = "#F8F9FA"
)

bp <- boxplot(
  coef ~ model,
  data     = results,
  col      = cols[model_order],
  border   = "#333333",
  names    = model_labels,
  ylab     = expression(hat(beta)[reciprocity]),
  xlab     = "",
  main     = "",
  outline  = TRUE,
  outcol   = adjustcolor("#333333", 0.5),
  outpch   = 16,
  outcex   = 0.6,
  whisklty = 1,
  staplelwd= 1.5,
  boxwex   = 0.45,
  cex.axis = 0.9,
  cex.lab  = 1.0,
  las      = 1
)

abline(h = true_val, lty = 2, lwd = 2, col = "#FF6B35")

legend(
  "topright",
  legend    = sprintf("True value = %.1f", true_val),
  lty       = 2,
  lwd       = 2,
  col       = "#FF6B35",
  bty       = "n",
  cex       = 0.9
)

title(
  main = bquote(bold("Coefficient recovery across 100 replications") ~
                  "(n = 1 000 events, 1 control each)"),
  cex.main = 1.0,
  col.main = "#222222"
)