# install.packages("remotes")
# install.packages("remotes")
# remotes::install_github("franciscorichter/amore")

library(amore)
library(pbapply)
load("input/first_records.RData")



# P2.1: Importing data ####
event_log <- standardize_event_log(first_records[,c(1,3:4)],
                                   sender_col = "species",
                                   receiver_col = "region",
                                   time_col = "year")
  
head(event_log)


native_df<-cbind(native[, c("species", "region")],"time" = 1879)
colnames(native_df)<-c("sender", "receiver", "time")
head(native_df)

# P2.2: Case-control sampling from the risk set####
set.seed(1234)
cc <- sample_non_events(event_log,
                        n_controls = 1,              # 1 control is default
                        scope         = "all",
                        mode          = "two",
                        risk          = "remove",    # drops past + concurrent
                        exclude_pairs = native_df[,1:2])   ### sender 1st col rec 2nd col


head(cc)


# P2.3: Computing endogenous covariates ####

## P2.3.1: Invaded regions ####

feats <- compute_endogenous_features(cc, stats = "sender_receivers_set",
                                         history_log = event_log, prior_log = native_df)

head(feats)

## remove current region to avoid zero difference
feats$invaded<- mapply(setdiff,feats$sender_receivers_set,feats$receiver)


## P2.3.2: Temperature ####
head(data_temperature)

compound_region_map <- list(
  "USACanada" = c("United States", "Canada")
)

get_temp <- function(region,compound_areas = compound_region_map) {
  if (region %in% data_temperature$X) {
    return(data_temperature[data_temperature$X == region, "temp"][1])
  }
  if (region %in% names(compound_areas)) {
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
  
}, feats$invaded, feats$receiver)

feats$temp  <- dt_value

## P2.3.3: Trade ####

head(data_trade)

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
}, feats$invaded, feats$receiver, feats$time)

feats$trade<- trade_value

## P2.3.4: Distance ####

head(data_distance)

distance_value <- pbmapply(function(invaded_regions, current_region, y) {
  
  if (length(invaded_regions) == 0) return(NA_real_)
  
  distances <- data_distance[current_region, invaded_regions]
  
  log(min(distances, na.rm = TRUE) + 1)
  
}, feats$invaded, feats$receiver, feats$time)

feats$dist <- distance_value


# P2.4: Constructing the case-control dataset ####
cc_wide <- widen_case_control(feats, case = "event",stratum = "stratum")
head(cc_wide)


# P2.5: Fitting various model formulation ####

## P2.5.1 Fixed linear effect ####
m1_only_temp_l<- rem(~ temp, data = cc_wide, method = "gam")
summary(m1_only_temp_l)

## P2.5.2 Time-varying linear effect ####
m2_only_trade_tv<- rem(~ tv(trade),time = "time_ev", data = cc_wide, method = "gam")
summary(m2_only_trade_tv)
plot(m2_only_trade_tv)

## P2.5.3 Non-linear effect ####
m3_only_dist_nl<- rem(~ nl(dist), data = cc_wide, method = "gam")
summary(m3_only_dist_nl)
plot(m3_only_dist_nl)

## P2.5.4 Random effect (intercept) ####
m4_only_sender_re<- rem(~ re(sender), data = cc_wide, method = "gam")
summary(m4_only_sender_re)
re.species <- coefficients(m4_only_sender_re)

#### rem with re() effect specification fits a random intercept based on the specified group var
#### it handles factor encoding internally which renders used of output less intuitive.
#### the following replicates the mapping from group var format to factor in order to print results in the original format
ev <- cc_wide[["sender_ev"]]
nv <- cc_wide[["sender_nv"]]
fmat <- factor(c(as.character(ev), as.character(nv))) # Replicate what rem() does internally
names(re.species) <- levels(fmat)  # The mapping: index 1 = levels(fmat)[1], index 2 = levels(fmat)[2], etc.


cat("5 most invasive species:\n");  print(sort(re.species, decreasing = TRUE)[1:5])
cat("5 least invasive species:\n"); print(sort(re.species)[1:5])

## P2.5.5 Full model ####
m5_full <- rem(~ temp + 
                 tv(trade) + 
                 nl(dist) +
                 re(sender), time = "time_ev", data = cc_wide, method = "gam")

# P2.6 Model Comparison (using AIC) ####

aic_table <- data.frame(
  model     = c("dt_only", "tr_only", "d_only", "sp_only", "complete"),
  AIC       = c(AIC(m1_only_temp_l), AIC(m2_only_trade_tv), AIC(m3_only_dist_nl),
                AIC(m4_only_sender_re), AIC(m5_full))
)
aic_table <- aic_table[order(aic_table$AIC), ]
print(aic_table)





