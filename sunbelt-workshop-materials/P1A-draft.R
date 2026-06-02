library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)

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
