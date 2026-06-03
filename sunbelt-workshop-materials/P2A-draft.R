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
