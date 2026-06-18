#' Endogenous features for a hyperedge event log
#'
#' Hyperedge analogue of [endogenous_features()]. Accepts a
#' hyperedge log (see [hyperedge_log()]) and computes hyperedge-native
#' statistics, falling back to the dyadic engine for stat names that
#' belong to the standard dyadic endogenous catalogue.
#'
#' Recognised hyperedge stat names:
#'
#' \describe{
#'   \item{\code{"subrep_<rho>_<l>"}}{Directed subset repetition (paper eq. 4).
#'     \code{rho} = sender-side subset cardinality (1..|I|),
#'     \code{l} = receiver-side subset cardinality (0..|J|, 0 = ignore receivers).
#'     Examples: \code{"subrep_1_1"} (average activity over single-actor sub-pairs),
#'     \code{"subrep_2_1"} (over pair-of-senders × single-receiver subpairs).}
#'   \item{\code{"subrep_<rho>"}}{Undirected subset repetition. Equivalent to
#'     \code{"subrep_<rho>_0"}; counts past events whose participant set is a
#'     superset of the chosen subset, with no receiver-side restriction.}
#'   \item{\code{"activity"}}{Counts past events whose participant set covers
#'     the focal event's entire \code{(I, J)} pair. Equivalent to
#'     \code{"subrep_<|I|>_<|J|>"}.}
#' }
#'
#' For dyadic-shaped events (every row has \code{|I| = |J| = 1}) and a
#' dyadic stat name, this function delegates to
#' [endogenous_features()] via [as_dyadic_log()].
#'
#' @param hyperedge_log A hyperedge log (see [hyperedge_log()]).
#' @param stats Character vector of statistic names. Mix of hyperedge-
#'   native names listed above and the dyadic catalogue names accepted
#'   by [endogenous_features()].
#' @param half_life Required when an exp-decay statistic is requested
#'   (only applies to delegated dyadic stats; hyperedge subrep does not
#'   use a half-life).
#' @return The hyperedge log with one added column per requested stat.
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
#' Time-Homogeneity: Relational Hyper Event Models with Time-Varying
#' Non-Linear Effects*. arXiv:2509.05289.
#' @seealso [hyperedge_subrep()], [hyperedge_activity()],
#'   [endogenous_features()].
#' @examples
#' hl <- hyperedge_log(
#'   I    = list(c("a","b"), c("a","c"), c("b","c"), c("a","b","c")),
#'   J    = list(c("X"),     c("X","Y"), c("Y"),     c("X")),
#'   time = c(1, 2, 3, 4))
#' hyperedge_features(hl,
#'   stats = c("subrep_1_1", "subrep_2_1", "activity"))
#' @export
hyperedge_features <- function(hyperedge_log, stats,
                                        half_life = NULL) {
  if (!is_hyperedge_log(hyperedge_log)) {
    stop("`hyperedge_log` is not a hyperedge log.")
  }
  if (!is.character(stats) || !length(stats)) {
    stop("`stats` must be a non-empty character vector.")
  }

  # Classify each stat as hyperedge-native (subrep family / activity) or
  # forwarded to the dyadic engine (the dyadic endogenous catalogue).
  classify <- function(s) {
    if (identical(s, "activity"))                       return("activity")
    if (grepl("^subrep_[0-9]+(_[0-9]+)?$", s))          return("subrep")
    return("dyadic")
  }
  kinds <- vapply(stats, classify, character(1))
  hyper_stats <- stats[kinds %in% c("subrep", "activity")]
  dyad_stats  <- stats[kinds == "dyadic"]

  out <- hyperedge_log
  n <- nrow(out)

  # Hyperedge-native: subrep family + activity.
  if (length(hyper_stats)) {
    for (s in hyper_stats) {
      if (identical(s, "activity")) {
        col <- numeric(n)
        for (i in seq_len(n)) {
          col[i] <- hyperedge_activity(hyperedge_log,
                                        I = hyperedge_log$I[[i]],
                                        J = hyperedge_log$J[[i]],
                                        t = hyperedge_log$time[i])
        }
        out[[s]] <- col
      } else {
        # subrep_<rho>_<l> or subrep_<rho>
        parts <- strsplit(s, "_", fixed = TRUE)[[1]][-1]
        rho <- as.integer(parts[1])
        l   <- if (length(parts) == 2L) as.integer(parts[2]) else 0L
        col <- numeric(n)
        for (i in seq_len(n)) {
          Iv <- hyperedge_log$I[[i]]
          Jv <- hyperedge_log$J[[i]]
          if (rho > length(Iv) || l > length(Jv)) {
            col[i] <- NA_real_
            next
          }
          col[i] <- hyperedge_subrep(hyperedge_log, I = Iv, J = Jv,
                                      t = hyperedge_log$time[i],
                                      rho = rho, l = l)
        }
        out[[s]] <- col
      }
    }
  }

  # Dyadic forwarded stats: only meaningful when every row is dyadic.
  if (length(dyad_stats)) {
    sizes_I <- vapply(hyperedge_log$I, length, integer(1))
    sizes_J <- vapply(hyperedge_log$J, length, integer(1))
    if (any(sizes_I != 1L) || any(sizes_J != 1L)) {
      stop("Cannot compute dyadic stat(s) ",
           paste(sQuote(dyad_stats), collapse = ", "),
           " on a non-dyadic hyperedge log. ",
           "Affected rows: ",
           sum(sizes_I != 1L | sizes_J != 1L), ".")
    }
    dy <- as_dyadic_log(hyperedge_log)
    dy_feat <- endogenous_features(dy, stats = dyad_stats,
                                            half_life = half_life)
    for (s in dyad_stats) out[[s]] <- dy_feat[[s]]
  }

  out
}
