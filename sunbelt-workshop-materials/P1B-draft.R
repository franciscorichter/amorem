library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)
library(dplyr)

# P1.1: What does the generated data look like? ####
data <- read.csv("input/les-miserables.csv")
tab1 <- head(data[,c("IS_OBSERVED","SOURCE","TARGET","TYPE","EVENT_INTERVAL",
                     "individual.activity","dyadic.activity","closure","female","diff.female")])
kable(tab1, format = "latex", booktabs = TRUE)

# P1.2: Construct datasets for two inference procedures ####

## (a): Case-$20$-control fitted via conditional logistic regression ####
fit_clogit <- clogit(IS_OBSERVED ~ 
                       + diff.female
                     + female
                     + individual.activity 
                     + dyadic.activity 
                     + strata(EVENT_INTERVAL)
                     , data = data)

## (b): Case-$1$-control fitted via degenerate logistic regression ####
set.seed(1234)
cases_direct <- data[data$IS_OBSERVED == 1L, ]
ctrls_direct  <- data[data$IS_OBSERVED == 0L, ]
ctrls_sampled <- ctrls_direct %>%
  group_by(EVENT_INTERVAL) %>%
  slice_sample(n = 1) %>%
  ungroup()
cases_direct  <- cases_direct[order(cases_direct$EVENT_INTERVAL), ]
ctrls_sampled <- ctrls_sampled[order(ctrls_sampled$EVENT_INTERVAL), ]
ncc_data  <- data.frame(
  stratum = cases_direct$EVENT_INTERVAL,
  sender_ev = cases_direct$SOURCE,
  sender_nv = ctrls_direct$SOURCE,
  d_individual.activity = cases_direct$individual.activity -
    ctrls_direct$individual.activity,
  d_dyadic.activity = cases_direct$dyadic.activity -
    ctrls_direct$dyadic.activity,
  d_closure = cases_direct$closure -
    ctrls_direct$closure,
  d_female = cases_direct$female -
    ctrls_direct$female,
  d_diff.female = cases_direct$diff.female -
    ctrls_direct$diff.female,
  one = 1
)

fit_glm <- glm(one ~ 
                 + d_diff.female + d_female
                 + d_individual.activity 
                 + d_dyadic.activity 
                 - 1, data = ncc_data, 
               family="binomial")

tab2 <- head(ncc_data)
kable(tab2, format = "latex", booktabs = TRUE)

# P1.3: Effect interpretation ####
summary(fit_clogit)
summary(fit_glm)
