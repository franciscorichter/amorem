library(amore)

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

head(raw_data_m1,20)


# P1.2: Construct datasets for two inference procedures ####

## (a): Case-$7$-control for inference via conditional logistic regression ####

set.seed(1)
raw_data_m7 <- simulate_relational_events(
  n_events           = 1000,
  senders            = paste0("a", 1:20),
  receivers          = paste0("a", 1:20),
  baseline_rate      = 1,
  n_controls         = 7,
  endogenous_stats   = "reciprocity_count", 
  endogenous_effects = c(reciprocity_count = 0.6),
)

head(raw_data_m7,10)

## (b): Case-$1$-control dataset in "wide" format for inference via degenerate logistic regression ####


wide_data_m1 <- widen_case_control(raw_data_m1, case = "event", stratum= "stratum")
head(wide_data_m1)

### could have also gotten it already in this format from simulate_relational_events(..., n_controls = 1, wide = T)


# P1.3: Inference procedures ####

## (a): Conditional logistic regression ####

fit_clogit <- rem(event ~ reciprocity_count, data = raw_data_m7, method = "clogit")
summary(fit_clogit)


## (b): Degenerate logistic regression ####

fit_glm <- rem(~ reciprocity_count, data = wide_data_m1, method = "gam")
summary(fit_glm)


### if passing directly data in long format
fit_glm_long_format <- rem(~ reciprocity_count, data = raw_data_m1, method = "gam", stratum = "stratum")
summary(fit_glm_long_format)


# P1.4: Replicate the simulation study 100 times  ####

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
  
  # fit degenerate logistic regression
  wide_d1 <- widen_case_control(d1, case = "event", stratum = "stratum")
  fit_glm <- rem(~ reciprocity_count, data = wide_d1, method = "gam")
  coefs$glm_1[i] <- coef(fit_glm)[["reciprocity_count"]]
  
  
  # case-7-control dataset
  d7 <- simulate_relational_events(
    n_events           = N_EVENTS,
    senders            = SENDERS,
    receivers          = RECEIVERS,
    baseline_rate      = 1,
    n_controls         = 7,
    endogenous_stats   = "reciprocity_count", 
    endogenous_effects = c(reciprocity_count = TRUE_BETA)
  )
  
  fit_clogit_7 <- rem(event ~ reciprocity_count, data = d7, method = "clogit")
  coefs$clogit_7[i] <- coef(fit_clogit_7)[["reciprocity_count"]]
  
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
  
  fit_clogit_20 <- rem(event ~ reciprocity_count, data = d20, method = "clogit")
  coefs$clogit_20[i] <- coef(fit_clogit_20)[["reciprocity_count"]]
  
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
