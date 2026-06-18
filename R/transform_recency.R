#' Recency transform of inter-event time gaps
#'
#' Maps non-negative time gaps \eqn{\delta}{delta} to bounded recency
#' weights via
#' \deqn{
#'   w(\delta) \;=\; \exp\!\Bigl(-\frac{\delta}{2\,m}\Bigr),
#' }{
#'   w(delta) = exp(-delta / (2 * m)),
#' }
#' where \eqn{m}{m} is the median of the supplied (or reference) gaps.
#' Large gaps map toward 0; gaps near 0 map toward 1. The half-life of
#' the kernel is \eqn{2 m \log 2}{2 * m * log(2)}, so the median gap
#' itself is mapped to approximately
#' \eqn{e^{-1/2} \approx 0.607}{exp(-1/2) ~ 0.607}.
#'
#' This is the data-driven recency parametrisation used as a preprocessing
#' step for global and exogenous covariates in
#' Lembo, Juozaitiene, Vinciotti & Wit (2025) and matches the
#' "recency" axis of [endogenous_features()].
#'
#' @param delta Numeric vector of non-negative time gaps. NAs propagate.
#' @param half_life Optional positive scalar. If supplied, used directly
#'   as the kernel scale \eqn{2 m}{2 m}, bypassing the median rule.
#' @param reference Optional numeric vector. If supplied, the median is
#'   computed on `reference` instead of `delta`. Useful when transforming
#'   new data using a scale fitted on training data.
#' @return Numeric vector the same length as `delta`, with values in
#'   `(0, 1]`. NAs in `delta` are preserved.
#' @references
#' Lembo M, Juozaitiene R, Vinciotti V, Wit EC (2025). *Relational
#' Event Models with Global Covariates*. JRSS-C.
#' @examples
#' set.seed(1)
#' gaps <- rexp(20, rate = 0.5)
#' transform_recency(gaps)
#' transform_recency(gaps, half_life = 1)
#' @export
transform_recency <- function(delta, half_life = NULL, reference = NULL) {
  if (!is.numeric(delta)) {
    stop("`delta` must be a numeric vector.")
  }
  finite_neg <- is.finite(delta) & delta < 0
  if (any(finite_neg)) {
    stop("`delta` must be non-negative.")
  }
  if (!is.null(half_life)) {
    if (!is.numeric(half_life) || length(half_life) != 1L ||
        !is.finite(half_life) || half_life <= 0) {
      stop("`half_life` must be a positive finite scalar.")
    }
    scale <- half_life
  } else {
    ref <- if (is.null(reference)) delta else reference
    if (!is.numeric(ref)) {
      stop("`reference` must be a numeric vector.")
    }
    m <- stats::median(ref, na.rm = TRUE)
    if (!is.finite(m) || m <= 0) {
      stop("Median of the reference gaps must be positive and finite; ",
           "supply `half_life` explicitly when this is not the case.")
    }
    scale <- 2 * m
  }
  exp(-delta / scale)
}
