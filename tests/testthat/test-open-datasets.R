# The datasets bundled from openly licensed sources (data-raw/bundle_open_datasets.R).

test_that("radoslaw_email is the CC0 release with its hierarchy", {
  data(radoslaw_email, envir = environment()); data(radoslaw_hierarchy, envir = environment())
  expect_equal(nrow(radoslaw_email), 82927L)
  expect_false(is.unsorted(radoslaw_email$time))
  expect_true(all(c(radoslaw_email$sender, radoslaw_email$receiver) %in% radoslaw_hierarchy$id))
  expect_equal(radoslaw_hierarchy$reports_to[radoslaw_hierarchy$id == "86"], "86")
  o <- as.POSIXct(attr(radoslaw_email, "unix_origin"), origin = "1970-01-01", tz = "Europe/Warsaw")
  expect_equal(format(o, "%Y-%m-%d %H:%M:%S"), "2010-01-02 17:40:10")
})

test_that("Copenhagen tables share one actor universe", {
  data(copenhagen_calls, envir = environment()); data(copenhagen_sms, envir = environment())
  data(copenhagen_actors, envir = environment())
  expect_named(copenhagen_calls, c("time", "sender", "receiver", "duration"))
  expect_named(copenhagen_sms, c("time", "sender", "receiver"))
  expect_true(all(copenhagen_actors$female %in% 0:1))
  expect_lt(max(copenhagen_calls$time, copenhagen_sms$time), 29)
})

test_that("congress_bills_118 is a hyperedge log with one sponsor per bill", {
  data(congress_bills_118, envir = environment()); data(congress_members_118, envir = environment())
  expect_true(is_hyperedge_log(congress_bills_118))
  expect_true(all(lengths(congress_bills_118$I) == 1L))
  expect_lte(max(lengths(congress_bills_118$J)), 435L)
  expect_true(all(unlist(congress_bills_118$I) %in% congress_members_118$bioguide_id))
  expect_false(is.unsorted(congress_bills_118$time))
})

test_that("event tables have sender, receiver and ordered time", {
  for (nm in c("us_leader_visits", "football_results")) {
    e <- new.env(); data(list = nm, envir = e); x <- get(nm, e)
    expect_true(all(c("time", "sender", "receiver") %in% names(x)), info = nm)
    expect_false(is.unsorted(x$time), info = nm)
    expect_gte(min(x$time), 0)
  }
  data(us_leader_visits, envir = environment())
  countries <- c(us_leader_visits$sender, us_leader_visits$receiver)
  expect_false(any(is.na(countries) | countries %in% c("", "NA")))
  expect_false(any(c("Korea, Republic of", "Zaire", "Vatican City") %in% countries))
  data(ucdp_dyads, envir = environment())
  expect_true(all(ucdp_dyads$intensity_level %in% 1:2))
  data(alien_invasions, envir = environment())
  expect_false(anyDuplicated(paste(alien_invasions$species, alien_invasions$region)) > 0)
  expect_true(all(alien_invasions$start <= alien_invasions$stop))
  expect_false(is.unsorted(alien_invasions$stop))
})

test_that("covariate tables cover the bundled logs' periods", {
  data(daily_weather, envir = environment()); data(public_holidays, envir = environment()); data(oni, envir = environment())
  expect_true(all(c("USW00014739", "USW00093184", "PLM00012375", "PLM00012424") %in% daily_weather$station))
  expect_true(all(c("PL", "US") %in% public_holidays$country))
  expect_equal(min(oni$year), 1950)
})

test_that("alien_mammals is a risk table with its risk-set attributes", {
  data(alien_mammals, envir = environment())
  x <- alien_mammals
  expect_equal(sum(x$event), 676L)
  expect_true(all(x$start <= x$stop))
  ex <- attr(x, "never_at_risk")
  expect_named(ex, c("sender", "receiver"))
  expect_false(any(paste(ex$sender, ex$receiver) %in% paste(x$species, x$region)))
  ent <- attr(x, "entry")
  expect_true(all(x$start >= ent$entry[match(x$species, ent$species)]))
})

