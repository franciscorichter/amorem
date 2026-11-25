#' Simulated event log used in the examples
#'
#' 600 directed events among 20 actors (`a01` to `a20`), drawn by
#' [simulate_relational_events()] with the Gillespie algorithm, a baseline rate
#' of 1 per dyad, and effects 1.5 of `reciprocity_binary` and 0.8 of
#' `transitivity_binary`. `data-raw/simulated_events.R` in the source repository
#' draws it.
#'
#' @format A data frame with 600 rows and 3 columns: `time`, `sender`,
#'   `receiver`.
#' @source Simulated; part of \pkg{amorem} (MIT licence).
#' @seealso [fetch_dataset()] for the classroom, Social Evolution, CollegeMsg and
#'   Email-Eu-core logs, which the package downloads instead of shipping.
"simulated_events"

#' US state distance matrix
#'
#' A 56 × 56 matrix of pairwise geographic distances (in metres) between
#' US states and territories, computed from boundary geometries via
#' \code{sf::st_distance}.
#'
#' @format A numeric matrix with 56 rows and 56 columns.
#'   Row and column names are state/territory names.
#' @source Computed from US Census TIGER/Line shapefiles using the
#'   \pkg{tigris}, \pkg{sf}, and \pkg{geosphere} packages.
#'   See Walker (2024), Pebesma (2018), Hijmans (2022).
#'   TIGER/Line files are a US government work in the public domain.
"dist_matrix"

#' Manufacturing-company email events (Nurek & Michalski 2020)
#'
#' Time-stamped directed emails among the 167 employees of a mid-sized
#' manufacturing company in Poland, January to September 2010. Each recipient
#' of an email (To, CC or BCC) is a separate row. The data are the CC0 release
#' of Nurek & Michalski (2020); [radoslaw_hierarchy] gives who reports to whom.
#'
#' @format A data frame with 82,927 rows and 4 columns:
#' \describe{
#'   \item{time}{Days since the first email. `attr(., "unix_origin")` holds the
#'     Unix time of `time = 0`; the release records local (Europe/Warsaw) time.}
#'   \item{sender}{Character employee id, as in [radoslaw_hierarchy].}
#'   \item{receiver}{Character employee id.}
#'   \item{weight}{Integer, `1` for every record.}
#' }
#' @details 51 rows are emails an employee sent to themself.
#' @source Nurek M, Michalski R (2020). Manufacturing company email metadata and
#'   corporate hierarchy. Harvard Dataverse, \doi{10.7910/DVN/6Z3CGX}, licence
#'   CC0 1.0. Cite: Nurek M, Michalski R (2020). Combining machine learning and
#'   social network analysis to reveal the organizational structures.
#'   *Applied Sciences* 10(5), 1699, \doi{10.3390/app10051699}; and Michalski R,
#'   Palus S, Kazienko P (2011). Matching organizational structure and social
#'   network extracted from email communication. *Lecture Notes in Business
#'   Information Processing* 87, 197--206.
"radoslaw_email"

#' Reporting hierarchy of the manufacturing company (Nurek & Michalski 2020)
#'
#' Who reports to whom among the employees of [radoslaw_email]. Employee 86 is
#' the chief executive and reports to themself.
#'
#' @format A data frame with 167 rows and 2 columns:
#' \describe{
#'   \item{id}{Character employee id, as in [radoslaw_email].}
#'   \item{reports_to}{Character id of the employee's manager.}
#' }
#' @source Harvard Dataverse, \doi{10.7910/DVN/6Z3CGX}, licence CC0 1.0.
"radoslaw_hierarchy"

#' Reconstructed Niño3.4 ENSO index, 1301--2005 (Li et al. 2013)
#'
#' Annual reconstruction of the El Niño/Southern Oscillation from 2,222
#' tree-ring chronologies across Asia, New Zealand and the Americas. Each value
#' is the November--January Niño3.4 sea-surface temperature anomaly of the
#' winter that ends in January of `year`. A global covariate on a yearly clock:
#' it takes one value at each time for every dyad, so its effect on a
#' relational event process is identified only through time-shifted
#' case-control sampling, [sample_non_events()] with `shift = "exponential"`.
#'
#' @format A data frame with 705 rows and 2 columns:
#' \describe{
#'   \item{year}{Integer year CE, 1301--2005.}
#'   \item{nino34}{Reconstructed November--January Niño3.4 sea-surface
#'     temperature anomaly (°C), relative to the 1971--2000 observed mean.
#'     The file gives no uncertainty for the reconstruction.}
#' }
#' @details To use it as a piecewise-constant covariate in
#'   [simulate_relational_events()], pass
#'   `data.frame(time_start = enso_nino34$year, nino34 = enso_nino34$nino34)`
#'   as `global_covariates`, which holds each winter's value through the
#'   calendar year that it opens. For event data after 1950, NOAA's
#'   instrumental Oceanic Niño Index (monthly) is the better covariate.
#'   The raw file is shipped as
#'   `system.file("extdata", "enso_nino34", "enso-li2013.txt", package = "amorem")`;
#'   `data-raw/enso_nino34.R` in the source repository rebuilds this object.
#' @source NOAA National Centers for Environmental Information, World Data
#'   Service for Paleoclimatology, study 14632,
#'   \url{https://www.ncei.noaa.gov/access/paleo-search/study/14632},
#'   \doi{10.25921/jfqm-9178}; file `enso-li2013.txt`, accessed 2026-10-16.
#'   NCEI states that all data products of its Paleoclimatology Product Area
#'   are publicly available without restriction.
#' @references
#' Li J, Xie S-P, Cook ER, Morales MS, Christie DA, Johnson NC, Chen F,
#' D'Arrigo R, Fowler AM, Gou X, Fang K (2013). El Niño modulations over the
#' past seven centuries. *Nature Climate Change* 3, 822--826.
#' \doi{10.1038/nclimate1936}.
#' @examples
#' data(enso_nino34)
#' plot(enso_nino34$year, enso_nino34$nino34, type = "l",
#'      xlab = "year", ylab = "Niño3.4 anomaly (°C)")
"enso_nino34"


#' Copenhagen Networks Study: phone calls, text messages and gender
#'
#' Phone calls and text messages among students of the Technical University of
#' Denmark over four weeks, from the Copenhagen Networks Study (Sapiezynski et
#' al. 2019). `copenhagen_actors` records each participant's gender.
#'
#' @format `copenhagen_calls`: 3,600 rows, `time` (days since the start of the
#'   study period), `sender` (caller), `receiver` (callee), `duration` (seconds;
#'   `-1` for missed calls in the release). `copenhagen_sms`: 24,333 rows,
#'   `time`, `sender`, `receiver`. `copenhagen_actors`: 787 rows, `id`,
#'   `female` (1 = female).
#' @source Sapiezynski P, Stopczynski A, Lassen DD, Lehmann S (2019).
#'   Interaction data from the Copenhagen Networks Study. *Scientific Data* 6,
#'   315, \doi{10.1038/s41597-019-0325-x}. Data: Figshare,
#'   \doi{10.6084/m9.figshare.7267433}, MIT licence.
#' @name copenhagen
#' @aliases copenhagen_calls copenhagen_sms copenhagen_actors
NULL

#' @rdname copenhagen
"copenhagen_calls"

#' @rdname copenhagen
"copenhagen_sms"

#' @rdname copenhagen
"copenhagen_actors"

#' Bills of the 118th US Congress as hyperevents
#'
#' Every House and Senate bill introduced in the 118th Congress (January 2023
#' to January 2025) as a directed hyperevent: the sponsor sends the bill, the
#' cosponsors receive it. An [hyperedge_log()] with the bill number and the
#' introduction date; [congress_members_118] gives party and state.
#'
#' @format An `amorem_hyperedge_log` with 16,213 rows: `I` (list of one sponsor
#'   bioguide id), `J` (list of cosponsor bioguide ids, possibly empty), `time`
#'   (days since 3 January 2023), `bill` (e.g. `"hr184"`), `date` (introduced).
#' @source US Government Publishing Office, BILLSTATUS bulk data for the 118th
#'   Congress, <https://www.govinfo.gov/bulkdata/BILLSTATUS>, accessed
#'   2026-10-17. A work of the US Government, public domain (17 U.S.C. 105).
"congress_bills_118"

#' Members of the 118th US Congress
#'
#' Sponsors and cosponsors appearing in [congress_bills_118].
#'
#' @format A data frame with 553 rows: `bioguide_id`, `name` (as printed in the
#'   bill status), `party`, `state`.
#' @source As [congress_bills_118]; public domain.
"congress_members_118"

#' US leader-to-leader visits, 1945--2019
#'
#' Visits of foreign heads of state or government to the United States, and
#' travels of US presidents abroad, as directed visitor-to-host events.
#'
#' @format A data frame with 3,945 rows: `time` (days since the first visit),
#'   `date`, `sender` (visiting country), `receiver` (host country),
#'   `direction` (`"to_us"` or `"from_us"`).
#' @details Country names follow the visits table's cleaned names. Where that
#'   name is missing (microstates and a few presidential trips) the raw name is
#'   used, or the country of the listed locales; the two source tables' spellings
#'   are merged ("Korea, Republic of" is South Korea, "Zaire" is
#'   Congo - Kinshasa). A 1998 presidential trip labelled Congo whose locales are
#'   all in Uganda is coded as Uganda. See `data-raw/bundle_open_datasets.R`.
#' @source US Leader-to-Leader Diplomatic Visits Dataset, 1946--2019. Harvard
#'   Dataverse, \doi{10.7910/DVN/2ZNR5R}, licence CC0 1.0.
"us_leader_visits"

#' UCDP dyadic conflict data, 1946--2025
#'
#' One row per year in which a pair of actors (governments, rebel groups) was in
#' armed conflict with at least 25 battle-related deaths, from the UCDP Dyadic
#' Dataset version 26.1.
#'
#' @format A data frame with 3,518 rows: `year`, `sender` (side A), `receiver`
#'   (side B), `dyad_id`, `conflict_id`, `location`, `intensity_level`
#'   (1 = 25 to 999 deaths, 2 = 1,000 or more), `type_of_conflict` (1
#'   extrasystemic, 2 interstate, 3 intrastate, 4 internationalised intrastate).
#' @source Uppsala Conflict Data Program, <https://ucdp.uu.se/downloads/>,
#'   licence CC BY 4.0. Cite: Harbom L, Melander E, Wallensteen P (2008). Dyadic
#'   dimensions of armed conflict, 1946--2007. *Journal of Peace Research*
#'   45(5), 697--710, \doi{10.1177/0022343308094331}; and Davies S, Pettersson T,
#'   Öberg M (2025). Organized violence 1989--2024. *Journal of Peace Research*.
"ucdp_dyads"

#' Men's international football results since 1872
#'
#' Every men's full international match: the home team as sender, the away team
#' as receiver.
#'
#' @format A data frame with 49,945 rows: `time` (days since 30 November 1872),
#'   `date`, `sender` (home team), `receiver` (away team), `home_score`,
#'   `away_score`, `tournament`, `neutral` (`TRUE` when played at a neutral
#'   venue).
#' @source Jürisoo M. International football results from 1872 to present,
#'   <https://github.com/martj42/international_results>, licence CC0 1.0,
#'   accessed 2026-10-17.
"football_results"

#' Alien species first records, prepared for relational event models
#'
#' First records of established alien species (mammals, birds, plants, insects)
#' in 259 regions, 1880--2005, as one-shot species-to-region events: each pair
#' fires at most once (`risk = "remove"`). The first record is dated `stop`;
#' `start` is the start of the last interval over which the pair was at risk
#' with unchanged covariates in the counting-process release.
#'
#' @format A data frame with 11,730 rows, ordered by `stop`: `species`,
#'   `region`, `start`, `stop` (years), `taxonomy`. `start` equals `stop` in
#'   421 rows: the 14 records of 1880 and 407 later records whose last
#'   at-risk interval in the release begins in the year of the record.
#' @details The release also holds every censored species-region-interval with
#'   distance, trade, colonial, climate and land-use covariates (535,020 rows);
#'   download it from the source to fit the full model.
#' @source Juozaitienė R, Seebens H, Latombe G, Essl F, Wit EC (2023).
#'   Analysing ecological dynamics with relational event models: the case of
#'   biological invasions. *Diversity and Distributions* 29, 1208--1225,
#'   \doi{10.1111/ddi.13752}. Data: Dryad \doi{10.5061/dryad.x69p8czpv}
#'   (CC0 1.0).
"alien_invasions"

#' Alien mammals: risk table with covariates (Juozaitienė et al. 2023)
#'
#' The first records of 112 alien mammal species in the regions of the
#' FirstRecords database, 1880--2005, as a risk table: one row per species,
#' region and time interval during which the pair was at risk, with the
#' covariates of Juozaitienė et al. (2023). A pair leaves the table after its
#' first record (`event = 1`).
#'
#' @format A data frame with 24,584 rows and 13 columns:
#' \describe{
#'   \item{species, region}{The pair.}
#'   \item{start, stop}{Years delimiting the interval; a first record is dated at `stop`.}
#'   \item{event}{1 when the interval ends with the first record, 0 otherwise.}
#'   \item{dist}{Distance (km) from the region to the nearest region the
#'     species has already invaded by `stop`.}
#'   \item{num_inv}{Weighted number of earlier invasions in the region.}
#'   \item{trade}{Sum of annual trade flows (current US dollars) between the
#'     region and the regions the species has invaded; `NA` when not recorded.}
#'   \item{col}{1 if the species is present in a region of the same colonial area.}
#'   \item{temp_dist}{Smallest absolute temperature difference (degrees C)
#'     between the region and the regions already invaded.}
#'   \item{pasture, urban, cropland}{Shares of land use in the region.}
#' }
#' @details Two attributes describe the risk set. `attr(x, "never_at_risk")`
#'   is a data frame (`sender`, `receiver`) of the species--region pairs that
#'   never appear in the table (native range, or established before 1880), to
#'   pass to `sample_non_events(exclude_pairs = )`. `attr(x, "entry")` gives,
#'   for each species, the year from which it is at risk, to pass to
#'   `sample_non_events(entry = )`.
#' @source Juozaitienė R, Seebens H, Latombe G, Essl F, Wit EC (2023).
#'   Analysing ecological dynamics with relational event models: the case of
#'   biological invasions. *Diversity and Distributions* 29(10), 1208--1225,
#'   \doi{10.1111/ddi.13752}. Data: Dryad \doi{10.5061/dryad.x69p8czpv}
#'   (CC0 1.0).
#' @seealso [alien_invasions] for the first records of all taxa.
"alien_mammals"

#' Daily weather at the places and periods of the bundled event logs
#'
#' Daily maximum and minimum temperature and precipitation from NOAA GHCN-Daily
#' for Boston Logan (September--December 2008, Social Evolution), Santa Ana
#' John Wayne airport (April--October 2004, CollegeMsg), and Warsaw-Okecie and
#' Wroclaw-Strachowice (January--October 2010, manufacturing email).
#'
#' @format A data frame with 944 rows: `station`, `name`, `date`, `tmax` and
#'   `tmin` (degrees Celsius), `prcp` (millimetres). Missing values are `NA`.
#' @source NOAA National Centers for Environmental Information, Global
#'   Historical Climatology Network Daily, <https://www.ncei.noaa.gov/>,
#'   accessed 2026-10-17. A work of the US Government, public domain.
"daily_weather"

#' Public holidays for the periods of the bundled event logs
#'
#' Public holidays in Poland (2010), the United States (2004, 2008, 2009) and
#' Great Britain (2026).
#'
#' @format A data frame with 75 rows: `country` (ISO code), `date`, `name`,
#'   `local_name`.
#' @source Nager.Date public holiday API, <https://nagerholidays.com/>, accessed
#'   2026-10-17. Holiday dates and names are facts.
"public_holidays"

#' Oceanic Niño Index, 1950--present
#'
#' Three-month running mean of the Niño 3.4 sea-surface temperature anomaly, the
#' NOAA measure of El Niño and La Niña. The instrumental counterpart of the
#' reconstruction in [enso_nino34].
#'
#' @format A data frame with 920 rows: `year`, `season` (three-month window,
#'   e.g. `"DJF"`), `sst` (degrees Celsius), `anomaly` (degrees Celsius).
#' @source NOAA Climate Prediction Center,
#'   <https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt>, accessed
#'   2026-10-17. A work of the US Government, public domain.
"oni"
