# Readers for the data catalogue: one function per folder in data-raw/raw/,
# returning the standard object documented in profile.R. Each reader reads the
# files exactly as downloaded (see the folder's SOURCES/URLS and SHA256SUMS).

suppressPackageStartupMessages(library(data.table))
RAW <- file.path(path.expand("~/System/Research/REM/data-raw/raw"))
.p <- function(...) file.path(RAW, ...)
.unix <- as.POSIXct("1970-01-01", tz = "UTC")

dyadic <- function(sender, receiver, time, directed, unit, origin = NULL, tz = "UTC", note = "") {
  list(kind = "dyadic", directed = directed,
       events = data.frame(sender = as.character(sender), receiver = as.character(receiver),
                           time = as.numeric(time)),
       time_unit = unit, origin = origin, tz = tz, note = note)
}
.tij <- function(file, cols = c("t", "i", "j"), ...) {
  d <- fread(cmd = paste("gzip -dc", shQuote(file)), header = FALSE, ...)
  setnames(d, seq_along(cols), cols); d
}
.untar_read <- function(archive, member, flag = "z", ...) {
  fread(cmd = sprintf("tar -x%sOf %s %s", flag, shQuote(archive), shQuote(member)), ...)
}
# KONECT out.* files: '%' header lines, columns separated by spaces and tabs.
.konect <- function(archive, member) {
  fread(cmd = sprintf("tar -xjOf %s %s | grep -v '^%%' | tr '\\t' ' '", shQuote(archive), shQuote(member)),
        header = FALSE, sep = " ", fill = TRUE)
}

readers <- list(
  # --- SocioPatterns (CC BY-NC-SA): undirected contacts at 20-s resolution ----
  "sp-sfhh-conference" = function() { d <- .tij(.p("sp-sfhh-conference", "SFHH_tij.dat.gz"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "time is seconds from an unstated origin") },
  "sp-hospital-lyon" = function() { d <- .tij(.p("sp-hospital-lyon", "hospital_lyon_contacts.dat.gz"), c("t", "i", "j", "Si", "Sj"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "roles: ADM, MED, NUR, PAT") },
  "sp-highschool-2011-2012" = function() { d <- .tij(.p("sp-highschool-2011-2012", "highschool_2012.csv.gz"), c("t", "i", "j", "Ci", "Cj"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "2012 file (180 students, 5 classes); the 2011 file is also in the folder") },
  "sp-highschool-2013" = function() { d <- .tij(.p("sp-highschool-2013", "HighSchool2013_proximity_net.csv.gz"), c("t", "i", "j", "Ci", "Cj"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", .unix, "Europe/Paris", "Unix time; Lycee Thiers, Marseille, December 2013") },
  "sp-primaryschool" = function() { d <- .tij(.p("sp-primaryschool", "primaryschool.csv.gz"), c("t", "i", "j", "Ci", "Cj"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "two school days, Lyon, October 2009") },
  "sp-workplace-invs15" = function() { d <- .tij(.p("sp-workplace-invs15", "workplace_InVS15_tij.dat.gz"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "office building, 2015") },
  "sp-workplace-invs13" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("sp-workplace-invs13", "workplace_InVS_tij.dat.zip"))), header = FALSE, col.names = c("t", "i", "j"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "office building, 2013") },
  "sp-ht2009" = function() { d <- .tij(.p("sp-ht2009", "ht2009_contact_list.dat.gz"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", note = "ACM Hypertext 2009, three days") },
  "sp-baboons" = function() { d <- fread(cmd = paste("gzip -dc", shQuote(.p("sp-baboons", "baboons_proximity_data.txt.gz"))))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", .unix, "Europe/Paris", "Unix time; Guinea baboons, CNRS primate centre, Rousset, June-July 2019") },
  "sp-malawi-village" = function() { d <- fread(cmd = paste("gzip -dc", shQuote(.p("sp-malawi-village", "tnet_malawi_pilot.csv.gz"))))
    dyadic(d$id1, d$id2, d$day * 86400 + d$contact_time, FALSE, "seconds", note = "time = day * 86400 + contact_time") },
  "sp-kenya-households" = function() {
    d <- fread(cmd = paste("unzip -p", shQuote(.p("sp-kenya-households", "scc2034_household_contact_dataset.zip")), "scc2034_kilifi_all_contacts_within_households.csv"))
    dyadic(paste0(d$h1, d$m1), paste0(d$h2, d$m2), (d$day - 1) * 86400 + d$hour * 3600, FALSE, "seconds",
           note = "hourly resolution: time = (day - 1) * 86400 + hour * 3600; one row per contact with duration") },
  "sp-infectious-dublin" = function() {
    a <- .p("sp-infectious-dublin", "sciencegallery_infectious_contacts.tgz")
    m <- system2("tar", c("-tzf", shQuote(a)), stdout = TRUE)[1]
    d <- .untar_read(a, m, header = FALSE, col.names = c("t", "i", "j"))
    dyadic(d$i, d$j, d$t, FALSE, "seconds", .unix, "Europe/Dublin",
           paste("one day of the 69 daily files:", m)) },
  # --- SNAP (no licence stated) -----------------------------------------------
  "snap-collegemsg" = function() { d <- .tij(.p("snap-collegemsg", "CollegeMsg.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "America/Los_Angeles", "Unix time; UC Irvine") },
  "snap-email-eu-core-temporal" = function() { d <- .tij(.p("snap-email-eu-core-temporal", "email-Eu-core-temporal.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", note = "full network; seconds from an unstated origin") },
  "snap-sx-mathoverflow" = function() { d <- .tij(.p("snap-sx-mathoverflow", "sx-mathoverflow.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC", "answers and comments, all interaction types") },
  "snap-sx-askubuntu" = function() { d <- .tij(.p("snap-sx-askubuntu", "sx-askubuntu.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC") },
  "snap-sx-superuser" = function() { d <- .tij(.p("snap-sx-superuser", "sx-superuser.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC") },
  "snap-wiki-talk-temporal" = function() { d <- .tij(.p("snap-wiki-talk-temporal", "wiki-talk-temporal.txt.gz"), c("i", "j", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC", "English Wikipedia user talk pages") },
  "snap-bitcoin-otc" = function() { d <- fread(cmd = paste("gzip -dc", shQuote(.p("snap-bitcoin-otc", "soc-sign-bitcoinotc.csv.gz"))), header = FALSE, col.names = c("i", "j", "rating", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC", "trust ratings from -10 to +10") },
  "snap-bitcoin-alpha" = function() { d <- fread(cmd = paste("gzip -dc", shQuote(.p("snap-bitcoin-alpha", "soc-sign-bitcoinalpha.csv.gz"))), header = FALSE, col.names = c("i", "j", "rating", "t"))
    dyadic(d$i, d$j, d$t, TRUE, "seconds", .unix, "UTC", "trust ratings from -10 to +10") },
  "snap-act-mooc" = function() { d <- .untar_read(.p("snap-act-mooc", "act-mooc.tar.gz"), "act-mooc/mooc_actions.tsv")
    dyadic(paste0("u", d$USERID), paste0("a", d$TARGETID), d$TIMESTAMP, TRUE, "seconds",
           note = "bipartite: users acting on course activities; seconds from course start") },
  "snap-cit-hepth" = function() {
    dates <- .tij(.p("snap-cit-hepth", "cit-HepTh-dates.txt.gz"), c("paper", "date"), skip = 1)
    cit <- .tij(.p("snap-cit-hepth", "cit-HepTh.txt.gz"), c("from", "to"), skip = 4)
    t <- as.numeric(as.Date(dates$date[match(cit$from, dates$paper)]))
    dyadic(cit$from, cit$to, t, TRUE, "days", note = "citation at the citing paper's submission date; days since 1970-01-01") },
  "snap-cit-hepph" = function() {
    dates <- .tij(.p("snap-cit-hepph", "cit-HepPh-dates.txt.gz"), c("paper", "date"), skip = 1)
    cit <- .tij(.p("snap-cit-hepph", "cit-HepPh.txt.gz"), c("from", "to"), skip = 4)
    t <- as.numeric(as.Date(dates$date[match(cit$from, dates$paper)]))
    dyadic(cit$from, cit$to, t, TRUE, "days", note = "citation at the citing paper's submission date; days since 1970-01-01") },
  "snap-wiki-rfa" = function() {
    x <- readLines(gzfile(.p("snap-wiki-rfa", list.files(.p("snap-wiki-rfa"), pattern = "gz$")[1])), warn = FALSE)
    src <- sub("^SRC:", "", x[startsWith(x, "SRC:")]); tgt <- sub("^TGT:", "", x[startsWith(x, "TGT:")])
    dat <- sub("^DAT:", "", x[startsWith(x, "DAT:")])
    t <- as.numeric(as.POSIXct(dat, format = "%H:%M, %d %B %Y", tz = "UTC"))
    dyadic(src, tgt, t, TRUE, "seconds", .unix, "UTC", "votes on requests for adminship; undated votes dropped") },
  # --- KONECT (licence unknown) ----------------------------------------------
  "konect-chess" = function() { d <- .konect(.p("konect-chess", "download.tsv.chess.tar.bz2"), "chess/out.chess")
    dyadic(d$V1, d$V2, d$V4, TRUE, "seconds", .unix, "UTC", "white -> black; result in the weight column") },
  "konect-haggle" = function() { d <- .konect(.p("konect-haggle", "download.tsv.contact.tar.bz2"), "contact/out.contact")
    dyadic(d$V1, d$V2, d$V4, FALSE, "seconds", note = "Bluetooth device contacts, Infocom 2005") },
  "konect-dutch-college" = function() { d <- .konect(.p("konect-dutch-college", "download.tsv.moreno_vdb.tar.bz2"), "moreno_vdb/out.moreno_vdb_vdb")
    dyadic(d$V1, d$V2, d$V4, TRUE, "seconds", .unix, "UTC", "seven survey waves; rating in the weight column") },
  # --- Network Repository (CC BY-SA) -------------------------------------------
  "nr-fb-forum" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("nr-fb-forum", "fb-forum.zip")), "fb-forum.edges"), header = FALSE)
    dyadic(d$V1, d$V2, d$V3, TRUE, "seconds", .unix, "UTC", "Facebook-like forum, 2004") },
  "nr-ia-enron-employees" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("nr-ia-enron-employees", "ia-enron-employees.zip")), "ia-enron-employees.edges"), header = FALSE)
    dyadic(d$V1, d$V2, d$V4, TRUE, "seconds", .unix, "America/Chicago", "Enron employees, 1999-2002") }
)

# --- other dyadic event data -------------------------------------------------
.xl_date <- function(x) as.Date(suppressWarnings(as.numeric(x)), origin = "1899-12-30")
.days <- function(d) as.numeric(as.Date(d))
readers2 <- list(
  "radoslaw-email-dataverse" = function() { d <- fread(.p("radoslaw-email-dataverse", "communication.csv"), sep = ";")
    dyadic(d$Sender, d$Recipient, as.numeric(as.POSIXct(d$EventDate, tz = "Europe/Warsaw")), TRUE, "seconds", .unix, "Europe/Warsaw",
           "the CC0 release of the manufacturing-company email bundled in amorem as radoslaw_email") },
  "copenhagen-networks-study" = function() { d <- fread(.p("copenhagen-networks-study", "calls.csv"))
    d <- d[callee >= 0]
    dyadic(d$caller, d$callee, d$timestamp, TRUE, "seconds",
           note = "phone calls; seconds from the start of the four-week study. The folder also holds SMS, Bluetooth proximity and Facebook friendships") },
  "covid-bucharest-transmission" = function() { x <- readxl::read_excel(.p("covid-bucharest-transmission", "replication_data_clean_version.xlsx"))
    t <- as.Date(substr(as.character(x$REFEREE_CONFIRMATION_DAY), 1, 10))   # full date; the MONTH column holds its month name
    dyadic(x$REFERRAL_CODE, x$REFEREE_CODE, .days(t), TRUE, "days",
           note = "referral (likely source) -> referee (case), at the referee's confirmation date in 2020; days since 1970-01-01") },
  "fourpcan-alter-nominations" = function() { d <- fread(.p("fourpcan-alter-nominations", "events.csv"))
    d <- d[source != target]
    dyadic(d$source, d$target, d$time, TRUE, "units", note = "alter nominations; time in the units of the release") },
  "alien-species-first-records-rem" = function() { d <- fread(.p("alien-species-first-records-rem", "species_data.csv"))
    d <- d[event == 1]
    dyadic(d$species, d$country, d$strt, TRUE, "years", note = "one-shot species -> country first records (risk = \"remove\"), start of the recording interval") },
  "alien-first-records-v4" = function() { d <- fread(.p("alien-first-records-v4", "FirstRecords_dataset_public_v4.0.csv"), sep = ";")
    t <- suppressWarnings(as.numeric(d$firstRecordEvent))
    dyadic(d$taxon, d$location, t, TRUE, "years", note = "one-shot taxon -> region first records; rows with a non-numeric year dropped") },
  "honeybee-trophallaxis-gernat2018" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("honeybee-trophallaxis-gernat2018", "trial1.zip"))))
    dyadic(d$id1, d$id2, d$begin / 1000, FALSE, "seconds", .unix, "America/Chicago", "trial 1 of 5: trophallaxis contacts, start times") },
  "goldfish-datasets" = function() { e <- new.env(); load(.p("goldfish-datasets", "Fisheries_Treaties_6070.RData"), envir = e)
    b <- e$bilatchanges; b <- b[b$increment > 0, ]
    dyadic(b$sender, b$receiver, as.numeric(b$time), FALSE, "seconds", .unix, "UTC",
           "bilateral fisheries treaties 1960-1970 (goldfish); the folder also holds the RFID validity study and Social Evolution") },
  "statnet-relevent-workshop" = function() { e <- new.env(); load(.p("statnet-relevent-workshop", "relevent_workshop.Rdata"), envir = e)
    w <- e$WTCPoliceCalls
    dyadic(w[[2]], w[[3]], w[[1]], TRUE, "seconds", note = "WTC police radio calls on 11 September 2001 (Butts 2008); time in seconds from the first call. Also holds a classroom log") },
  "eventnet-rhem-data" = function() { d <- fread(.p("eventnet-rhem-data", "apache_apache_events.csv"))
    d <- d[source != "system_dummy" & target != "system_dummy"]
    dyadic(d$source, d$target, as.numeric(as.POSIXct(d$time, tz = "UTC")), TRUE, "seconds", .unix, "UTC",
           "Apache developer communication (eventnet); also holds Enron, DGG and Les Miserables") },
  "networkdynamicdata-cran" = function() {
    e <- new.env(); f <- tempfile(fileext = ".rda")
    con <- pipe(paste("tar -xzOf", shQuote(.p("networkdynamicdata-cran", "networkDynamicData_0.3.0.tar.gz")), "networkDynamicData/data/harry_potter_support.rda"), "rb")
    raw <- readBin(con, "raw", 5e7); close(con); writeBin(raw, f); load(f, envir = e)
    s <- networkDynamic:::as.data.frame.networkDynamic(get(ls(e)[1], e))
    dyadic(s$tail, s$head, s$onset, TRUE, "books", note = "support nominations across the seven Harry Potter books (networkDynamicData)") },
  "gharchive-sample" = function() { x <- jsonlite::stream_in(gzfile(.p("gharchive-sample", "2015-01-01-15.json.gz")), verbose = FALSE)
    dyadic(x$actor$login, x$repo$name, as.numeric(as.POSIXct(x$created_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")), TRUE, "seconds", .unix, "UTC",
           "one hour of public GitHub events, user -> repository (bipartite)") },
  "gdelt" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("gdelt", "1979.zip"))), header = FALSE, sep = "\t", select = c(2, 8, 18), quote = "")
    setnames(d, c("date", "a1", "a2")); d <- d[a1 != "" & a2 != ""]
    dyadic(d$a1, d$a2, .days(as.Date(as.character(d$date), "%Y%m%d")), TRUE, "days", note = "1979 file: actor-1 country -> actor-2 country, CAMEO events") },
  "polecat" = function() { d <- fread(.p("polecat", "ngecEvents.DV.2024.txt"), sep = "\t", quote = "", select = c("Event Date", "Actor Country", "Recipient Country"))
    setnames(d, c("date", "a", "b")); d <- d[a != "None" & b != "None" & a != b]
    dyadic(d$a, d$b, .days(d$date), TRUE, "days", note = "2024 weekly files: actor country -> recipient country, PLOVER events") },
  "phoenix-cline" = function() { d <- fread(.p("phoenix-cline", "PhoenixNYT_1945-2005.csv"), select = c("story_date", "source_root", "target_root"))
    d <- d[source_root != "" & target_root != "" & source_root != target_root]
    dyadic(d$source_root, d$target_root, .days(as.Date(d$story_date, "%m/%d/%Y")), TRUE, "days", note = "source root actor -> target root actor (country codes), New York Times stories") },
  "ucdp" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("ucdp", "ucdp-dyadic-261-csv.zip"))))
    dyadic(d$side_a, d$side_b, d$year, TRUE, "years", note = "conflict dyad-years 1946-2025 (UCDP dyadic); one row per active dyad and year") },
  "atop" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("atop", "atop_5.1__.csv_.zip")), shQuote("ATOP 5.1 (.csv)/atop5_1dy.csv")))
    k <- intersect(c("stateA", "statea", "mem1"), names(d))[1]; l <- intersect(c("stateB", "stateb", "mem2"), names(d))[1]
    d <- d[order(get(k), get(l), year)]; first <- d[, .SD[1], by = c(k, l)]
    dyadic(first[[k]], first[[l]], first$year, FALSE, "years", note = "first year each state pair shares an alliance (ATOP dyad-years)") },
  "africa-mfa-visits" = function() { x <- readxl::read_excel(.p("africa-mfa-visits", "africa_mfa_2010_2022.xlsx"))
    out <- x$outgoing_incoming == "Outgoing"
    dyadic(ifelse(out, x$country_a, x$partner), ifelse(out, x$partner, x$country_a), .days(.xl_date(x$time)), TRUE, "days",
           note = "visitor country -> host country, foreign ministers") },
  "italy-diplomatic-visits" = function() { x <- readxl::read_excel(.p("italy-diplomatic-visits", "Dataset_Italy_diplomatic_visits_2000-2023.xlsx"))
    out <- x$Direction == "Outgoing"
    dyadic(ifelse(out, "Italy", x$Partner), ifelse(out, x$Partner, "Italy"), .days(as.Date(x$Date)), TRUE, "days", note = "visitor -> host") },
  "russia-ukraine-mfa-visits" = function() { x <- readxl::read_excel(.p("russia-ukraine-mfa-visits", "Russia and Ukraine MFAs 2021-2024.xlsx"))
    out <- x$Direction == "Outgoing"
    dyadic(ifelse(out, x$Country, x$`Partner Country`), ifelse(out, x$`Partner Country`, x$Country), .days(as.Date(x$Date)), TRUE, "days", note = "visitor -> host") },
  "us-leader-visits" = function() { a <- fread(.p("us-leader-visits", "foreign_leader_visits_20221102.tab"))
    b <- fread(.p("us-leader-visits", "president_travels_20221102.tab"))
    bc <- intersect(c("country_clean", "country"), names(b))[1]; bd <- intersect(c("start_date", "date"), names(b))[1]
    dyadic(c(a$country_clean, rep("United States", nrow(b))), c(rep("United States", nrow(a)), b[[bc]]),
           c(.days(a$start_date), .days(b[[bd]])), TRUE, "days", note = "foreign leaders visiting the US and US presidents travelling abroad") },
  "unhcr-refugees" = function() { e <- new.env(); f <- tempfile(fileext = ".rda")
    con <- pipe(paste("tar -xzOf", shQuote(.p("unhcr-refugees", "refugees_2025.12.2.tar.gz")), "refugees/data/population.rda"), "rb")
    raw <- readBin(con, "raw", 2e8); close(con); writeBin(raw, f); load(f, envir = e)
    x <- as.data.frame(get(ls(e)[1], e)); x <- x[!is.na(x$refugees) & x$refugees > 0 & x$coo_iso != x$coa_iso, ]
    dyadic(x$coo_iso, x$coa_iso, x$year, TRUE, "years", note = "origin -> asylum country-years with at least one refugee (UNHCR population statistics)") },
  "opensky-covid-flightlist-2020-04" = function() { d <- fread(cmd = paste("gzip -dc", shQuote(.p("opensky-covid-flightlist-2020-04", "flightlist_20200401_20200430.csv.gz"))), select = c("origin", "destination", "firstseen"))
    d <- d[origin != "" & destination != "" & origin != destination]
    dyadic(d$origin, d$destination, as.numeric(as.POSIXct(d$firstseen, tz = "UTC")), TRUE, "seconds", .unix, "UTC", "flights between airports, April 2020") },
  "tfl-cycle-hire-2026-02" = function() { fs <- list.files(.p("tfl-cycle-hire-2026-02"), pattern = "csv$", full.names = TRUE)
    d <- rbindlist(lapply(fs, fread, select = c("Start date", "Start station number", "End station number")))
    setnames(d, c("t", "a", "b")); d <- d[a != b]
    dyadic(d$a, d$b, as.numeric(as.POSIXct(d$t, format = "%Y-%m-%d %H:%M", tz = "Europe/London")), TRUE, "seconds", .unix, "Europe/London", "station -> station journeys, February 2026") },
  "lichess-2013-01" = function() { x <- system2("sh", c("-c", shQuote(paste("zstd -dc", shQuote(.p("lichess-2013-01", "lichess_db_standard_rated_2013-01.pgn.zst")), "| grep -E '^\\[(White|Black|UTCDate|UTCTime) '"))), stdout = TRUE)
    v <- sub('^\\[[A-Za-z]+ "(.*)"\\]$', "\\1", x); k <- sub("^\\[([A-Za-z]+) .*", "\\1", x)
    g <- cumsum(k == "White"); w <- tapply(v[k == "White"], g[k == "White"], `[`, 1)
    b <- tapply(v[k == "Black"], g[k == "Black"], `[`, 1); dd <- tapply(v[k == "UTCDate"], g[k == "UTCDate"], `[`, 1)
    tt <- tapply(v[k == "UTCTime"], g[k == "UTCTime"], `[`, 1)
    dyadic(w, b, as.numeric(as.POSIXct(paste(dd, tt), format = "%Y.%m.%d %H:%M:%S", tz = "UTC")), TRUE, "seconds", .unix, "UTC", "white -> black, rated standard games") },
  "international-football-results" = function() { d <- fread(.p("international-football-results", "results.csv"))
    dyadic(d$home_team, d$away_team, .days(d$date), TRUE, "days", note = "home -> away team, men's internationals since 1872") },
  "retrosheet-gamelogs" = function() { d <- fread(cmd = paste("unzip -p", shQuote(.p("retrosheet-gamelogs", "gl1871_2024.zip"))), header = FALSE, select = c(1, 4, 7), quote = "\"")
    dyadic(d$V4, d$V7, .days(as.Date(as.character(d$V1), "%Y%m%d")), TRUE, "days", note = "visiting -> home team, MLB games 1871-2024. The information used here was obtained free of charge from and is copyrighted by Retrosheet. Interested parties may contact Retrosheet at www.retrosheet.org.") },
  "kddcup2003-hepth" = function() {
    cit <- fread(cmd = paste("tar -xzOf", shQuote(.p("kddcup2003-hepth", "hep-th-citations.tar.gz"))), header = FALSE)
    dts <- fread(cmd = paste("tar -xzOf", shQuote(.p("kddcup2003-hepth", "hep-th-slacdates.tar.gz"))), header = FALSE)
    t <- .days(as.Date(dts$V2[match(cit$V1, dts$V1)]))
    dyadic(cit$V1, cit$V2, t, TRUE, "days", note = "citing -> cited paper at the citing paper's SLAC date") },
  "nber-patent-citations" = function() { cit <- fread(cmd = paste("unzip -p", shQuote(.p("nber-patent-citations", "acite75_99.zip"))))
    pat <- fread(cmd = paste("unzip -p", shQuote(.p("nber-patent-citations", "apat63_99.zip"))), select = c("PATENT", "GDATE"))
    t <- pat$GDATE[match(cit$CITING, pat$PATENT)]
    dyadic(cit$CITING, cit$CITED, t - 3653, TRUE, "days", note = "citing -> cited US patent at the citing patent's grant date (GDATE, days since 1960-01-01, shifted to 1970)") }
)
readers <- c(readers, readers2)

# --- hyperevents ---------------------------------------------------------------
hyper <- function(I, J, time, unit, origin = NULL, note = "") {
  ev <- data.frame(time = as.numeric(time)); ev$I <- I; ev$J <- J
  ev <- ev[!is.na(ev$time), ]
  list(kind = "hyper", events = ev, time_unit = unit, origin = origin, note = note)
}
.benson <- function(nverts, simplices, times) {
  nv <- scan(nverts, quiet = TRUE); sx <- scan(simplices, quiet = TRUE); tt <- scan(times, quiet = TRUE)
  split(as.character(sx), rep(seq_along(nv), nv)) -> sets
  list(sets = unname(sets), time = tt)
}
readers3 <- list(
  "enron-perry-wolfe" = function() {
    m <- fread(.p("enron-perry-wolfe", "messages.tsv"), header = FALSE, quote = "", sep = "\t")
    r <- fread(.p("enron-perry-wolfe", "recipients.tsv"), header = FALSE)
    J <- split(as.character(r$V3), r$V1)
    hyper(as.list(as.character(m$V5)), unname(J[as.character(m$V1)]), m$V3, "seconds", .unix,
          "one sender -> recipient set per message, Enron executives 1998-2002") },
  "benson-drive" = function() {
    a <- .p("benson-drive", "congress-bills-full.tar.gz"); td <- tempfile(); dir.create(td)
    utils::untar(a, exdir = td); b <- file.path(td, "congress-bills-full")
    x <- .benson(file.path(b, "congress-bills-full-nverts.txt"), file.path(b, "congress-bills-full-simplices.txt"),
                 file.path(b, "congress-bills-full-times.txt"))
    hyper(x$sets, replicate(length(x$sets), character(0), simplify = FALSE), x$time - 719529, "days",
          note = "sponsor and cosponsors of each US bill, 1973-2016 (Benson); times converted from MATLAB date numbers to days since 1970") },
  "benson-scholp" = function() { b <- .p("benson-scholp", "threads-math-sx")
    x <- .benson(gzfile(file.path(b, "threads-math-sx-nverts.txt.gz")), gzfile(file.path(b, "threads-math-sx-simplices.txt.gz")),
                 gzfile(file.path(b, "threads-math-sx-times.txt.gz")))
    hyper(x$sets, replicate(length(x$sets), character(0), simplify = FALSE), x$time / 1000, "seconds", .unix,
          "users taking part in each MathOverflow question thread (threads-math-sx); the folder holds 11 more ScHoLP datasets") },
  "xgi-data" = function() { d <- jsonlite::fromJSON(.p("xgi-data", "email-enron.json"), simplifyVector = FALSE)
    eid <- vapply(d$edges, function(e) as.character(e$edge), ""); ts <- vapply(d$edges, function(e) e$attrs$timestamp %||% NA_character_, "")
    inc <- do.call(rbind, lapply(d$incidences, function(x) data.frame(node = as.character(x$node), edge = as.character(x$edge))))
    sets <- split(inc$node, inc$edge)[eid]
    hyper(unname(sets), replicate(length(sets), character(0), simplify = FALSE),
          as.numeric(as.POSIXct(ts, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")), "seconds", .unix,
          "email-enron hypergraph (all participants of a message as one set); the folder also holds senate-bills and sfhh-conference") },
  "govinfo-billstatus-118" = function() {
    rows <- list()
    for (z in c("BILLSTATUS-118-hr.zip", "BILLSTATUS-118-s.zip")) {
      zf <- .p("govinfo-billstatus-118", z); td <- tempfile(); dir.create(td); utils::unzip(zf, exdir = td)
      for (f in list.files(td, pattern = "xml$", full.names = TRUE, recursive = TRUE)) {
        x <- xml2::read_xml(f)
        sp <- xml2::xml_text(xml2::xml_find_all(x, "/billStatus/bill/sponsors/item/bioguideId"))
        co <- xml2::xml_text(xml2::xml_find_all(x, "/billStatus/bill/cosponsors/item/bioguideId"))
        dt <- xml2::xml_text(xml2::xml_find_first(x, "/billStatus/bill/introducedDate"))
        rows[[length(rows) + 1]] <- list(I = sp, J = co, t = dt)
      }
    }
    hyper(lapply(rows, `[[`, "I"), lapply(rows, `[[`, "J"), as.numeric(as.Date(vapply(rows, `[[`, "", "t"))), "days",
          note = "sponsor -> cosponsors of each House and Senate bill of the 118th Congress (2023-2024)") },
  "openalex-social-networks-journal" = function() {
    ws <- unlist(lapply(list.files(.p("openalex-social-networks-journal"), pattern = "^works-page.*json$", full.names = TRUE),
                        function(f) jsonlite::fromJSON(f, simplifyVector = FALSE)$results), recursive = FALSE)
    hyper(lapply(ws, function(w) vapply(w$authorships, function(a) a$author$id %||% NA_character_, "")),
          lapply(ws, function(w) unlist(w$referenced_works) %||% character(0)),
          as.numeric(as.Date(vapply(ws, function(w) w$publication_date %||% NA_character_, ""))), "days",
          note = "author set -> set of cited works, articles of the journal Social Networks (OpenAlex)") }
)
readers <- c(readers, readers3)

# --- covariate series ----------------------------------------------------------
series <- function(time, values, unit, origin = NULL, note = "") {
  d <- data.frame(time = as.numeric(time), values, check.names = FALSE)
  list(kind = "series", events = d[!is.na(d$time), ], time_unit = unit, origin = origin, note = note)
}
.ghcnd <- function(f) { d <- fread(f)
  data.frame(date = as.Date(d$DATE), station = d$NAME[1], tmax = d$TMAX, tmin = d$TMIN, prcp = d$PRCP) }
readers4 <- list(
  "noaa-ghcnd-weather" = function() {
    d <- rbindlist(lapply(list.files(.p("noaa-ghcnd-weather"), pattern = "csv$", full.names = TRUE), .ghcnd))
    series(as.numeric(d$date), data.frame(station = d$station, tmax_c = d$tmax, tmin_c = d$tmin, prcp_mm = d$prcp), "days",
           note = "daily weather at Boston Logan (Sep-Dec 2008), Santa Ana (Apr-Oct 2004), Warsaw and Wroclaw (Jan-Oct 2010)") },
  "noaa-enso" = function() { d <- fread(.p("noaa-enso", "oni.ascii.txt"))
    m <- match(d$SEAS, c("DJF","JFM","FMA","MAM","AMJ","MJJ","JJA","JAS","ASO","SON","OND","NDJ"))
    series(d$YR + (m - 0.5) / 12, data.frame(oni = d$ANOM), "years", note = "Oceanic Nino Index, three-month running means since 1950") },
  "open-meteo-weather" = function() {
    d <- rbindlist(lapply(list.files(.p("open-meteo-weather"), pattern = "csv$", full.names = TRUE), function(f) {
      x <- fread(f, skip = 3); x$place <- sub("openmeteo_([a-z]+)_.*", "\\1", basename(f)); x }), fill = TRUE)
    series(as.numeric(as.Date(d$time)), data.frame(place = d$place, tmax_c = d[[grep("temperature_2m_max", names(d))]],
           tmin_c = d[[grep("temperature_2m_min", names(d))]], prcp_mm = d[[grep("precipitation_sum", names(d))]]), "days",
           note = "reanalysis-based daily weather for London (Feb 2026) and Warsaw (Jan-Oct 2010)") },
  "imgw-synop-daily-2010" = function() {
    d <- rbindlist(lapply(c("2010_375_s.zip", "2010_424_s.zip"), function(z) {
      zf <- .p("imgw-synop-daily-2010", z); m <- grep("^s_d_[0-9]", utils::unzip(zf, list = TRUE)$Name, value = TRUE)[1]
      fread(cmd = paste("unzip -p", shQuote(zf), m), header = FALSE, encoding = "Latin-1") }))
    series(as.numeric(as.Date(sprintf("%d-%02d-%02d", d$V3, d$V4, d$V5))),
           data.frame(station = d$V2, tmax_c = d$V6, tmin_c = d$V8, tmean_c = d$V10, prcp_mm = d$V14), "days",
           note = "IMGW synoptic daily records, Warsaw-Okecie (375) and Wroclaw (424), 2010; columns per s_d_format.txt") },
  "eia-oil-prices" = function() {
    a <- readxl::read_excel(.p("eia-oil-prices", "RBRTEd.xls"), sheet = 2, skip = 2)
    series(as.numeric(as.Date(a[[1]])), data.frame(brent_usd = as.numeric(a[[2]])), "days", note = "Brent spot price, US dollars per barrel, daily (EIA); WTI in the same folder") },
  "worldbank-pinksheet" = function() {
    a <- suppressMessages(readxl::read_excel(.p("worldbank-pinksheet", "CMO-Historical-Data-Monthly.xlsx"), sheet = "Monthly Prices", skip = 4))
    names(a)[1] <- "month"; a <- a[grepl("^[0-9]{4}M[0-9]{2}$", a$month), ]
    yr <- as.numeric(substr(a$month, 1, 4)) + (as.numeric(substr(a$month, 6, 7)) - 0.5) / 12
    keep <- intersect(c("Crude oil, average", "Coffee, Arabica", "Wheat, US HRW", "Copper", "Gold"), names(a))
    series(yr, as.data.frame(lapply(a[keep], as.numeric), check.names = FALSE), "years", note = "World Bank monthly commodity prices since 1960 (selected series)") },
  "nager-date-holidays" = function() {
    d <- rbindlist(lapply(list.files(.p("nager-date-holidays"), pattern = "json$", full.names = TRUE), function(f) {
      x <- jsonlite::fromJSON(f); data.frame(date = x$date, country = x$countryCode, name = x$name) }))
    series(as.numeric(as.Date(d$date)), data.frame(country = d$country, holiday = d$name), "days", note = "public holidays: PL 2010, US 2004/2008/2009, GB 2026") },
  "unga-ideal-points" = function() { d <- fread(.p("unga-ideal-points", "IdealpointestimatesFP_2026FP.csv"))
    series(d$year, data.frame(country = d$iso3c, ideal_point = d$IdealPointFP), "years", note = "UN General Assembly ideal points per country and session") },
  "unga-votes-1946-2013" = function() { d <- fread(.p("unga-votes-1946-2013", "un_rc_3.txt"), sep = ";", encoding = "Latin-1")
    series(d$year, data.frame(yes = d$yes_votes, no = d$no_votes, abstain = d$abstentions), "years", note = "UN General Assembly roll calls: yes, no and abstention counts per resolution") }
)
readers <- c(readers, readers4)
