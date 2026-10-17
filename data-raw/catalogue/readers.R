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
