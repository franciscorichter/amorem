library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)
library(pbapply)
library(mgcv)
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

native_codified           <- native[, c("sp.num", "species", "region")]
colnames(native_codified) <- c("sp.num", "sender", "receiver")

# PROPOSAL: TO BE CHECKED AND CORRECTED
source("compute_relational_stats.R")
cc_feat <- compute_relational_stats(
  event_log                  = raw_data_m1,
  stats                      = c("out_sender"),
  sort                       = TRUE,
  additional_previous_events = native_codified,
  history_log                = event_log        # only first records update state
)
cc_feat <- cc_feat[order(cc_feat$time), ]

# P2.3: Computing endogenous covariates ####

## P2.3.1: Invaded regions ####

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

# for (i in 1:nrow(first_records)) {
#   sp  <- first_records$sp.num[i]
#   reg <- first_records$r.num[i]
#   yr  <- first_records$year[i]
#   
#   # find the matching row in cc_feat
#   cc_row <- which(cc_feat$sender   == first_records$species[i] &
#                     cc_feat$receiver == first_records$region[i]  &
#                     cc_feat$time     == yr)
#   
#   if(!identical(unique(colnames(data_distance)[invaded.regions(sp, reg, yr, native, first_records)]),
#                 unique(cc_feat[cc_row, "out_sender"][[1]]))){
#     print(i)
#     print(c("invaded:", colnames(data_distance)[invaded.regions(sp, reg, yr, native, first_records)]))
#     print(c("new:", cc_feat[cc_row, "out_sender"][[1]]))
#   }
# }

## P2.3.2: Temperature ####

compound_region_map <- list(
  "USACanada" = c("United States", "Canada")
)

get_temp <- function(region) {
  if (region %in% data_temperature$X) {
    return(data_temperature[data_temperature$X == region, "temp"][1])
  }
  if (region %in% names(compound_region_map)) {
    parts <- compound_region_map[[region]]
    temps <- data_temperature[data_temperature$X %in% parts, "temp"]
    if (length(temps) > 0) return(mean(temps, na.rm = TRUE))
  }
  return(NA_real_)
}

dt_value <- mapply(function(invaded_regions, current_region) {
  
  if (length(invaded_regions) == 0) return(NA_real_)
  
  avg_temp_invaded  <- sapply(invaded_regions, get_temp)
  avg_temp_interest <- get_temp(current_region)
  
  if (is.na(avg_temp_interest) || all(is.na(avg_temp_invaded))) 
    return(NA_real_)
  
  min(abs(avg_temp_invaded - avg_temp_interest), na.rm = TRUE)
  
}, cc_feat$out_sender, cc_feat$receiver)

cc_feat$dt_value <- dt_value

## P2.3.3: Trade ####

t <- which(data_trade$transfer < 0)
data_trade$transfer[t] <- 0
trade_value <- pbmapply(function(invaded_regions, current_region, y) {
  trade_funct_new <- function(to_region) {
    if (length(invaded_regions) == 0) return(0)
    x <- data_trade[
      data_trade$FromRegion %in% invaded_regions &
        data_trade$ToRegion   == to_region &
        data_trade$year       <= y,
    ]
    if (nrow(x) == 0) return(0)
    most_recent <- aggregate(x$year, list(x$FromRegion), FUN = max)
    trade_vals <- mapply(function(region, max_year) {
      x$transfer[x$FromRegion == region & x$year == max_year]
    }, most_recent[, 1], most_recent[, 2])
    log(sum(unlist(trade_vals), na.rm = TRUE) + 1)
  }
  if (current_region == "USACanada") {
    mean(c(trade_funct_new("United States"),
           trade_funct_new("Canada")))
  } else {
    trade_funct_new(current_region)
  }
}, cc_feat$out_sender, cc_feat$receiver, cc_feat$time)

cc_feat$tr_value <- trade_value

## P2.3.4: Distance ####

distance_value <- pbmapply(function(invaded_regions, current_region, y) {
  
  if (length(invaded_regions) == 0) return(NA_real_)
  
  distances <- data_distance[current_region, invaded_regions]
  
  log(min(distances, na.rm = TRUE) + 1)
  
}, cc_feat$out_sender, cc_feat$receiver, cc_feat$time)

cc_feat$d_value <- distance_value

## P2.4: Constructing the case-control dataset ####

cases_direct <- cc_feat[cc_feat$event == 1L, ]
ctrls_direct <- cc_feat[cc_feat$event == 0L, ]
cases_direct <- cases_direct[order(cases_direct$stratum), ]
ctrls_direct <- ctrls_direct[order(ctrls_direct$stratum), ]
ncc_data <- data.frame(
  stratum    = cases_direct$stratum,
  sender_ev  = cases_direct$sender,
  receiver_ev = cases_direct$receiver,
  sender_nv  = ctrls_direct$sender,
  receiver_nv = ctrls_direct$receiver,
  prev_inv_ev = I(cases_direct$out_sender),
  prev_inv_nv = I(ctrls_direct$out_sender),
  dt_ev  = cases_direct$dt_value,
  dt_nv  = ctrls_direct$dt_value,
  d_dt   = cases_direct$dt_value - ctrls_direct$dt_value,
  tr_ev  = cases_direct$tr_value,
  tr_nv  = ctrls_direct$tr_value,
  d_tr   = cases_direct$tr_value - ctrls_direct$tr_value,
  d_ev  = cases_direct$d_value,
  d_nv  = ctrls_direct$d_value,
  d_d   = cases_direct$d_value - ctrls_direct$d_value,
  one    = 1
)

ncc_data[which(ncc_data$dt_ev != dat.gam$dt1),"receiver_ev"]
# Difference is due to a previous bug related to the 
# absence of USACanada among the rows of data_temperature

ncc_data[which(ncc_data$tr_ev != dat.gam$tr1),"receiver_ev"]
# Some differences are due to a previous bug
# related to the usage of mean(,) instead of mean(c(,))
other_idx <- which(
  ncc_data$tr_ev != dat.gam$tr1 &
    !ncc_data$receiver_ev %in% c("USACanada")
)
# Check if they are equal within floating point tolerance
for (i in other_idx) {
  cat("Row", i, "| diff:", ncc_data$tr_ev[i] - dat.gam$tr1[i],
      "| check:", isTRUE(all.equal(ncc_data$tr_ev[i], dat.gam$tr1[i])), "\n")
}

ncc_data[which(ncc_data$d_ev != dat.gam$d1),"receiver_ev"]
# Same as obtained using the previous code

## P2.5: Fitting various model formulation ####

# compare_models_smooth currently sample the non-events
# this process should follow the non-event sampling strategy shown above

# again it would be important to extrapolate the model objects

# compare_models_smooth(
#   ncc_data,
#   models = list(
#     linear_dt = c(d_dt = "linear"),
#     tve_tr    = c(d_tr = "tve"),
#     nle_d     = c(d_d  = "nle")
#   ),
#   seed = 11, 
#   k = 5)

# REMARK: MISSING RANDOM EFFECTS AS SPLINES!

ss1 <- ncc_data$sender_ev
ss2 <- ncc_data$sender_nv
ss <- factor(c(ss1,ss2))
dim(ss) <- c(length(ss1),2)
unit <- rep(1, nrow(dat.gam))
I = cbind(unit,-unit)	
gam_ss.only <- gam(one ~ s(ss, by=I, bs="re") - 1,
                   family="binomial"(link = 'logit'), data=ncc_data)

re.species <- coefficients(gam_ss.only)
names(re.species) <- levels(ss)

# 5 most invasive species
sort(re.species, decreasing = TRUE)[1:5]