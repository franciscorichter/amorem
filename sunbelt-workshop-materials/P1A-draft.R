library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)

# P1.1: What does the generated data look like? ####
set.seed(1)
raw_data_m1 <- simulate_relational_events(
  n_events           = 1000,
  senders            = paste0("a", 1:20),
  receivers          = paste0("a", 1:20),
  baseline_rate      = 1,
  n_controls         = 1,
  endogenous_stats   = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = 0.6)
)

tab1 <- head(raw_data_m1, which(raw_data_m1$event == 1 & raw_data_m1$reciprocity_count == 1)[1] + 1)
kable(tab1, format = "latex", booktabs = TRUE)


# P1.2: Construct datasets for two inference procedures ####

## (a): Case-$7$-control fitted via conditional logistic regression ####

set.seed(1)
raw_data_m7 <- simulate_relational_events(
  n_events           = 1000,
  senders            = paste0("a", 1:20),
  receivers          = paste0("a", 1:20),
  baseline_rate      = 1,
  n_controls         = 7,
  endogenous_stats   = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = 0.6)
)

tab2 <- raw_data_m7[raw_data_m7$stratum<=2,]
kable(tab2, format = "latex", booktabs = TRUE)

fit_clogit <- clogit(event ~ reciprocity_count + strata(stratum),
                     data = raw_data_m7)
coef(fit_clogit)

## (b): Case-$1$-control fitted via degenerate logistic regression ####

cases_direct <- raw_data_m1[raw_data_m1$event == 1L, ]
ctrls_direct <- raw_data_m1[raw_data_m1$event == 0L, ]
cases_direct <- cases_direct[order(cases_direct$stratum), ]
ctrls_direct <- ctrls_direct[order(ctrls_direct$stratum), ]
ncc_data  <- data.frame(
  stratum = cases_direct$stratum,
  sender_ev = cases_direct$sender,
  receiver_ev = cases_direct$receiver,
  sender_nv = ctrls_direct$sender,
  receiver_nv = ctrls_direct$receiver,
  d_reciprocity_count = cases_direct$reciprocity_count -
    ctrls_direct$reciprocity_count,
  one = 1
)
fit_glm <- glm(one ~ d_reciprocity_count - 1,
               family = "binomial", data = ncc_data)
tab3 <- ncc_data[ncc_data$stratum<=8,]
kable(tab3, format = "latex", booktabs = TRUE)
AIC(fit_glm)

cc <- sample_non_events(
  raw_data_m1[raw_data_m1$event == 1L, c("sender", "receiver", "time")],
  n_controls = 1,
  scope      = "all",
  mode       = "one",
  seed=1
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
AIC(fit_glm_r)

compare_models(
  raw_data_m1[raw_data_m1$event == 1L, c("sender", "receiver", "time")],
  models = list(
    count       = c("reciprocity_count")),
  n_controls = 1, seed = 1)

# P1.3: Replicate the simulation study 100 times ####

# parameters
N_SIM        <- 100
N_EVENTS     <- 1000
TRUE_BETA    <- 0.6          
SENDERS      <- paste0("a", 1:20)
RECEIVERS    <- paste0("a", 1:20)

# storage
coefs <- data.frame(
  glm_1   = numeric(N_SIM),   # degenerate logistic, 1 control
  clogit_7  = numeric(N_SIM), # conditional logit,   7 controls
  clogit_20 = numeric(N_SIM)  # conditional logit,  20 controls
)

for (i in seq_len(N_SIM)) {
  
  set.seed(i)
  
  # case-1-control dataset
  d1 <- simulate_relational_events(
    n_events           = N_EVENTS,
    senders            = SENDERS,
    receivers          = RECEIVERS,
    baseline_rate      = 1,
    n_controls         = 1,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = TRUE_BETA),
  )
  
  cases <- d1[d1$event == 1L, ]
  ctrls <- d1[d1$event == 0L, ]
  cases <- cases[order(cases$stratum), ]
  ctrls <- ctrls[order(ctrls$stratum), ]
  
  ncc <- data.frame(
    d_reciprocity_count = cases$reciprocity_count - ctrls$reciprocity_count,
    one = 1L
  )
  
  fit_glm <- glm(one ~ d_reciprocity_count - 1,
                 family = binomial, data = ncc)
  coefs$glm_1[i] <- coef(fit_glm)[["d_reciprocity_count"]]
  
  # case-7-control dataset
  d7 <- simulate_relational_events(
    n_events           = N_EVENTS,
    senders            = SENDERS,
    receivers          = RECEIVERS,
    baseline_rate      = 1,
    n_controls         = 7,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = TRUE_BETA),
  )
  
  fit7 <- clogit(event ~ reciprocity_count + strata(stratum), data = d7)
  coefs$clogit_7[i] <- coef(fit7)[["reciprocity_count"]]
  
  # case-20-control dataset
  d20 <- simulate_relational_events(
    n_events           = N_EVENTS,
    senders            = SENDERS,
    receivers          = RECEIVERS,
    baseline_rate      = 1,
    n_controls         = 20,
    endogenous_stats   = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = TRUE_BETA),
  )
  
  fit20 <- clogit(event ~ reciprocity_count + strata(stratum), data = d20)
  coefs$clogit_20[i] <- coef(fit20)[["reciprocity_count"]]
  
  if (i %% 10 == 0) message(sprintf("  Completed %d / %d replications", i, N_SIM))
}

coefs_long <- stack(coefs)
levels(coefs_long$ind) <- c(
  "Logistic\n(1 control)",
  "Cond. logit\n(7 controls)",
  "Cond. logit\n(20 controls)"
)
cols <- c("#4E79A7", "#F28E2B", "#59A14F")
boxplot(
  values ~ ind,
  data       = coefs_long,
  col        = cols,
  border     = darken <- adjustcolor(cols, red.f = 0.6, green.f = 0.6, blue.f = 0.6),
  outcol     = cols,
  outpch     = 16,
  cex        = 0.6,
  las        = 1,
  xlab       = "",
  ylab       = expression(hat(beta)),
  main       = expression(
    "Estimated "*beta*" for reciprocity_count across 100 replications"
  ),
  cex.main   = 1.0,
  cex.lab    = 0.95,
  frame.plot = FALSE
)
abline(h = TRUE_BETA, lty = 2, lwd = 1.8, col = "black")
