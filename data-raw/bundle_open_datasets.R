# data-raw/bundle_open_datasets.R
# Builds the package datasets whose licences allow redistribution, from the
# files in data-raw/raw/ (downloaded 2026-10-17; sources, licences and
# checksums in data-raw/catalogue/licences.csv, vignettes/articles/data/catalogue/downloads.csv
# and each folder's SHA256SUMS). Run from the package root.

suppressPackageStartupMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
raw <- function(...) file.path("data-raw/raw", ...)
save_data <- function(...) {                                 # mark text as UTF-8 (CRAN: no unmarked non-ASCII)
  env <- parent.frame()
  for (nm in vapply(substitute(list(...))[-1], deparse, "")) {
    x <- get(nm, env)
    for (j in names(x)) if (is.character(x[[j]])) Encoding(x[[j]]) <- "UTF-8"
      else if (is.list(x[[j]])) x[[j]] <- lapply(x[[j]], function(v) { if (is.character(v)) Encoding(v) <- "UTF-8"; v })
    assign(nm, x, env)
  }
  eval(substitute(usethis::use_data(..., overwrite = TRUE, compress = "xz")), env)
}
days_from <- function(t, origin) as.numeric(difftime(t, origin, units = "days"))

# --- Manufacturing company email: CC0 1.0 (Harvard Dataverse doi:10.7910/DVN/6Z3CGX)
d <- fread(raw("radoslaw-email-dataverse", "communication.csv"), sep = ";", colClasses = list(character = "EventDate"))
ts <- as.POSIXct(d$EventDate, tz = "Europe/Warsaw")          # release: dates in local time
o <- min(ts)
radoslaw_email <- data.frame(time = days_from(ts, o), sender = as.character(d$Sender),
                             receiver = as.character(d$Recipient), weight = 1L)
radoslaw_email <- radoslaw_email[order(radoslaw_email$time), ]
rownames(radoslaw_email) <- NULL
attr(radoslaw_email, "unix_origin") <- as.numeric(o)
h <- fread(raw("radoslaw-email-dataverse", "reportsto.csv"), sep = ";")
radoslaw_hierarchy <- data.frame(id = as.character(h$ID), reports_to = as.character(h$ReportsToID))
save_data(radoslaw_email, radoslaw_hierarchy)

# --- Copenhagen Networks Study: MIT (Figshare doi:10.6084/m9.figshare.7267433)
cl <- fread(raw("copenhagen-networks-study", "calls.csv"))
copenhagen_calls <- data.frame(time = cl$timestamp / 86400, sender = as.character(cl$caller),
                               receiver = as.character(cl$callee), duration = cl$duration)
sm <- fread(raw("copenhagen-networks-study", "sms.csv"))
copenhagen_sms <- data.frame(time = sm$timestamp / 86400, sender = as.character(sm$sender),
                             receiver = as.character(sm$recipient))
gd <- fread(raw("copenhagen-networks-study", "genders.csv"))
setnames(gd, c("id", "female"))
copenhagen_actors <- data.frame(id = as.character(gd$id), female = as.integer(gd$female))
save_data(copenhagen_calls, copenhagen_sms, copenhagen_actors)

# --- US Congress, 118th: public domain (govinfo BILLSTATUS bulk data)
rows <- list(); members <- list()
for (z in c("BILLSTATUS-118-hr.zip", "BILLSTATUS-118-s.zip")) {
  td <- tempfile(); dir.create(td); utils::unzip(raw("govinfo-billstatus-118", z), exdir = td)
  for (f in list.files(td, pattern = "xml$", full.names = TRUE, recursive = TRUE)) {
    x <- xml2::read_xml(f); b <- xml2::xml_find_first(x, "/billStatus/bill")
    it <- function(path) xml2::xml_find_all(b, path)
    sp <- it("sponsors/item"); co <- it("cosponsors/item")
    for (m in c(sp, co)) members[[length(members) + 1]] <- data.frame(
      bioguide_id = xml2::xml_text(xml2::xml_find_first(m, "bioguideId")),
      name = xml2::xml_text(xml2::xml_find_first(m, "fullName")),
      party = xml2::xml_text(xml2::xml_find_first(m, "party")),
      state = xml2::xml_text(xml2::xml_find_first(m, "state")))
    if (!length(sp)) next
    rows[[length(rows) + 1]] <- list(
      bill = paste0(tolower(xml2::xml_text(xml2::xml_find_first(b, "type"))), xml2::xml_text(xml2::xml_find_first(b, "number"))),
      date = as.Date(xml2::xml_text(xml2::xml_find_first(b, "introducedDate"))),
      I = xml2::xml_text(xml2::xml_find_first(sp, "bioguideId")),
      J = xml2::xml_text(xml2::xml_find_first(co, "bioguideId")))
  }
}
dates <- as.Date(vapply(rows, function(r) as.character(r$date), ""))
ord <- order(dates)
congress_bills_118 <- hyperedge_log(I = lapply(rows[ord], `[[`, "I"),
                                    J = lapply(rows[ord], function(r) if (length(r$J)) r$J else character(0)),
                                    time = as.numeric(dates[ord] - as.Date("2023-01-03")))
congress_bills_118$bill <- vapply(rows[ord], `[[`, "", "bill")
congress_bills_118$date <- dates[ord]
congress_members_118 <- unique(do.call(rbind, members))
congress_members_118 <- congress_members_118[!duplicated(congress_members_118$bioguide_id), ]
congress_members_118 <- congress_members_118[order(congress_members_118$bioguide_id), ]
rownames(congress_members_118) <- NULL
save_data(congress_bills_118, congress_members_118)

# --- US leader-to-leader visits 1946-2019: CC0 1.0 (Harvard Dataverse doi:10.7910/DVN/2ZNR5R)
a <- fread(raw("us-leader-visits", "foreign_leader_visits_20221102.tab"))
p <- fread(raw("us-leader-visits", "president_travels_20221102.tab"))
# One name per country across the two tables. country_clean is missing ("NA") for
# microstates and a few trips; fall back to the raw name, then to the locale.
same_name <- c("Korea, Republic of" = "South Korea", "Zaire" = "Congo - Kinshasa", "Vatican City" = "Holy See",
               "St. Christopher and Nevis" = "St. Kitts and Nevis", "Saint Lucia" = "St. Lucia",
               "Western Samoa" = "Samoa", "Palestinian Authority" = "Palestine")
clean_country <- function(clean, raw, locale = NULL) {
  x <- ifelse(is.na(clean) | clean %in% c("", "NA"), raw, clean)
  if (!is.null(locale)) {
    x[(is.na(x) | x == "NA") & grepl("Geneva", locale)] <- "Switzerland"
    x[(is.na(x) | x == "NA") & grepl("Berlin|Aachen", locale)] <- "Germany"
    x[x %in% "Congo" & grepl("Kampala|Entebbe", locale)] <- "Uganda"   # 1998 trip: every locale is in Uganda
  }
  ifelse(x %in% names(same_name), same_name[x], x)
}
v <- rbind(data.frame(date = as.Date(a$start_date), sender = clean_country(a$country_clean, a$country),
                      receiver = "United States", direction = "to_us"),
           data.frame(date = as.Date(p$start_date), sender = "United States",
                      receiver = clean_country(p$country_clean, p$country, p$locale), direction = "from_us"))
v <- v[!is.na(v$date) & !is.na(v$receiver) & v$receiver != "", ]
v <- v[order(v$date), ]
us_leader_visits <- data.frame(time = days_from(v$date, min(v$date)), v, row.names = NULL)
save_data(us_leader_visits)

# --- UCDP dyadic conflict data v26.1: CC BY 4.0
u <- fread(cmd = paste("unzip -p", shQuote(raw("ucdp", "ucdp-dyadic-261-csv.zip"))))
ucdp_dyads <- data.frame(year = u$year, sender = u$side_a, receiver = u$side_b, dyad_id = u$dyad_id,
                         conflict_id = u$conflict_id, location = u$location,
                         intensity_level = u$intensity_level, type_of_conflict = u$type_of_conflict)
ucdp_dyads <- ucdp_dyads[order(ucdp_dyads$year, ucdp_dyads$dyad_id), ]
rownames(ucdp_dyads) <- NULL
save_data(ucdp_dyads)

# --- International football results: CC0 1.0 (github.com/martj42/international_results)
fb <- fread(raw("international-football-results", "results.csv"))
football_results <- data.frame(time = days_from(as.Date(fb$date), as.Date(min(fb$date))), date = as.Date(fb$date),
                               sender = fb$home_team, receiver = fb$away_team,
                               home_score = fb$home_score, away_score = fb$away_score,
                               tournament = fb$tournament, neutral = fb$neutral)
save_data(football_results)

# --- Alien species first records prepared for REMs: CC0 1.0 (Dryad doi:10.5061/dryad.x69p8czpv; files from the Zenodo mirror, record 8096819)
al <- fread(raw("alien-species-first-records-rem", "species_data.csv"))[event == 1]
alien_invasions <- data.frame(species = al$species, region = al$country, start = al$strt, stop = al$stp,
                              taxonomy = al$taxonomy)
alien_invasions <- alien_invasions[order(alien_invasions$stop, alien_invasions$species), ]   # record dated at stop
rownames(alien_invasions) <- NULL
save_data(alien_invasions)

# --- Risk table of the alien mammals, with the study's covariates (same CC0 source).
# One row per species, region and interval at risk; event = 1 at the first record.
# attr "never_at_risk": species-region pairs absent from the risk table (native
# range, or established before 1880); attr "entry": the year each species enters
# the risk set.
rk <- fread(raw("alien-species-first-records-rem", "species_data.csv"))
all_regions <- sort(unique(rk$country))
mm <- rk[taxonomy == "Mammals"]
alien_mammals <- data.frame(species = mm$species, region = mm$country, start = mm$strt, stop = mm$stp,
                            event = as.integer(mm$event), dist = signif(mm$dist, 6), num_inv = signif(mm$num_inv, 6),
                            trade = signif(mm$trade, 6), col = as.integer(mm$col), temp_dist = signif(mm$temp_dist, 6),
                            pasture = mm$pasture, urban = mm$urban, cropland = mm$cropland)
alien_mammals <- alien_mammals[order(alien_mammals$species, alien_mammals$region, alien_mammals$start), ]
rownames(alien_mammals) <- NULL
pairs <- CJ(sender = sort(unique(mm$species)), receiver = all_regions)
at_risk <- unique(mm[, .(sender = species, receiver = country)])
attr(alien_mammals, "never_at_risk") <- as.data.frame(pairs[!at_risk, on = .(sender, receiver)])
attr(alien_mammals, "entry") <- as.data.frame(mm[, .(entry = min(strt)), by = species][order(species)])
save_data(alien_mammals)

# --- Daily weather (NOAA GHCN-Daily, US Government work, public domain)
w <- rbindlist(lapply(list.files(raw("noaa-ghcnd-weather"), pattern = "csv$", full.names = TRUE), function(f) {
  x <- fread(f); data.table(station = x$STATION[1], name = x$NAME[1], date = as.Date(x$DATE),
                            tmax = x$TMAX, tmin = x$TMIN, prcp = x$PRCP) }))
daily_weather <- as.data.frame(w[order(station, date)])
save_data(daily_weather)

# --- Public holidays (dates and names are facts; retrieved from the Nager.Date API)
ph <- rbindlist(lapply(list.files(raw("nager-date-holidays"), pattern = "json$", full.names = TRUE), function(f) {
  x <- jsonlite::fromJSON(f); data.table(country = x$countryCode, date = as.Date(x$date), name = x$name,
                                          local_name = x$localName) }))
public_holidays <- as.data.frame(ph[order(country, date)])
save_data(public_holidays)

# --- Oceanic Nino Index (NOAA CPC, US Government work, public domain)
on <- fread(raw("noaa-enso", "oni.ascii.txt"))
oni <- data.frame(year = on$YR, season = on$SEAS, sst = on$TOTAL, anomaly = on$ANOM)
save_data(oni)
