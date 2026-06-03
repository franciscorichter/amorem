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

native_codified <- native
native_codified <- native_codified[,c("species","region")]
colnames(native_codified) <- c("sender", "receiver")

source(compute_relational_stats)
cc_feat <- compute_relational_stats(
  event_log                  = raw_data_m1,
  stats                      = c("out_sender"),
  sort                       = TRUE,
  additional_previous_events = native_codified
)
head(cc_feat, 30)

# CHECK WITH EXISTING CODE
# invaded.regions <- function(sp.n, r.n, y, native, first_records){
#   
#   # Convert input arguments to numeric type if not already
#   sp.n <- as.numeric(sp.n)
#   r.n <- as.numeric(r.n)
#   y <- as.numeric(y)
#   
#   # Get unique combinations of species number and region number from native data
#   t <- unique(as.vector(subset(native, sp.num == sp.n, r.num)))
#   
#   # Get region numbers from first records data where species number matches
#   pr <- as.vector(subset(first_records, sp.num == sp.n, r.num))
#   
#   # If the invasion is both present in first records data and in native range
#   # consider the former as actual piece of information
#   t <- setdiff(t, pr)
#   
#   # Find indices of first records occurring before end date for the species
#   set.sp <- which(first_records$sp.num == sp.n & first_records$year < y)
#   
#   # Combine regions in native range with regions in first records before date
#   t <- na.omit(c(t, first_records$r.num[set.sp]))
#   
#   # Do not consider the involved region
#   inv <- unlist(setdiff(t, r.n))
#   
#   # Return invaded regions
#   return(inv)
# }
# 
# 
# for (i in seq_len(nrow(first_records))) {
#   if(!identical(colnames(data_distance)[invaded.regions(first_records$sp.num[1], 
#                                                           first_records$r.num[1], 
#                                                           first_records$year[1], 
#                                                           native, first_records)],
#                   cc_feat[1,"out_sender"][[1]])) print(i)
# }



cases_direct <- raw_data_m1[raw_data_m1$event == 1L, ]
ctrls_direct <- raw_data_m1[raw_data_m1$event == 0L, ]
cases_direct <- cases_direct[order(cases_direct$stratum), ]
ctrls_direct <- ctrls_direct[order(ctrls_direct$stratum), ]
ncc_data  <- data.frame(
  stratum = cases_direct$stratum,
  sender_ev = cases_direct$sender,
  receiver_ev = cases_direct$receiver,
  sender_nv = ctrls_direct$sender,
  receiver_nv = ctrls_direct$receiver
)
tab3 <- ncc_data[ncc_data$stratum<=8,]
kable(tab3, format = "latex", booktabs = TRUE)