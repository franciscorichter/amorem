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
"dist_matrix"

#' Classroom interaction events (McFarland 2001)
#'
#' Time-stamped directed interactions among 20 individuals in a single
#' US high-school class session, recorded on 16 October 1996 by Daniel
#' McFarland. The same data appear in the `networkDynamic` R package as
#' `McFarland_cls33_10_16_96`; this is a tidy event-table form.
#'
#' @format A data frame with 691 rows and 5 columns:
#' \describe{
#'   \item{time}{Minutes since the start of the class period.}
#'   \item{sender}{Character actor id matching [classroom_actors]`$id`.}
#'   \item{receiver}{Character actor id matching [classroom_actors]`$id`.}
#'   \item{interaction_type}{Factor with levels `"social"`, `"sanction"`,
#'     `"task"`.}
#'   \item{weight}{Integer weight of the interaction.}
#' }
#' @source McFarland, D. (2001). Student resistance: How the formal and
#'   informal organization of classrooms facilitate everyday forms of
#'   student defiance. *American Journal of Sociology* 107(3), 612–678.
#'   \doi{10.1086/338779}. Redistributed via the `networkDynamic` R
#'   package (CRAN), dataset `McFarland_cls33_10_16_96`.
#' @seealso [classroom_actors]
"classroom_events"

#' Classroom actor attributes (McFarland 2001)
#'
#' Per-actor covariates for the [classroom_events] event stream.
#'
#' @format A data frame with 20 rows and 3 columns:
#' \describe{
#'   \item{id}{Character actor id matching the `sender`/`receiver` columns
#'     of [classroom_events].}
#'   \item{sex}{Factor `"F"` / `"M"` — biological sex.}
#'   \item{role}{Factor with levels `"instructor"`, `"grade_11"`,
#'     `"grade_12"`.}
#' }
#' @source McFarland (2001), via `networkDynamic`. See [classroom_events].
"classroom_actors"

#' Phone calls in the Social Evolution study (Madan et al. 2011)
#'
#' Time-stamped directed phone calls among undergraduates in an MIT
#' residence hall over the 2008–2009 academic year. Sourced from the
#' `goldfish` R package (`Social_Evolution$calls`).
#'
#' @format A data frame with 439 rows and 4 columns:
#' \describe{
#'   \item{time}{Days since the first recorded call.
#'     `attr(., "unix_origin")` holds the Unix epoch of `time = 0`.}
#'   \item{sender}{Character actor id matching
#'     [social_evolution_actors]`$id`.}
#'   \item{receiver}{Same domain as `sender`.}
#'   \item{increment}{Integer increment recorded for the call (typically 1).}
#' }
#' @source Madan, A., Cebrian, M., Moturu, S., Farrahi, K. (2011).
#'   Sensing the "health state" of a community. *IEEE Pervasive
#'   Computing* 11(1), 36–45. \doi{10.1109/MPRV.2011.79}. Redistributed
#'   via the `goldfish` R package (github.com/snlab-ch/goldfish),
#'   dataset `Social_Evolution`.
#' @seealso [social_evolution_actors], [social_evolution_friendship]
"social_evolution_calls"

#' Actor attributes for the Social Evolution study
#'
#' Per-actor covariates for [social_evolution_calls] and
#' [social_evolution_friendship].
#'
#' @format A data frame with 84 rows and 4 columns:
#' \describe{
#'   \item{id}{Character actor id (`"Actor 1"`, `"Actor 2"`, …).}
#'   \item{present}{Logical — whether the actor was present at the start
#'     of the study window.}
#'   \item{floor}{Integer dormitory floor.}
#'   \item{gradeType}{Factor — student grade type (freshman, sophomore,
#'     junior, senior, graduate-tutor).}
#' }
#' @source Madan et al. (2011), via `goldfish`. See
#'   [social_evolution_calls].
"social_evolution_actors"

#' Friendship-survey events for the Social Evolution study
#'
#' Self-reported friendship ties recorded at survey waves throughout the
#' Social Evolution study.
#'
#' @format A data frame with 766 rows and 4 columns:
#' \describe{
#'   \item{time}{Days since the first recorded call (same origin as
#'     [social_evolution_calls]). `attr(., "unix_origin")` holds the
#'     Unix epoch of `time = 0`.}
#'   \item{sender}{Character actor id (the survey respondent).}
#'   \item{receiver}{Character actor id (the nominated friend).}
#'   \item{replace}{Integer — `1` adds the tie, `0` removes it.}
#' }
#' @source Madan et al. (2011), via `goldfish`.
#' @seealso [social_evolution_calls], [social_evolution_actors]
"social_evolution_friendship"

#' Manufacturing-company email events (Michalski et al. 2014)
#'
#' Time-stamped directed emails among employees of a mid-sized
#' manufacturing company over a nine-month period. Sourced from Network
#' Repository as the `ia-radoslaw-email` dataset.
#'
#' @format A data frame with 82,927 rows and 4 columns:
#' \describe{
#'   \item{time}{Days since the first email.
#'     `attr(., "unix_origin")` holds the Unix epoch of `time = 0`.}
#'   \item{sender}{Character employee id.}
#'   \item{receiver}{Character employee id.}
#'   \item{weight}{Integer — `1` for every record in the original file.}
#' }
#' @source Michalski, R., Palus, S., Kazienko, P. (2014). Seed selection
#'   for spread of influence in social networks: Temporal vs. static
#'   approach. *New Generation Computing* 32(3–4), 213–235.
#'   \doi{10.1007/s00354-014-0402-9}. Distributed via
#'   <https://networkrepository.com/ia-radoslaw-email.php>.
"radoslaw_email"

#' CollegeMsg: private messages on a university online community
#'
#' Directed time-stamped instant messages between students of the
#' University of California, Irvine over 193 days in 2004. Each row
#' is one message. Sourced from the SNAP repository.
#'
#' @format A data frame with 59,835 rows and 3 columns:
#' \describe{
#'   \item{time}{Days since the first message.
#'     `attr(., "unix_origin")` holds the Unix epoch of `time = 0`.}
#'   \item{sender}{Character user id.}
#'   \item{receiver}{Character user id.}
#' }
#' @source Panzarasa, P., Opsahl, T., Carley, K. (2009). Patterns and
#'   dynamics of users' behavior and interaction: Network analysis of
#'   an online community. *Journal of the American Society for
#'   Information Science and Technology* 60(5), 911–932.
#'   Distributed via SNAP:
#'   <https://snap.stanford.edu/data/CollegeMsg.html>.
"college_msg"

#' Email-Eu-Core temporal (single-department subset)
#'
#' Internal emails between members of a single department of a large
#' European research institution over ~803 days. The dataset has been
#' filtered to remove self-loops. Sourced from the SNAP repository as a
#' single-department slice of the email-Eu-core-temporal dataset.
#'
#' @format A data frame with 12,216 rows and 3 columns:
#' \describe{
#'   \item{time}{Days since the first email in the recording window.}
#'   \item{sender}{Character employee id (anonymised).}
#'   \item{receiver}{Character employee id (anonymised).}
#' }
#' @source Paranjape, A., Benson, A.R., Leskovec, J. (2017). Motifs in
#'   temporal networks. *WSDM '17*, 601–610.
#'   \doi{10.1145/3018661.3018731}. Distributed via SNAP:
#'   <https://snap.stanford.edu/data/email-Eu-core-temporal.html>.
"email_eu_core"
