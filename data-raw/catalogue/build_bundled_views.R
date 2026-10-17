# Views (network, timeline, close-up, pairs) of the event logs bundled in amorem,
# for vignettes/articles/datasets.Rmd: Rscript data-raw/catalogue/build_bundled_views.R
suppressPackageStartupMessages(devtools::load_all("~/System/Research/REM", quiet = TRUE))
source("~/System/Research/REM/data-raw/catalogue/readers.R")
source("~/System/Research/REM/data-raw/catalogue/view.R")
out <- path.expand("~/System/Research/REM/vignettes/articles/data/bundled")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
org <- function(x) as.POSIXct(attr(x, "unix_origin"), origin = "1970-01-01", tz = "UTC")
cm <- amorem::congress_members_118
cname <- function(id) { lab <- sub(" \\[.*", "", sub("^(Rep|Sen)\\. ", "", cm$name))
  lab <- paste0(sub(",.*", "", lab), " (", cm$party, "-", cm$state, ")"); o <- lab[match(id, cm$bioguide_id)]; ifelse(is.na(o), id, o) }
objs <- list(
  classroom_events = dyadic(classroom_events$sender, classroom_events$receiver, classroom_events$time * 60, TRUE, "seconds"),
  social_evolution_calls = dyadic(social_evolution_calls$sender, social_evolution_calls$receiver, social_evolution_calls$time, TRUE, "days",
                                  origin = if (!is.null(attr(social_evolution_calls, "unix_origin"))) org(social_evolution_calls)),
  radoslaw_email = dyadic(radoslaw_email$sender, radoslaw_email$receiver, radoslaw_email$time, TRUE, "days", origin = org(radoslaw_email), tz = "Europe/Warsaw"),
  college_msg = dyadic(college_msg$sender, college_msg$receiver, college_msg$time, TRUE, "days", origin = org(college_msg), tz = "America/Los_Angeles"),
  email_eu_core = dyadic(email_eu_core$sender, email_eu_core$receiver, email_eu_core$time, TRUE, "days"),
  copenhagen_calls = dyadic(copenhagen_calls$sender, copenhagen_calls$receiver, copenhagen_calls$time, TRUE, "days"),
  copenhagen_sms = dyadic(copenhagen_sms$sender, copenhagen_sms$receiver, copenhagen_sms$time, TRUE, "days"),
  us_leader_visits = dyadic(us_leader_visits$sender, us_leader_visits$receiver, as.numeric(us_leader_visits$date), TRUE, "days"),
  football_results = dyadic(football_results$sender, football_results$receiver, as.numeric(football_results$date), FALSE, "days"),
  ucdp_dyads = dyadic(ucdp_dyads$sender, ucdp_dyads$receiver, ucdp_dyads$year, FALSE, "years"),
  alien_invasions = dyadic(alien_invasions$species, alien_invasions$region, alien_invasions$stop, TRUE, "years"),
  congress_bills_118 = hyper(lapply(congress_bills_118$I, cname), lapply(congress_bills_118$J, cname),
                             as.numeric(congress_bills_118$date), "days"))
# email_eu_core and the Copenhagen logs have no calendar date; their times are days from the start
objs$email_eu_core$time_unit <- objs$copenhagen_calls$time_unit <- objs$copenhagen_sms$time_unit <- "days from start"
for (nm in names(objs)) {
  o <- objs[[nm]]
  v <- if (o$kind == "hyper") view_hyper(o) else view_dyadic(o)
  saveRDS(list(kind = o$kind, directed = isTRUE(o$directed), time_unit = o$time_unit, origin = o$origin, tz = o$tz, view = v),
          file.path(out, paste0(nm, ".rds")), compress = "xz")
  cat(nm, "ok\n")
}
