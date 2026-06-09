#' Fit a relational (hyper)event model on preprocessed case-control data
#'
#' `rem()` is the unified front-end for fitting relational event models from
#' **already preprocessed** case-control data (e.g. produced by `eventnet`),
#' where the endogenous/exogenous covariates have already been computed. It is
#' intended to supersede [compare_models()], [compare_models_smooth()] and
#' [compare_models_global()], which couple feature computation and fitting.
#'
#' Two estimation backends are provided:
#' \describe{
#'   \item{`"degenerate"`}{Degenerate logistic regression on a case-1-control
#'     design (Boschi, Lerner & Wit 2025): the response is a constant 1 and the
#'     linear predictor is built from event-minus-control differences. Supports
#'     smooth time-varying (`tve`), non-linear (`nle`) and time-varying
#'     non-linear (`tvnle`) effects via [mgcv::gam()].}
#'   \item{`"clogit"`}{Conditional logistic regression on a case-k-control
#'     design via [survival::clogit()]. *(Added with issue #84.)*}
#' }
#'
#' @section Formula syntax:
#' The right-hand side lists covariates. A bare name is a **linear** effect; wrap
#' a name to request a smooth effect (degenerate method only):
#' \itemize{
#'   \item `tve(x)`   — time-varying linear effect: `s(time, by = d_x)`.
#'   \item `nle(x)`   — non-linear effect: `s(cbind(x_ev, x_nv), by = c(1, -1))`.
#'   \item `tvnle(x)` — time-varying non-linear effect (tensor product).
#' }
#' For the degenerate method the left-hand side is ignored (the response is the
#' constant case indicator); for `clogit` it is the 0/1 event indicator.
#'
#' @section Column resolution:
#' For a covariate `x`, the event/control difference is taken from column `x`,
#' else `d_x`, else `x_ev - x_nv`. Non-linear terms use `transform_x_ev` /
#' `transform_x_nv` when present (the eventnet spline-transformed covariate),
#' otherwise `x_ev` / `x_nv`. `tvnle` uses `transformed_time` when present.
#' Undirected logs (senders only, no receiver/`TARGET` column) are supported.
#'
#' @param formula A formula; see *Formula syntax*.
#' @param data A data.frame of preprocessed case-control data (wide for the
#'   degenerate method; long with a case indicator and stratum for `clogit`).
#' @param method Estimation backend; see *Description*.
#' @param case Name of the 0/1 event-indicator column (used by `clogit`).
#' @param stratum Name of the column grouping each case with its controls
#'   (required by `clogit`).
#' @param time Name of the time column, required for `tve` / `tvnle` terms.
#' @param k Optional integer basis dimension passed to `s()` / `te()`.
#' @param ... Reserved for future use.
#'
#' @return An object of class `"rem"`: a list with the fitted model (`$fit`),
#'   the `method`, the original `formula`, the parsed `terms`, and the number of
#'   observations `n`. Has [summary()], [coef()], [plot()] and [logLik()]
#'   methods.
#'
#' @seealso [compare_models_smooth()] (superseded), [simulate_relational_events()]
#'   (whose `wide = TRUE` output is a valid input here),
#'   [simulate_directed_hyperevents_tvnl()].
#'
#' @examples
#' set.seed(1)
#' w <- simulate_relational_events(
#'   n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
#'   n_controls = 1, endogenous_stats = "reciprocity_count",
#'   endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
#' fit <- rem(~ reciprocity_count, data = w, method = "degenerate")
#' coef(fit)
#'
#' @export
rem <- function(formula, data,
                method = c("degenerate", "clogit"),
                case = "IS_OBSERVED", stratum = NULL, time = NULL,
                k = NULL, ...) {
  method <- match.arg(method)
  if (!inherits(formula, "formula")) stop("`formula` must be a formula.")
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")

  term_labels <- attr(stats::terms(formula), "term.labels")
  if (!length(term_labels)) {
    stop("`formula` must have at least one term on the right-hand side.")
  }
  parse_term <- function(lbl) {
    m <- regmatches(lbl, regexec("^(tve|nle|tvnle)\\((.+)\\)$", lbl))[[1]]
    if (length(m) == 3L) list(type = m[2], var = trimws(m[3]))
    else list(type = "linear", var = lbl)
  }
  terms_info <- lapply(term_labels, parse_term)

  if (method == "clogit") {
    stop("method = \"clogit\" is not implemented yet (it arrives with issue ",
         "#84); use method = \"degenerate\" for the case-1-control fit.")
  }

  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("The `mgcv` package is required by rem(method = \"degenerate\"). ",
         "Install it with install.packages(\"mgcv\").")
  }
  n <- nrow(data)
  if (!n) stop("`data` has no rows.")

  # event-minus-control difference for covariate v
  get_diff <- function(v) {
    if (!is.null(data[[v]])) return(as.numeric(data[[v]]))
    if (!is.null(data[[paste0("d_", v)]])) return(as.numeric(data[[paste0("d_", v)]]))
    ev <- data[[paste0(v, "_ev")]]; nv <- data[[paste0(v, "_nv")]]
    if (is.null(ev) || is.null(nv)) {
      stop("Cannot find a column for linear term '", v, "' ",
           "(looked for '", v, "', 'd_", v, "', '", v, "_ev'/'", v, "_nv').")
    }
    as.numeric(ev) - as.numeric(nv)
  }
  # case/control matrix for a non-linear term (prefers transform_ columns)
  get_evnv <- function(v) {
    for (pre in c("transform_", "")) {
      ev <- data[[paste0(pre, v, "_ev")]]; nv <- data[[paste0(pre, v, "_nv")]]
      if (!is.null(ev) && !is.null(nv)) {
        return(cbind(case = as.numeric(ev), ctrl = as.numeric(nv)))
      }
    }
    stop("Cannot find ev/nv columns for non-linear term '", v, "' ",
         "(looked for '[transform_]", v, "_ev'/'_nv').")
  }
  get_time <- function() {
    if (is.null(time)) stop("`time` (a column name) is required for tve/tvnle terms.")
    if (is.null(data[[time]])) stop("time column '", time, "' not found in `data`.")
    as.numeric(data[[time]])
  }
  get_time_trans <- function() {
    if (!is.null(data[["transformed_time"]])) as.numeric(data[["transformed_time"]])
    else get_time()
  }

  reserved <- c("one", ".I", ".time", ".T")
  df <- list(one = rep(1, n), .I = cbind(case = rep(1, n), ctrl = rep(-1, n)))
  rhs <- character(0)
  k_arg <- if (is.null(k)) "" else sprintf(", k = %d", k)
  need_time <- FALSE; need_ttrans <- FALSE
  bt <- function(x) paste0("`", x, "`")            # backtick for formula safety
  for (ti in terms_info) {
    v <- ti$var
    if (v %in% reserved) {
      stop("Covariate name '", v, "' clashes with an internal column; ",
           "please rename it in `data`.")
    }
    # Difference / matrix columns are named by the covariate itself so that
    # coef()/summary() report meaningful term names.
    if (ti$type == "linear") {
      df[[v]] <- get_diff(v)
      rhs <- c(rhs, bt(v))
    } else if (ti$type == "tve") {
      df[[v]] <- get_diff(v); need_time <- TRUE
      rhs <- c(rhs, sprintf("s(%s, by = %s%s)", bt(".time"), bt(v), k_arg))
    } else if (ti$type == "nle") {
      xc <- paste0(".X_", v); df[[xc]] <- get_evnv(v)
      rhs <- c(rhs, sprintf("s(%s, by = %s%s)", bt(xc), bt(".I"), k_arg))
    } else if (ti$type == "tvnle") {
      xc <- paste0(".X_", v); df[[xc]] <- get_evnv(v); need_ttrans <- TRUE
      rhs <- c(rhs, sprintf("te(%s, %s, by = %s%s)",
                            bt(".T"), bt(xc), bt(".I"), k_arg))
    }
  }
  if (need_time)   df[[".time"]] <- get_time()
  if (need_ttrans) { tt <- get_time_trans(); df[[".T"]] <- cbind(tt, tt) }

  fm <- stats::as.formula(paste("one ~ -1 +", paste(rhs, collapse = " + ")))
  fit <- mgcv::gam(fm, family = stats::binomial(), data = df, method = "REML")

  structure(
    list(fit = fit, method = method, formula = formula,
         terms = terms_info, n = n, gam_formula = fm),
    class = "rem")
}

#' @export
print.rem <- function(x, ...) {
  cat("Relational event model (rem)\n")
  cat("  method : ", x$method, "\n", sep = "")
  cat("  formula: ", deparse(x$formula), "\n", sep = "")
  cat("  n      : ", x$n, "\n", sep = "")
  invisible(x)
}

#' @export
summary.rem <- function(object, ...) summary(object$fit, ...)

#' @export
coef.rem <- function(object, ...) stats::coef(object$fit, ...)

#' @export
plot.rem <- function(x, ...) plot(x$fit, ...)

#' @export
logLik.rem <- function(object, ...) stats::logLik(object$fit)
