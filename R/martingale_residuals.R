#' Martingale residuals from a case-control partial-likelihood fit
#'
#' Computes per-observation martingale residuals
#' \eqn{M_i = y_i - \pi_i}{M_i = y_i - pi_i} from a one-control-per-case
#' partial-likelihood fit, where \eqn{y_i}{y_i} is the case indicator
#' inside the (case, control) pair and
#' \deqn{
#'   \pi_i \;=\; \frac{\exp(\eta_i)}{\exp(\eta_{\mathrm{case}}) + \exp(\eta_{\mathrm{ctrl}})}
#' }{
#'   pi_i = exp(eta_i) / (exp(eta_case) + exp(eta_ctrl))
#' }
#' is the fitted probability that observation \eqn{i}{i} is the event
#' in its risk set. The residuals sum to zero within each stratum.
#'
#' Useful as a goodness-of-fit diagnostic: plotting residuals vs. time or
#' vs. a covariate reveals systematic miscalibration. The convention
#' matches `survival::residuals.coxph(type = "martingale")` for the
#' two-element risk set induced by 1-control case-control sampling.
#'
#' Only the linear partial-likelihood path (`compare_models()`-style
#' linear-effect specs) is supported by this helper; for smooth-effect
#' fits the case-vs-control matrix design used by
#' [compare_models_smooth()] does not have a clean per-observation
#' martingale interpretation.
#'
#' @param event_log Dyadic event log (see [standardize_event_log()]).
#' @param model A named character vector mapping statistic name to
#'   `"linear"`. Mirrors a single entry of `compare_models()`'s
#'   `models` argument. Non-linear effect types are currently rejected.
#' @param scope,mode,half_life,seed Same meaning as in
#'   [compare_models()]; control the case-control sampling and the
#'   feature computation.
#' @return A data frame with one row per observation in the case-control
#'   table (so 2N rows for N events), with columns:
#'   `stratum`, `role` (`"case"` or `"control"`), `sender`, `receiver`,
#'   `time`, `eta`, `fitted_prob`, `residual`.
#' @references
#' Therneau TM, Grambsch PM, Fleming TR (1990). *Martingale-based
#' residuals for survival models*. Biometrika 77(1), 147--160.
#' @seealso [compare_models()], [compare_models_smooth()].
#' @examples
#' \dontrun{
#' data(classroom_events)
#' res <- martingale_residuals(
#'   classroom_events,
#'   model = c(reciprocity_count = "linear",
#'             transitivity_count = "linear"),
#'   seed = 1)
#' plot(res$time, res$residual,
#'      col = ifelse(res$role == "case", "red", "grey60"),
#'      ylab = "Martingale residual", xlab = "Event time")
#' abline(h = 0)
#' }
#' @export
martingale_residuals <- function(event_log, model,
                                  scope = c("all", "appearance", "citation"),
                                  mode  = c("one", "two"),
                                  half_life = NULL, seed = NULL) {
  if (!is.data.frame(event_log)) stop("`event_log` must be a data.frame.")
  if (!is.character(model) || !length(model)) {
    stop("`model` must be a non-empty named character vector.")
  }
  if (is.null(names(model)) || any(!nzchar(names(model)))) {
    stop("Every entry in `model` must have a non-empty name.")
  }
  if (anyDuplicated(names(model))) {
    stop("`model` must have unique names.")
  }
  bad <- model != "linear"
  if (any(bad)) {
    stop("martingale_residuals() supports only effect type \"linear\". ",
         "Got: ", paste(unique(model[bad]), collapse = ", "))
  }
  scope <- match.arg(scope)
  mode  <- match.arg(mode)

  stat_set <- names(model)
  cc <- sample_non_events(event_log, n_controls = 1L,
                          scope = scope, mode = mode, seed = seed)
  cc_feat <- compute_endogenous_features(cc, stats = stat_set,
                                          half_life = half_life)
  for (st in stat_set) {
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
  X_case <- as.matrix(cases[, stat_set, drop = FALSE])
  X_ctrl <- as.matrix(ctrls[, stat_set, drop = FALSE])
  diff_df <- as.data.frame(X_case - X_ctrl)
  names(diff_df) <- paste0("d_", stat_set)
  diff_df$one <- 1
  fm <- stats::as.formula(paste("one ~",
    paste(paste0("d_", stat_set), collapse = " + "), "- 1"))
  fit <- stats::glm(fm, family = "binomial", data = diff_df)
  beta <- stats::coef(fit)
  names(beta) <- stat_set
  eta_case <- as.numeric(X_case %*% beta)
  eta_ctrl <- as.numeric(X_ctrl %*% beta)
  denom <- exp(eta_case) + exp(eta_ctrl)
  pi_case <- exp(eta_case) / denom
  pi_ctrl <- exp(eta_ctrl) / denom

  n <- nrow(cases)
  out <- data.frame(
    stratum     = c(cases$stratum, ctrls$stratum),
    role        = rep(c("case", "control"), each = n),
    sender      = c(cases$sender, ctrls$sender),
    receiver    = c(cases$receiver, ctrls$receiver),
    time        = c(cases$time, ctrls$time),
    eta         = c(eta_case, eta_ctrl),
    fitted_prob = c(pi_case, pi_ctrl),
    residual    = c(1 - pi_case, 0 - pi_ctrl),
    stringsAsFactors = FALSE)
  out <- out[order(out$stratum, out$role), , drop = FALSE]
  rownames(out) <- NULL
  out
}
