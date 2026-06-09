#' Compare candidate specifications with smooth (TVE / NLE / TVNLE) effects
#'
#' @description
#' **Superseded** by [rem()], which fits the same smooth (TVE / NLE / TVNLE)
#' effects on preprocessed case-control data. `compare_models_smooth()` remains
#' fully supported.
#'
#' Mirrors [compare_models()] but lets each statistic in a specification
#' take one of four effect types instead of a single linear coefficient:
#' linear, time-varying (TVE), non-linear (NLE), or jointly time-varying
#' non-linear (TVNLE). The smooth machinery follows
#' Boschi, Lerner & Wit (2025); the matrix-of-event-vs-non-event trick
#' is documented in their Section 3.3.
#'
#' For each specification:
#' \itemize{
#'   \item One case-control sample is drawn from `event_log` with
#'     `n_controls = 1` (paired event / non-event design).
#'   \item For every requested statistic, both the case (event) and the
#'     control (non-event) features are computed via
#'     [compute_endogenous_features()].
#'   \item The mgcv design uses the case-vs-control matrix trick:
#'     \itemize{
#'       \item linear -> a single coefficient on `case - control` (column `d_stat`).
#'       \item tve    -> `s(time, by = d_stat)` — smooth in time, multiplied by `d_stat`.
#'       \item nle    -> `s(stat_mat, by = I_mat)` where `stat_mat` is a
#'         two-column matrix `cbind(case, control)` and `I_mat` is
#'         `cbind(1, -1)`.
#'       \item tvnle  -> `te(time_mat, stat_mat, by = I_mat)` tensor product
#'         smooth, with time_mat both columns equal to the event time vector.
#'     }
#'   \item The model is fitted with `mgcv::gam` and a degenerate logistic
#'     likelihood: response = `rep(1, n)`, formula = `one ~ -1 + ...`,
#'     `family = binomial`. This matches Boschi et al. equation 8.
#' }
#'
#' AIC values are directly comparable across specifications because every
#' fit uses the same case-control sample. Returns the same tidy
#' `data.frame` as [compare_models()].
#'
#' @param event_log Data frame with `sender`, `receiver`, `time` columns.
#' @param models Named list of specifications. Each entry is itself a
#'   named character vector (or named list) mapping statistic names to
#'   effect types: `"linear"`, `"tve"`, `"nle"`, or `"tvnle"`. Example:
#'   \preformatted{
#'     list(
#'       linear = c(reciprocity_count   = "linear",
#'                  transitivity_count  = "linear"),
#'       nle    = c(reciprocity_time_recent  = "nle",
#'                  transitivity_time_recent = "nle"),
#'       tvnle  = c(reciprocity_time_recent  = "tvnle",
#'                  transitivity_time_recent = "tvnle"))
#'   }
#' @param scope,mode Passed through to [sample_non_events()].
#' @param half_life Required when an exp-decay statistic is requested.
#' @param k Optional integer: knot count for `s()` and `te()` terms.
#'   Default `NULL` lets `mgcv` choose (`-1`).
#' @param seed Integer seed for the case-control sample.
#' @param keep_fits Logical; when `TRUE`, the returned table carries the fitted
#'   model objects (one per spec, named by model, `NULL` for specs that failed)
#'   as `attr(result, "fits")`, e.g. for plotting estimated effects. Defaults to
#'   `FALSE`.
#' @return Data frame with one row per specification and columns
#'   `model`, `n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`.
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and Time-Homogeneity:
#' Relational Hyper Event Models with Time-Varying Non-Linear Effects*.
#' arXiv:2509.05289.
#' @seealso [compare_models()] for the linear-only variant.
#' @export
#' @examples
#' \dontrun{
#' data(classroom_events)
#' compare_models_smooth(
#'   classroom_events,
#'   models = list(
#'     linear = c(reciprocity_time_recent  = "linear",
#'                transitivity_time_recent = "linear"),
#'     nle    = c(reciprocity_time_recent  = "nle",
#'                transitivity_time_recent = "nle"),
#'     tvnle  = c(reciprocity_time_recent  = "tvnle",
#'                transitivity_time_recent = "tvnle")),
#'   seed = 11)
#' }
compare_models_smooth <- function(event_log,
                                   models,
                                   scope = c("all", "appearance", "citation"),
                                   mode  = c("one", "two"),
                                   half_life = NULL,
                                   k = NULL,
                                   seed = NULL,
                                   keep_fits = FALSE) {
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("The `mgcv` package is required by compare_models_smooth(). ",
         "Install it with install.packages(\"mgcv\").")
  }
  if (!is.data.frame(event_log)) stop("`event_log` must be a data.frame.")
  if (!is.list(models) || !length(models)) {
    stop("`models` must be a non-empty named list of (stat -> effect) maps.")
  }
  if (is.null(names(models)) || any(!nzchar(names(models))) ||
      anyDuplicated(names(models))) {
    stop("Every entry in `models` must have a unique non-empty name.")
  }
  scope <- match.arg(scope)
  mode  <- match.arg(mode)

  allowed_effects <- c("linear", "tve", "nle", "tvnle")
  for (i in seq_along(models)) {
    spec <- models[[i]]
    if (is.list(spec)) spec <- unlist(spec)
    if (!is.character(spec) || is.null(names(spec)) ||
        any(!nzchar(names(spec)))) {
      stop("Specification '", names(models)[i],
           "' must be a named character vector mapping stat -> effect.")
    }
    bad <- setdiff(spec, allowed_effects)
    if (length(bad)) {
      stop("Unknown effect type(s) in '", names(models)[i], "': ",
           paste(unique(bad), collapse = ", "),
           ". Allowed: ", paste(allowed_effects, collapse = ", "))
    }
    models[[i]] <- spec
  }

  all_stats <- unique(unlist(lapply(models, names), use.names = FALSE))
  if (!length(all_stats)) {
    stop("At least one statistic must be requested across `models`.")
  }

  # Single matched case-control sample (paired design, n_controls = 1).
  cc <- sample_non_events(event_log,
                          n_controls = 1L,
                          scope = scope, mode = mode,
                          seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = all_stats,
                                          half_life = half_life)
  for (st in all_stats) {
    v <- cc_feat[[st]]
    if (anyNA(v)) {
      v[is.na(v)] <- 0
      cc_feat[[st]] <- v
    }
  }

  cases <- cc_feat[cc_feat$event == 1L, , drop = FALSE]
  ctrls <- cc_feat[cc_feat$event == 0L, , drop = FALSE]
  cases <- cases[order(cases$stratum), , drop = FALSE]
  ctrls <- ctrls[order(ctrls$stratum), , drop = FALSE]
  if (nrow(cases) != nrow(ctrls)) {
    stop("Internal: case and control counts disagree after stratum sort.")
  }
  n <- nrow(cases)

  # Per-spec build a design data list and fit mgcv::gam with the degenerate
  # logistic likelihood from Boschi et al. (2025), equation 8.
  rows <- vector("list", length(models))
  fits <- vector("list", length(models))
  names(fits) <- names(models)
  for (i in seq_along(models)) {
    spec <- models[[i]]
    stat_set <- names(spec)
    eff_set  <- unname(spec)

    df <- list(one = rep(1, n), .time = cases$time)
    rhs_terms <- character(0)

    for (s_idx in seq_along(stat_set)) {
      st  <- stat_set[s_idx]
      eff <- eff_set[s_idx]
      xc  <- cases[[st]]
      xn  <- ctrls[[st]]
      dx  <- xc - xn
      stat_mat <- cbind(case = xc, ctrl = xn)
      I_mat    <- cbind(case = rep(1, n), ctrl = rep(-1, n))
      T_mat    <- cbind(case = cases$time, ctrl = cases$time)
      d_col <- paste0("d_", st); df[[d_col]] <- dx
      X_col <- paste0("X_", st); df[[X_col]] <- stat_mat
      I_col <- paste0("I_", st); df[[I_col]] <- I_mat
      T_col <- paste0("T_", st); df[[T_col]] <- T_mat
      k_arg <- if (is.null(k)) "" else sprintf(", k = %d", k)
      rhs_terms <- c(rhs_terms, switch(eff,
        linear = d_col,
        tve    = sprintf("s(.time, by = %s%s)", d_col, k_arg),
        nle    = sprintf("s(%s, by = %s%s)", X_col, I_col, k_arg),
        tvnle  = sprintf("te(%s, %s, by = %s%s)", T_col, X_col, I_col, k_arg)))
    }

    fm <- stats::as.formula(paste("one ~ -1 +",
                                   paste(rhs_terms, collapse = " + ")))
    fit <- tryCatch(
      mgcv::gam(fm, family = stats::binomial(),
                data = df, method = "REML"),
      error = function(e) {
        warning(sprintf("compare_models_smooth: spec '%s' failed (%s)",
                        names(models)[i], conditionMessage(e)),
                call. = FALSE)
        NULL
      })
    rows[[i]] <- if (is.null(fit)) {
      data.frame(
        model   = names(models)[i],
        n_terms = length(stat_set),
        n_obs   = n,
        log_lik = NA_real_,
        AIC     = NA_real_,
        stringsAsFactors = FALSE)
    } else {
      data.frame(
        model   = names(models)[i],
        n_terms = length(stat_set),
        n_obs   = n,
        log_lik = as.numeric(stats::logLik(fit)),
        AIC     = stats::AIC(fit),
        stringsAsFactors = FALSE)
    }
    fits[[i]] <- fit
  }
  out <- do.call(rbind, rows)
  out$delta_AIC <- out$AIC - min(out$AIC, na.rm = TRUE)
  out <- out[order(out$AIC), , drop = FALSE]
  rownames(out) <- NULL
  if (keep_fits) attr(out, "fits") <- fits
  out
}
