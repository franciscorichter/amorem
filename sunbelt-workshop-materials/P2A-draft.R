library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)
load("input/first_records.RData")

# P2.1: Importing data ####
event_log <- standardize_event_log(first_records[,c(1,3:4)],
                                   sender_col = "species",
                                   receiver_col = "region",
                                   time_col = "year")
event_log <- event_log[order(event_log$time), ]
tab1 <- head(event_log)
kable(tab1, format = "latex", booktabs = TRUE)


# P2.2: Defining the risk set####
# PROPOSAL
# raw_data_m1 <- sample_non_events(event_log,
#                               scope      = "all", 
#                               # exclude if it has already occurred.
#                               risk       = "remove",
#                               exclude_fn = 
#                                 function(sender, receiver, time, fr) {
#                                   # exclude if is part of the native range
#                                   is_native     <- any(native$species == sender & 
#                                                        native$region == receiver)
#                                   # exclude if it has occurred at the same time
#                                   is_concurrent <- any(fr$time == time)
#                                   is_native || is_concurrent})

# currently possible in amore (but wrong conceptually for this application):
raw_data_m1 <- sample_non_events(event_log,
                              scope      = "all", 
                              risk       = "remove")
head(raw_data_m1)

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
