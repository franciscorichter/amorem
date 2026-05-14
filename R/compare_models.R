#' Compare candidate endogenous specifications by AIC
#'
#' Convenience wrapper that runs the canonical case-control / no-intercept
#' binomial-GLM recipe on every specification in `models` and returns a
#' tidy AIC comparison table. One case-control sample is drawn from
#' `event_log` and shared across every specification so that the AIC
#' values are directly comparable.
#'
#' Each specification is a character vector of stat names accepted by
#' [compute_endogenous_features()]. The function computes the union of
#' all stats once, builds case-minus-control differences, and fits one
#' binomial GLM per specification with the appropriate subset of
#' columns. The fitted models are equivalent to the partial-likelihood
#' parametrisation used in case-control REM inference
#' (Vu et al. 2017; Juozaitienė & Wit 2024).
#'
#' The helper currently supports `n_controls = 1` only; richer
#' case-control designs (more controls per case, conditional-logistic
#' aggregation) are on the roadmap.
#'
#' @param event_log Data frame with `sender`, `receiver`, and `time`
#'   columns.
#' @param models Named list of character vectors. Each entry names one
#'   candidate specification; the vector contents are the
#'   endogenous statistics it includes. Stats must be valid names for
#'   [compute_endogenous_features()].
#' @param n_controls Number of controls per case in
#'   [sample_non_events()]. Currently must be `1`.
#' @param scope,mode Passed through to [sample_non_events()]; see that
#'   help page for semantics.
#' @param half_life Required when any specification contains an
#'   exp-decay stat. Shared across all specs that use one.
#' @param seed Optional integer seed for the case-control sample.
#' @return A data frame with one row per specification and columns
#'   `model`, `n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`. Sorted
#'   ascending by `AIC`. The model with the lowest AIC has
#'   `delta_AIC = 0`.
#' @seealso [compute_endogenous_features()], [sample_non_events()].
#' @references
#' Juozaitienė R, Wit EC (2024). It's about time: revisiting reciprocity
#' and triadicity in relational event analysis. *Journal of the Royal
#' Statistical Society Series A* 188(4), 1246-1262.
#' \doi{10.1093/jrsssa/qnae132}.
#' @export
#' @examples
#' \dontrun{
#' data(classroom_events)
#' compare_models(
#'   classroom_events,
#'   models = list(
#'     count       = c("reciprocity_count", "transitivity_count"),
#'     continuous  = c("reciprocity_time_recent",
#'                     "transitivity_time_recent"),
#'     interrupted = c("reciprocity_time_recent_interrupted",
#'                     "transitivity_time_recent_interrupted")),
#'   seed = 11)
#' }
compare_models <- function(event_log,
                            models,
                            n_controls = 1,
                            scope = c("all", "appearance", "citation"),
                            mode = c("one", "two"),
                            half_life = NULL,
                            seed = NULL) {
  if (!is.data.frame(event_log)) stop("`event_log` must be a data.frame.")
  if (!is.list(models) || !length(models)) {
    stop("`models` must be a non-empty named list of character vectors.")
  }
  if (is.null(names(models)) || any(!nzchar(names(models))) ||
      anyDuplicated(names(models))) {
    stop("Every entry in `models` must have a unique non-empty name.")
  }
  if (!all(vapply(models, is.character, logical(1)))) {
    stop("Every entry in `models` must be a character vector.")
  }
  if (n_controls != 1L) {
    stop("`compare_models()` currently supports `n_controls = 1` only.")
  }
  scope <- match.arg(scope)
  mode  <- match.arg(mode)

  all_stats <- unique(unlist(models, use.names = FALSE))
  if (!length(all_stats)) {
    stop("At least one statistic must be requested across `models`.")
  }

  cc <- sample_non_events(event_log,
                          n_controls = n_controls,
                          scope = scope, mode = mode,
                          seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = all_stats,
                                          half_life = half_life)
  # NA -> 0 so that case-minus-control differences are well-defined
  # everywhere; matches the simulator's never-seen convention.
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

  diff_df <- as.data.frame(
    as.matrix(cases[, all_stats, drop = FALSE]) -
    as.matrix(ctrls[, all_stats, drop = FALSE]))
  names(diff_df) <- paste0("d_", all_stats)
  diff_df$one <- 1

  rows <- vector("list", length(models))
  for (i in seq_along(models)) {
    stat_set <- models[[i]]
    bad <- setdiff(stat_set, all_stats)
    if (length(bad)) stop("Internal: missing stats ", paste(bad, collapse = ", "))
    fm <- stats::as.formula(paste("one ~",
      paste(paste0("d_", stat_set), collapse = " + "), "- 1"))
    fit <- stats::glm(fm, family = "binomial", data = diff_df)
    rows[[i]] <- data.frame(
      model   = names(models)[i],
      n_terms = length(stat_set),
      n_obs   = nrow(diff_df),
      log_lik = as.numeric(stats::logLik(fit)),
      AIC     = stats::AIC(fit),
      stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out$delta_AIC <- out$AIC - min(out$AIC)
  out <- out[order(out$AIC), , drop = FALSE]
  rownames(out) <- NULL
  out
}
