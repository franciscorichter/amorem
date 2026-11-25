#' Download an event log that amorem does not redistribute
#'
#' Seven of the data sets used in the package articles and in the amorem paper
#' come from sources that state no licence for the data, so the package does not
#' ship them. `fetch_dataset()` downloads the file from its original source, checks
#' its MD5 sum, builds the same tidy table that earlier versions bundled, caches it
#' and returns it.
#'
#' @param name One of `"classroom_events"`, `"classroom_actors"`,
#'   `"social_evolution_calls"`, `"social_evolution_actors"`,
#'   `"social_evolution_friendship"`, `"college_msg"`, `"email_eu_core"`.
#' @param cache_dir Folder for the downloaded file and the built table. The
#'   default, `tools::R_user_dir("amorem", "cache")`, keeps them between
#'   sessions; pass `tempdir()` to keep nothing.
#' @param refresh If `TRUE`, download and build again even when a cached copy
#'   exists.
#' @param quiet If `TRUE`, download without progress messages.
#'
#' @return A data frame, the same object as the data set of that name in
#'   \pkg{amorem} 1.2.0.
#'
#' @section Data sets:
#' \describe{
#'   \item{`classroom_events`, `classroom_actors`}{691 directed interactions among
#'     20 people in one US high-school class period on 16 October 1996
#'     (McFarland 2001), and the actors' sex and role. Columns of the events:
#'     `time` (minutes since the start of the period), `sender`, `receiver`,
#'     `interaction_type` (factor: social, sanction, task) and `weight` (1 for
#'     communication directed at particular others, 501 rows; 0.2 for broadcast
#'     communication such as lecturing, 190 rows). Rows are in time order, ties
#'     by sender and then receiver. Columns of the actors: `id`, `sex` (F, M),
#'     `role` (instructor, grade_11, grade_12). Source: McFarland, D. (2001).
#'     Student resistance: How the formal and informal organization of
#'     classrooms facilitate everyday forms of student defiance. *American
#'     Journal of Sociology* 107(3), 612--678, \doi{10.1086/338779}; downloaded
#'     from the \pkg{networkDynamic} repository
#'     (<https://github.com/statnet/networkDynamic>, object
#'     `McFarland_cls33_10_16_96`). No licence is stated for the data.}
#'   \item{`social_evolution_calls`, `social_evolution_actors`,
#'     `social_evolution_friendship`}{439 phone calls among 84 undergraduates of
#'     an MIT residence hall, 6 September to 18 October 2008, with the actors'
#'     attributes (`id`, `present`, `floor`, `gradeType`) and 766 friendship
#'     survey events (`replace` is 1 when a tie is added, 0 when it is removed).
#'     `time` is in days since the first call; `attr(., "unix_origin")` holds the
#'     Unix time of `time = 0`. Source: Madan, A., Cebrian, M., Moturu, S.,
#'     Farrahi, K., Pentland, A. (2012). Sensing the "health state" of a
#'     community. *IEEE Pervasive Computing* 11(4), 36--45,
#'     \doi{10.1109/MPRV.2011.79}; downloaded from the \pkg{goldfish} repository
#'     (<https://github.com/stocnet/goldfish>, object `Social_Evolution`). No
#'     licence is stated for the data, and the original MIT Reality Commons
#'     release asks users not to redistribute them and not to attempt to
#'     re-identify participants.}
#'   \item{`college_msg`}{59,835 private messages between students of the
#'     University of California, Irvine over 193 days in 2004. `time` is in days
#'     since the first message; `attr(., "unix_origin")` holds its date-time.
#'     Source: Panzarasa, P., Opsahl, T., Carley, K. (2009). Patterns and
#'     dynamics of users' behavior and interaction: Network analysis of an
#'     online community. *Journal of the American Society for Information
#'     Science and Technology* 60(5), 911--932; downloaded from SNAP,
#'     <https://snap.stanford.edu/data/CollegeMsg.html>. No licence is stated;
#'     SNAP asks users to cite the source.}
#'   \item{`email_eu_core`}{12,216 e-mails between the members of one department
#'     of a European research institution over 803 days, self-addressed e-mails
#'     removed. `time` is in days. Source: Paranjape, A., Benson, A. R.,
#'     Leskovec, J. (2017). Motifs in temporal networks. *WSDM '17*, 601--610,
#'     \doi{10.1145/3018661.3018731}; downloaded from SNAP, file
#'     `email-Eu-core-temporal-Dept3.txt.gz` of
#'     <https://snap.stanford.edu/data/email-Eu-core-temporal.html>. No licence
#'     is stated; SNAP asks users to cite the source.}
#' }
#'
#' @aliases classroom_events classroom_actors social_evolution_calls
#'   social_evolution_actors social_evolution_friendship college_msg
#'   email_eu_core
#' @examples
#' \donttest{
#' # needs an internet connection the first time
#' ev <- tryCatch(fetch_dataset("classroom_events", cache_dir = tempdir()),
#'                error = function(e) NULL)
#' if (!is.null(ev)) head(ev)
#' }
#' @export
fetch_dataset <- function(name, cache_dir = tools::R_user_dir("amorem", "cache"),
                          refresh = FALSE, quiet = TRUE) {
  src <- .fetch_sources()
  name <- match.arg(name, names(src$objects))
  key <- src$objects[[name]]
  spec <- src$files[[key$file]]
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  built <- file.path(cache_dir, paste0(name, ".rds"))
  if (!refresh && file.exists(built)) return(readRDS(built))

  raw <- file.path(cache_dir, basename(spec$url))
  if (refresh || !file.exists(raw) || unname(tools::md5sum(raw)) != spec$md5) {
    tmp <- tempfile(fileext = paste0(".", tools::file_ext(raw)))
    on.exit(unlink(tmp), add = TRUE)
    ok <- tryCatch(utils::download.file(spec$url, tmp, mode = "wb", quiet = quiet),
                   error = function(e) e, warning = function(w) w)
    if (!identical(ok, 0L))
      stop("could not download ", spec$url,
           if (inherits(ok, "condition")) paste0(": ", conditionMessage(ok)),
           call. = FALSE)
    if (unname(tools::md5sum(tmp)) != spec$md5)
      stop("the file at ", spec$url, " is not the one amorem was built against ",
           "(MD5 differs); the source may have changed", call. = FALSE)
    file.copy(tmp, raw, overwrite = TRUE)
  }
  out <- key$build(raw)
  saveRDS(out, built)
  out
}

.fetch_sources <- function() {
  files <- list(
    classroom = list(
      url = paste0("https://raw.githubusercontent.com/statnet/networkDynamic/",
                   "76cd961b1b02b1aba7f35859266e5c382cc4712f/data/",
                   "McFarland_cls33_10_16_96.rda"),
      md5 = "a31ffff42cae4d7da51a9fec28a2affe"),
    social_evolution = list(
      url = paste0("https://raw.githubusercontent.com/stocnet/goldfish/",
                   "91a05f81de790702719181ef9d0e875e2b0686a7/data/",
                   "Social_Evolution.RData"),
      md5 = "38991f467cbb24c93b86bb0bc7b06fae"),
    college_msg = list(
      url = "https://snap.stanford.edu/data/CollegeMsg.txt.gz",
      md5 = "1095bbb6fceb596fb70b3fc680414bfd"),
    email_eu_core = list(
      url = "https://snap.stanford.edu/data/email-Eu-core-temporal-Dept3.txt.gz",
      md5 = "5c3aa2359d88524dc412190e89981297"))
  objects <- list(
    classroom_events = list(file = "classroom", build = function(f) .build_classroom(f)$events),
    classroom_actors = list(file = "classroom", build = function(f) .build_classroom(f)$actors),
    social_evolution_calls = list(file = "social_evolution",
                                  build = function(f) .build_social_evolution(f)$calls),
    social_evolution_actors = list(file = "social_evolution",
                                   build = function(f) .build_social_evolution(f)$actors),
    social_evolution_friendship = list(file = "social_evolution",
                                       build = function(f) .build_social_evolution(f)$friendship),
    college_msg = list(file = "college_msg", build = .build_college_msg),
    email_eu_core = list(file = "email_eu_core", build = .build_email_eu_core))
  list(files = files, objects = objects)
}

# The networkDynamic object is read as the plain list it is stored as, so
# neither network nor networkDynamic is needed.
.build_classroom <- function(file) {
  e <- new.env()
  load(file, envir = e)
  x <- unclass(e$cls33_10_16_96)
  rows <- lapply(x$mel, function(m) {
    if (is.null(m)) return(NULL)
    sp <- m$atl$active
    w  <- m$atl$weight.active
    ty <- m$atl$interaction_type.active
    data.frame(from = m$outl, to = m$inl, time = sp[, 1],
               weight = unlist(w[[1]])[match(sp[, 1], w[[2]][, 1])],
               type = unlist(ty[[1]])[match(sp[, 1], ty[[2]][, 1])])
  })
  r <- do.call(rbind, rows)
  r <- r[order(r$time, r$from, r$to), ]
  events <- data.frame(
    time             = r$time,
    sender           = as.character(r$from),
    receiver         = as.character(r$to),
    interaction_type = factor(r$type, levels = c("social", "sanction", "task")),
    weight           = r$weight,
    stringsAsFactors = FALSE)
  rownames(events) <- NULL
  v <- x$val
  actors <- data.frame(
    id   = vapply(v, function(a) as.character(a$vertex.names), ""),
    sex  = factor(vapply(v, function(a) a$gender, ""), levels = c("F", "M")),
    role = factor(vapply(v, function(a) a$type, ""),
                  levels = c("instructor", "grade_11", "grade_12")),
    stringsAsFactors = FALSE)
  list(events = events, actors = actors)
}

.build_social_evolution <- function(file) {
  env <- new.env()
  load(file, envir = env)
  a <- env$actors; ca <- env$calls; fr <- env$friendship
  actors <- data.frame(
    id        = as.character(a$label),
    present   = as.logical(a$present),
    floor     = as.integer(a$floor),
    gradeType = factor(a$gradeType, levels = sort(unique(a$gradeType))),
    stringsAsFactors = FALSE)
  calls <- data.frame(
    time      = as.numeric(ca$time),
    sender    = as.character(ca$sender),
    receiver  = as.character(ca$receiver),
    increment = as.integer(ca$increment),
    stringsAsFactors = FALSE)
  calls <- calls[order(calls$time), ]
  rownames(calls) <- NULL
  friendship <- data.frame(
    time     = as.numeric(fr$time),
    sender   = as.character(fr$sender),
    receiver = as.character(fr$receiver),
    replace  = as.integer(fr$replace),
    stringsAsFactors = FALSE)
  friendship <- friendship[order(friendship$time), ]
  rownames(friendship) <- NULL
  origin <- min(calls$time)
  attr(calls, "unix_origin") <- origin
  attr(friendship, "unix_origin") <- origin
  calls$time <- (calls$time - origin) / 86400
  friendship$time <- (friendship$time - origin) / 86400
  list(calls = calls, actors = actors, friendship = friendship)
}

.build_college_msg <- function(file) {
  r <- utils::read.table(file, col.names = c("sender", "receiver", "unix_time"))
  r <- r[order(r$unix_time), ]
  origin <- min(r$unix_time)
  out <- data.frame(time = (r$unix_time - origin) / 86400,
                    sender = as.character(r$sender),
                    receiver = as.character(r$receiver),
                    stringsAsFactors = FALSE)
  attr(out, "unix_origin") <- as.POSIXct(origin, origin = "1970-01-01", tz = "UTC")
  attr(out, "time_unit") <- "days"
  out
}

.build_email_eu_core <- function(file) {
  r <- utils::read.table(file, col.names = c("sender", "receiver", "secs_since"))
  r <- r[order(r$secs_since), ]
  r <- r[r$sender != r$receiver, ]
  out <- data.frame(time = r$secs_since / 86400,
                    sender = as.character(r$sender),
                    receiver = as.character(r$receiver),
                    stringsAsFactors = FALSE)
  attr(out, "time_unit") <- "days"
  attr(out, "note") <- "Subset: Department 3 of email-Eu-core (Paranjape et al. 2017)"
  out
}
