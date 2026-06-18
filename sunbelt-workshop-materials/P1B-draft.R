library(amore)
library(dplyr)

# P1.1: What does the generated data look like? ####
data <- read.csv("input/les-miserables.csv")
head(data[,c("IS_OBSERVED","SOURCE","TARGET","TYPE","EVENT_INTERVAL",
                     "individual.activity","dyadic.activity","closure","female","diff.female")])

# P1.2: Construct datasets for two inference procedures ####

## (a): Case-$20$-control fitted via conditional logistic regression ####
fit_clogit <- rem(IS_OBSERVED ~ diff.female
                           + female
                           + individual.activity 
                           + dyadic.activity, method = "clogit", data = data, stratum = "EVENT_INTERVAL")

## (b): Case-$1$-control fitted via degenerate logistic regression ####
set.seed(1234)

cases_direct <- data[data$IS_OBSERVED == 1L, ]
ctrls_direct <- data[data$IS_OBSERVED == 0L, ]

ctrls_sampled <- ctrls_direct %>%
  group_by(EVENT_INTERVAL) %>%
  slice_sample(n = 1) %>%
  ungroup()

data_m1 <- bind_rows(cases_direct, ctrls_sampled) %>%
  arrange(EVENT_INTERVAL)

head(data_m1)


# ctrls_first <- ctrls_direct %>%
#   group_by(EVENT_INTERVAL) %>%
#   slice(1) %>%          # explicitly take the first row
#   ungroup() 
# 
# data_m1 <- bind_rows(cases_direct, ctrls_first) %>%
#   arrange(EVENT_INTERVAL)
# 
# head(data_m1)

data_m1_wide <- widen_case_control(data_m1, case = "IS_OBSERVED", stratum = "EVENT_INTERVAL")
head(data_m1_wide)


fit_glm <- rem(~ d_diff.female + d_female
                 + d_individual.activity 
                 + d_dyadic.activity 
                 - 1, data = data_m1_wide, 
               method="gam")



# P1.3: Effect interpretation ####
summary(fit_clogit)
summary(fit_glm)
