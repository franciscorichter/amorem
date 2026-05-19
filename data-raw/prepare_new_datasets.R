# Prepare two new bundled REM datasets:
#   college_msg       -- 59,835 directed IMs (Panzarasa 2009)
#   email_eu_core     -- 12,216 emails inside an EU institution dept
#                        (Paranjape, Benson, Leskovec 2017)
# Source: SNAP. Re-runnable from raw files in data-raw/.

# ---- college_msg --------------------------------------------------
cm_raw <- read.table("data-raw/CollegeMsg.txt.gz",
                     col.names = c("sender", "receiver", "unix_time"))
cat("CollegeMsg raw rows:", nrow(cm_raw), "\n")
cm_raw$sender   <- as.character(cm_raw$sender)
cm_raw$receiver <- as.character(cm_raw$receiver)
cm_raw <- cm_raw[order(cm_raw$unix_time), ]
unix_origin <- min(cm_raw$unix_time)
cm <- data.frame(
  time     = (cm_raw$unix_time - unix_origin) / 86400,   # days
  sender   = cm_raw$sender,
  receiver = cm_raw$receiver,
  stringsAsFactors = FALSE)
attr(cm, "unix_origin") <- as.POSIXct(unix_origin,
                                       origin = "1970-01-01",
                                       tz = "UTC")
attr(cm, "time_unit") <- "days"
college_msg <- cm
cat(sprintf("college_msg: %d rows, %d actors, %.1f-day span\n",
            nrow(college_msg),
            length(unique(c(college_msg$sender, college_msg$receiver))),
            diff(range(college_msg$time))))

# ---- email_eu_core (Dept 3) --------------------------------------
eu_raw <- read.table("data-raw/email-eu-core-temporal.txt.gz",
                     col.names = c("sender", "receiver", "secs_since"))
cat("\nEU-core raw rows:", nrow(eu_raw), "\n")
eu_raw$sender   <- as.character(eu_raw$sender)
eu_raw$receiver <- as.character(eu_raw$receiver)
eu_raw <- eu_raw[order(eu_raw$secs_since), ]
# Drop self-loops (about half of email-Eu-core).
eu_raw <- eu_raw[eu_raw$sender != eu_raw$receiver, ]
eu <- data.frame(
  time     = eu_raw$secs_since / 86400,   # days
  sender   = eu_raw$sender,
  receiver = eu_raw$receiver,
  stringsAsFactors = FALSE)
attr(eu, "time_unit") <- "days"
attr(eu, "note") <- "Subset: Department 3 of email-Eu-core (Paranjape et al. 2017)"
email_eu_core <- eu
cat(sprintf("email_eu_core: %d rows, %d actors, %.1f-day span\n",
            nrow(email_eu_core),
            length(unique(c(email_eu_core$sender, email_eu_core$receiver))),
            diff(range(email_eu_core$time))))

# Save
save(college_msg,    file = "data/college_msg.rda",    compress = "xz")
save(email_eu_core,  file = "data/email_eu_core.rda",  compress = "xz")
cat("\nSaved data/college_msg.rda, data/email_eu_core.rda\n")
