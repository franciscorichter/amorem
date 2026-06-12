#' Convert a long case-control event log to wide case-1-control format
#'
#' Reshapes a long case-(k-)control dataset -- one row per case and per control,
#' with a 0/1 case indicator -- into a wide **case-1-control** table with one row
#' per case. For each covariate the event value (`<cov>_ev`), the matched
#' control value (`<cov>_nv`) and their difference (`d_<cov>`, event minus
#' control) are emitted, ready for the `gam` backend of [rem()].
#'
#' This is the preprocessing companion to [rem()] for eventnet-style output,
#' where a case row is followed by its controls and the stratum id is left blank
#' on control rows.
#'
#' @param data A long case-control data.frame.
#' @param case Optional name of the 0/1 event-indicator column. If `NULL`
#'   (default), it is auto-detected from the package's `event` column (as
#'   produced by [sample_non_events()]) or eventnet's `IS_OBSERVED`, preferring
#'   `event` when both are present.
#' @param stratum Optional name of the column grouping each case with its
#'   controls. When `NULL`, the stratum is derived as `cumsum(case == 1)`
#'   (assuming each case is immediately followed by its controls).
#' @param covariates Character vector of covariate columns to widen. When
#'   `NULL`, all numeric columns are used except the case indicator, the
#'   stratum, and the standard eventnet bookkeeping columns (`EVENT`,
#'   `INTEGER_TIME`, `TIME_POINT`, `TIME_UNIT`, `EVENT_INTERVAL`).
#' @param control_index Which control within each stratum to pair with the case
#'   (default the first). Lets a case-k-control log be reduced to case-1-control.
#'
#' @return A data.frame with one row per case: a `stratum` column and, for each
#'   covariate, `<cov>_ev`, `<cov>_nv` and `d_<cov>`. Strata without exactly one
#'   case or without the requested control are dropped (with a message).
#'
#' @seealso [rem()], [simulate_relational_events()] (`wide = TRUE`).
#'
#' @examples
#' set.seed(1)
#' long <- data.frame(
#'   IS_OBSERVED = rep(c(1, 0, 0), 4),
#'   x = rnorm(12), y = rnorm(12))
#' widen_case_control(long, control_index = 1)
#'
#' @export
widen_case_control <- function(data, case = NULL, stratum = NULL,
                               covariates = NULL, control_index = 1L) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  # Resolve the 0/1 indicator column: explicit `case`, else auto-detect the
  # package (`event`, from sample_non_events()) or eventnet (`IS_OBSERVED`)
  # convention, preferring `event` when both are present.
  if (is.null(case)) {
    cand <- intersect(c("event", "IS_OBSERVED"), names(data))
    if (!length(cand)) {
      stop("Could not find a 0/1 event-indicator column (looked for `event` ",
           "and `IS_OBSERVED`). Pass `case` explicitly.")
    }
    case <- cand[1L]
  }
  ci <- data[[case]]
  if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
  ci <- as.integer(ci)
  strat <- .derive_stratum(data, case, stratum)

  if (is.null(covariates)) {
    book <- c(case, stratum, "EVENT", "INTEGER_TIME", "TIME_POINT",
              "TIME_UNIT", "EVENT_INTERVAL", "EVENT_INTERVAL_ID")
    num <- names(data)[vapply(data, is.numeric, logical(1))]
    covariates <- setdiff(num, book)
  }
  if (!length(covariates)) stop("No covariate columns to widen.")
  miss <- setdiff(covariates, names(data))
  if (length(miss)) stop("Covariate column(s) not found: ", paste(miss, collapse = ", "))

  idx <- split(seq_len(nrow(data)), strat)
  dropped <- 0L
  rows <- lapply(idx, function(ix) {
    cs <- ix[ci[ix] == 1L]
    ct <- ix[ci[ix] == 0L]
    if (length(cs) != 1L || length(ct) < control_index) {
      dropped <<- dropped + 1L
      return(NULL)
    }
    ctrl <- ct[control_index]
    base <- data.frame(stratum = strat[cs], stringsAsFactors = FALSE)
    for (v in covariates) {
      ev <- as.numeric(data[[v]][cs])
      nv <- as.numeric(data[[v]][ctrl])
      base[[paste0(v, "_ev")]] <- ev
      base[[paste0(v, "_nv")]] <- nv
      base[[paste0("d_", v)]]  <- ev - nv
    }
    base
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) stop("No usable strata (need exactly one case and at least ",
                          control_index, " control per stratum).")
  if (dropped > 0L) {
    message("widen_case_control: dropped ", dropped,
            " stratum/strata without exactly one case and >= ",
            control_index, " control(s).")
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
