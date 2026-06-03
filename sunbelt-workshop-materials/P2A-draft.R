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
# ncc_data <- sample_non_events(event_log,
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

