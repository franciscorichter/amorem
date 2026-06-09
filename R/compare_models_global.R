#' Compare REM specifications with global covariate effects
#'
#' @description
#' **Superseded** by [rem()], the unified front-end for fitting relational
#' event models on preprocessed case-control data. `compare_models_global()`
#' remains fully supported.
#'
#' Implements the time-shifted partial likelihood of Lembo,
#' Juozaitienė, Vinciotti & Wit (2025) for fitting relational event
#' models with **global covariate effects** — covariates that are
#' time-dependent but constant across all interacting pairs (e.g.\
#' temperature, time of day, the residual baseline hazard). Standard
#' case-control partial likelihood cannot identify these because
#' global terms cancel in the rate ratio; this function follows the
#' paper's Section 4 recipe: a random per-dyad time shift breaks the
#' cancellation, and with one non-event per event the partial
#' likelihood reduces to a degenerate logistic additive model fit by
#' [mgcv::gam()].
#'
#' Per the paper's equations 11-13:
#' \deqn{
#'   \mathcal{L}^{PS}(f, g) = \prod_{k=1}^n
#'     \frac{\exp\{\Delta_k(f; x_{s_k r_k}) + \Delta_k(g; x_k)\}}
#'          {1 + \exp\{\Delta_k(f; x_{s_k r_k}) + \Delta_k(g; x_k)\}}
#' }{
#'   L^PS(f, g) = prod_k logistic(Delta_k(f; x_{s_k r_k}) + Delta_k(g; x_k))
#' }
#' where each \eqn{\Delta_k}{Delta_k} is the difference between the
#' (smooth) function evaluated at the focal event time and at the
#' sampled non-event's *shifted* time
#' \eqn{t^*_k = t_k - h_{s^* r^*}}{t*_k = t_k - h_{s*r*}}.
#'
#' Shift distribution. Per-dyad shifts \eqn{H_{sr}}{H_sr} are drawn
#' independently from an exponential distribution with mean
#' \eqn{\nu \cdot \bar{\Delta t}}{nu * mean_dt} where
#' \eqn{\bar{\Delta t}}{mean_dt} is the average inter-arrival time
#' in `event_log`. The paper's simulation studies find that
#' \eqn{\nu = 1}{nu = 1} works in practice and that the estimates
#' are robust to choices in \eqn{[0.1, 10]}{[0.1, 10]}.
#'
#' Specification format. Each entry of `models` is a named character
#' vector mapping a covariate name (a statistic in
#' [compute_endogenous_features()] **or** a column of
#' `global_covariates`) to an effect type:
#' \itemize{
#'   \item `"linear"` -- linear `beta * x` term.
#'   \item `"nle"`     -- smooth `s(x)` (thin-plate, paper's default).
#'   \item `"tve"`     -- smooth `s(time, by = x)` (time-varying).
#'   \item `"tvnle"`   -- tensor product `te(time, x)`.
#'   \item `"global_smooth"` -- smooth `s(x_global)` evaluated at the
#'     focal time vs. the non-event's shifted time (the paper's
#'     `g_b(x^{(b)}(t))` family).
#'   \item `"global_cyclic"` -- cyclic smooth `s(x_global, bs = "cc")`
#'     for time-of-day-like covariates with a periodic domain.
#'   \item `"global_time"` -- a smooth on `time` itself, recovering
#'     the residual time effect \eqn{g_0(t)}{g_0(t)} of paper eq. 3.
#' }
#'
#' @param event_log Data frame with `sender`, `receiver`, `time`.
#' @param models Named list of specifications (see "Specification
#'   format" above).
#' @param global_covariates Optional data frame with a `time` column
#'   plus one column per global covariate referenced in `models`.
#'   The function evaluates each covariate at the focal event time
#'   and at the non-event's shifted time by stepwise lookup (LOCF on
#'   the `time` axis).
#' @param scope,mode Passed through to [sample_non_events()].
#' @param half_life Required when any dyadic spec uses an exp-decay
#'   stat.
#' @param shift_scale Multiplier on the average inter-arrival time
#'   for the exponential shift distribution. Defaults to 1.
#' @param k Optional knot count for smooth terms (see
#'   [mgcv::s()]). Defaults to `mgcv`'s automatic choice.
#' @param k_cyclic Knot count for `global_cyclic` smooths
#'   (paper uses 10 for time-of-day).
#' @param seed Integer seed for the case-control sample and the
#'   shift draws.
#' @param keep_fits Logical; when `TRUE`, the returned table carries the fitted
#'   model objects (one per spec, named by model, `NULL` for specs that failed)
#'   as `attr(result, "fits")`, e.g. for plotting estimated effects. Defaults to
#'   `FALSE`.
#' @return Data frame with one row per specification and columns
#'   `model`, `n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`.
#' @references
#' Lembo M, Juozaitienė R, Vinciotti V, Wit EC (2025).
#' *Relational event models with global covariates: an application
#' to bike sharing*. Journal of the Royal Statistical Society,
#' Series C. \doi{10.1093/jrsssc/qlaf058}.
#' @seealso [compare_models()] (linear, no globals),
#'   [compare_models_smooth()] (smooth dyadic effects, no globals).
#' @export
#' @examples
#' \dontrun{
#' data(classroom_events)
#' # Hourly temperature track on the same time axis:
#' g <- data.frame(time = seq(0, max(classroom_events$time), length = 50),
#'                 temperature = rnorm(50, 20, 5))
#' compare_models_global(
#'   classroom_events,
#'   models = list(
#'     dyadic_only = c(reciprocity_count        = "linear",
#'                     transitivity_count       = "linear"),
#'     with_global = c(reciprocity_count        = "linear",
#'                     transitivity_count       = "linear",
#'                     temperature              = "global_smooth",
#'                     time                     = "global_time")),
#'   global_covariates = g,
#'   seed = 11, k = 5)
#' }
compare_models_global <- function(event_log,
                                   models,
                                   global_covariates = NULL,
                                   scope = c("all", "appearance", "citation"),
                                   mode  = c("one", "two"),
                                   half_life = NULL,
                                   shift_scale = 1,
                                   k = NULL, k_cyclic = 10,
                                   seed = NULL,
                                   keep_fits = FALSE) {
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("The `mgcv` package is required by compare_models_global(). ",
         "Install it with install.packages(\"mgcv\").")
  }
  if (!is.data.frame(event_log)) stop("`event_log` must be a data.frame.")
  if (!is.list(models) || !length(models)) {
    stop("`models` must be a non-empty named list of (cov -> effect) maps.")
  }
  if (is.null(names(models)) || any(!nzchar(names(models))) ||
      anyDuplicated(names(models))) {
    stop("Every entry in `models` must have a unique non-empty name.")
  }
  scope <- match.arg(scope)
  mode  <- match.arg(mode)

  allowed_effects <- c("linear", "nle", "tve", "tvnle",
                       "global_smooth", "global_cyclic", "global_time")
  global_effects  <- c("global_smooth", "global_cyclic", "global_time")
  for (i in seq_along(models)) {
    spec <- models[[i]]
    if (is.list(spec)) spec <- unlist(spec)
    if (!is.character(spec) || is.null(names(spec)) ||
        any(!nzchar(names(spec)))) {
      stop("Specification '", names(models)[i],
           "' must be a named character vector mapping covariate -> effect.")
    }
    bad <- setdiff(spec, allowed_effects)
    if (length(bad)) {
      stop("Unknown effect type(s) in '", names(models)[i], "': ",
           paste(unique(bad), collapse = ", "),
           ". Allowed: ", paste(allowed_effects, collapse = ", "))
    }
    models[[i]] <- spec
  }
  # Validate that referenced global covariates exist on `global_covariates`.
  ref_global <- function(spec) {
    nm <- names(spec); eff <- unname(spec)
    nm[eff %in% global_effects & eff != "global_time"]
  }
  needed_global <- unique(unlist(lapply(models, ref_global), use.names = FALSE))
  if (length(needed_global) && (is.null(global_covariates) ||
       !all(needed_global %in% names(global_covariates)))) {
    miss <- setdiff(needed_global, names(global_covariates))
    stop("Global covariate(s) referenced in models are missing from ",
         "`global_covariates`: ", paste(miss, collapse = ", "), ".")
  }
  if (!is.null(global_covariates) && !"time" %in% names(global_covariates)) {
    stop("`global_covariates` must have a `time` column.")
  }

  # Dyadic stat names from all specs (used by the case-control draw +
  # endogenous feature computation).
  all_dyad_stats <- unique(unlist(
    lapply(models, function(s) names(s)[!unname(s) %in% global_effects]),
    use.names = FALSE))

  # 1. One shared case-control draw (paired event / non-event design,
  # n_controls = 1). The case-control table will be re-used across specs.
  cc <- sample_non_events(event_log, n_controls = 1L,
                          scope = scope, mode = mode, seed = seed)
  cc_feat <- if (length(all_dyad_stats)) {
    compute_endogenous_features(cc, stats = all_dyad_stats,
                                 half_life = half_life)
  } else cc
  if (length(all_dyad_stats)) {
    for (st in all_dyad_stats) {
      v <- cc_feat[[st]]; if (anyNA(v)) v[is.na(v)] <- 0; cc_feat[[st]] <- v
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

  # 2. Per-dyad time shift H_{sr}. The paper draws H_{sr} ~ Exp(rate)
  # with mean = shift_scale * mean(inter-arrival times); we treat the
  # control row as the "non-event dyad" and assign it an independent
  # shift, then the focal event's time stays at t_k while the
  # non-event's time used in the design is t_k - h_{s*r*}.
  if (!is.null(seed)) set.seed(seed)
  ev_times <- sort(event_log$time)
  mean_dt  <- if (length(ev_times) > 1L) {
    mean(diff(ev_times))
  } else 1
  rate <- 1 / max(shift_scale * mean_dt, .Machine$double.eps)
  h_shifts <- stats::rexp(n, rate = rate)
  ctrl_shifted_time <- cases$time - h_shifts

  # 3. Global-covariate evaluation by LOCF lookup on the time axis.
  eval_global <- function(name, t) {
    g <- global_covariates
    ord <- order(g$time)
    idx <- findInterval(t, g$time[ord], all.inside = TRUE)
    g[[name]][ord][idx]
  }

  # 4. Per-spec design + mgcv::gam fit.
  rows <- vector("list", length(models))
  fits <- vector("list", length(models))
  names(fits) <- names(models)
  for (i in seq_along(models)) {
    spec <- models[[i]]
    cov_names <- names(spec); eff_names <- unname(spec)

    df <- list(one = rep(1, n), .time = cases$time)
    rhs_terms <- character(0)
    k_arg     <- if (is.null(k)) "" else sprintf(", k = %d", k)

    for (s_idx in seq_along(cov_names)) {
      cov <- cov_names[s_idx]; eff <- eff_names[s_idx]
      if (eff %in% global_effects) {
        # Global covariate: evaluated at t_k vs. t*_k = t_k - h_{s*r*}.
        if (eff == "global_time") {
          xc <- cases$time; xn <- ctrl_shifted_time
        } else {
          xc <- eval_global(cov, cases$time)
          xn <- eval_global(cov, ctrl_shifted_time)
        }
        dx <- xc - xn
        stat_mat <- cbind(case = xc, ctrl = xn)
        I_mat    <- cbind(case = rep(1, n), ctrl = rep(-1, n))
        d_col <- paste0("d_", cov);   df[[d_col]] <- dx
        X_col <- paste0("X_", cov);   df[[X_col]] <- stat_mat
        I_col <- paste0("I_", cov);   df[[I_col]] <- I_mat
        rhs_terms <- c(rhs_terms, switch(eff,
          global_smooth = sprintf("s(%s, by = %s%s)", X_col, I_col, k_arg),
          global_cyclic = sprintf("s(%s, by = %s, bs = \"cc\", k = %d)",
                                  X_col, I_col, k_cyclic),
          global_time   = sprintf("s(%s, by = %s%s)", X_col, I_col, k_arg)))
      } else {
        # Dyadic / node-level stat: same as compare_models_smooth().
        xc <- cases[[cov]]; xn <- ctrls[[cov]]
        dx <- xc - xn
        stat_mat <- cbind(case = xc, ctrl = xn)
        I_mat    <- cbind(case = rep(1, n), ctrl = rep(-1, n))
        T_mat    <- cbind(case = cases$time, ctrl = cases$time)
        d_col <- paste0("d_", cov);  df[[d_col]] <- dx
        X_col <- paste0("X_", cov);  df[[X_col]] <- stat_mat
        I_col <- paste0("I_", cov);  df[[I_col]] <- I_mat
        T_col <- paste0("T_", cov);  df[[T_col]] <- T_mat
        rhs_terms <- c(rhs_terms, switch(eff,
          linear = d_col,
          tve    = sprintf("s(.time, by = %s%s)", d_col, k_arg),
          nle    = sprintf("s(%s, by = %s%s)", X_col, I_col, k_arg),
          tvnle  = sprintf("te(%s, %s, by = %s%s)",
                            T_col, X_col, I_col, k_arg)))
      }
    }

    fm <- stats::as.formula(paste("one ~ -1 +",
      paste(rhs_terms, collapse = " + ")))
    fit <- tryCatch(
      mgcv::gam(fm, family = stats::binomial(),
                data = df, method = "REML"),
      error = function(e) {
        warning(sprintf("compare_models_global: spec '%s' failed (%s)",
                        names(models)[i], conditionMessage(e)),
                call. = FALSE)
        NULL
      })
    rows[[i]] <- if (is.null(fit)) {
      data.frame(model = names(models)[i],
                 n_terms = length(cov_names),
                 n_obs = n, log_lik = NA_real_, AIC = NA_real_,
                 stringsAsFactors = FALSE)
    } else {
      data.frame(model = names(models)[i],
                 n_terms = length(cov_names),
                 n_obs = n,
                 log_lik = as.numeric(stats::logLik(fit)),
                 AIC = stats::AIC(fit),
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
