#' Build / detect / convert hyperedge event logs
#'
#' A *hyperedge log* generalises the dyadic
#' `(sender, receiver, time)` event log used elsewhere in `amorem` to a
#' `(I, J, time)` event log where `I` and `J` are list-columns
#' containing the set of senders and the set of receivers participating
#' in each hyperevent. This matches the data model of Boschi, Lerner &
#' Wit (2025): each event is a time-stamped directed hyperedge
#' \eqn{(t_m, I_m, J_m)}{(t_m, I_m, J_m)} from a sender set to a
#' receiver set.
#'
#' The constructor [hyperedge_log()] accepts list-columns directly and
#' performs validation (character members, non-empty sets, finite
#' times, sorted by time). [as_hyperedge_log()] promotes a dyadic
#' `(sender, receiver, time)` data frame to the hyperedge form by
#' wrapping each `sender` and `receiver` in a length-1 character
#' vector. [as_dyadic_log()] is the inverse: it succeeds only when
#' every row of the hyperedge log has a length-1 sender set AND a
#' length-1 receiver set.
#'
#' For *undirected* hyperevents (e.g.\ multi-actor meetings), pass an
#' empty receiver set: `J = list(character(0), character(0), ...)`.
#' The receiver list-column must still be present.
#'
#' @param I List-column: each element is a character vector of sender
#'   actor names participating in that event. Length-1 vectors are
#'   allowed (and become standard dyadic events when combined with a
#'   length-1 `J`).
#' @param J List-column: each element is a character vector of receiver
#'   actor names. Empty character vectors are allowed and signal an
#'   *undirected* hyperevent.
#' @param time Numeric vector of event times. Must be finite and
#'   non-decreasing after sorting.
#' @param x A data frame or list-of-columns to test or convert.
#' @return A `data.frame` with columns `I`, `J`, `time`, additionally
#'   carrying class `amorem_hyperedge_log` to distinguish it from a
#'   dyadic log in dispatch contexts. Sorted by `time` ascending.
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
#' Time-Homogeneity: Relational Hyper Event Models with Time-Varying
#' Non-Linear Effects*. arXiv:2509.05289.
#' @examples
#' # Two co-authored citation events:
#' hl <- hyperedge_log(
#'   I    = list(c("alice", "bob"), c("alice", "carol")),
#'   J    = list(c("paperA"), c("paperA", "paperB")),
#'   time = c(1.0, 2.5))
#' is_hyperedge_log(hl)
#'
#' # Round-trip a dyadic log:
#' dy <- data.frame(sender = c("a", "b"),
#'                  receiver = c("b", "c"),
#'                  time = c(1, 2))
#' h <- as_hyperedge_log(dy)
#' as_dyadic_log(h)
#' @export
hyperedge_log <- function(I, J, time) {
  if (!is.list(I)) stop("`I` must be a list of character vectors.")
  if (!is.list(J)) stop("`J` must be a list of character vectors.")
  if (length(I) != length(J) || length(I) != length(time)) {
    stop("`I`, `J`, and `time` must all have the same length.")
  }
  if (!is.numeric(time) || !all(is.finite(time))) {
    stop("`time` must be a finite numeric vector.")
  }
  if (!all(vapply(I, function(v) is.character(v) && length(v) > 0L,
                  logical(1)))) {
    stop("Every element of `I` must be a non-empty character vector.")
  }
  if (!all(vapply(J, is.character, logical(1)))) {
    stop("Every element of `J` must be a character vector ",
         "(empty character(0) is allowed and means undirected).")
  }
  ord <- order(time)
  df <- data.frame(time = time[ord], stringsAsFactors = FALSE)
  df$I <- I[ord]
  df$J <- J[ord]
  df <- df[, c("I", "J", "time"), drop = FALSE]
  class(df) <- c("amorem_hyperedge_log", "data.frame")
  df
}

#' @rdname hyperedge_log
#' @export
is_hyperedge_log <- function(x) {
  inherits(x, "amorem_hyperedge_log") ||
    (is.data.frame(x) &&
     all(c("I", "J", "time") %in% names(x)) &&
     is.list(x$I) && is.list(x$J))
}

#' @rdname hyperedge_log
#' @param event_log A dyadic event log with `sender`, `receiver`, `time`
#'   columns.
#' @export
as_hyperedge_log <- function(event_log) {
  if (is_hyperedge_log(event_log)) return(event_log)
  required <- c("sender", "receiver", "time")
  missing <- setdiff(required, names(event_log))
  if (length(missing)) {
    stop("Cannot convert to a hyperedge log: missing column(s) ",
         paste(missing, collapse = ", "), ".")
  }
  hyperedge_log(I    = as.list(as.character(event_log$sender)),
                J    = as.list(as.character(event_log$receiver)),
                time = event_log$time)
}

#' @rdname hyperedge_log
#' @param hyperedge_log A hyperedge log produced by [hyperedge_log()] or
#'   [as_hyperedge_log()].
#' @export
as_dyadic_log <- function(hyperedge_log) {
  if (!is_hyperedge_log(hyperedge_log)) {
    stop("`hyperedge_log` is not a hyperedge log.")
  }
  size_I <- vapply(hyperedge_log$I, length, integer(1))
  size_J <- vapply(hyperedge_log$J, length, integer(1))
  if (any(size_I != 1L) || any(size_J != 1L)) {
    stop("Cannot convert to a dyadic log: ",
         sum(size_I != 1L | size_J != 1L),
         " event(s) have non-singleton sender or receiver sets.")
  }
  data.frame(
    sender   = vapply(hyperedge_log$I, `[[`, character(1), 1L),
    receiver = vapply(hyperedge_log$J, `[[`, character(1), 1L),
    time     = hyperedge_log$time,
    stringsAsFactors = FALSE)
}

#' Cardinality columns for a hyperedge event log
#'
#' Adds two integer columns to a hyperedge log: `size_I` (the number
#' of senders) and `size_J` (the number of receivers). Convenient
#' shortcut for filtering / case-control sampling matched on
#' cardinality (see Boschi et al. 2025, Section 3.3).
#'
#' @param hyperedge_log A hyperedge log.
#' @return The hyperedge log with two added integer columns.
#' @export
hyperedge_sizes <- function(hyperedge_log) {
  if (!is_hyperedge_log(hyperedge_log)) {
    stop("`hyperedge_log` is not a hyperedge log.")
  }
  hyperedge_log$size_I <- vapply(hyperedge_log$I, length, integer(1))
  hyperedge_log$size_J <- vapply(hyperedge_log$J, length, integer(1))
  hyperedge_log
}
