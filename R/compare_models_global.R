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
#' sampled non-event's *back-shifted* time
#' \eqn{t^*_k = t_k + h_{s_k r_k} - h_{s^* r^*}}{t*_k = t_k + h_{s_k r_k} - h_{s*r*}}.
#'
#' Shift distribution. The case-control sample is drawn by
#' [sample_non_events()] with `shift = "exponential"`: one shift per dyad,
#' \eqn{H_{sr} \sim \mathrm{Exp}}{H_sr ~ Exp} with mean \eqn{\nu}{nu} times
#' the average event time (measured from the start of `window`), the control
#' drawn from the dyads whose back-shifted time lies in `window`, and events
#' with no such dyad dropped. Dyadic statistics of each control are computed
#' from the events before its own time \eqn{t^*_k}{t*_k}. The
#' paper uses \eqn{\nu = 1}{nu = 1} and reports no effect of
#' \eqn{\nu}{nu} on the estimates for \eqn{\nu \in [0.1, 100]}{nu in [0.1, 100]}.
#'
#' Specification format. Each entry of `models` is a named character
#' vector mapping a covariate name (a statistic in
#' [endogenous_features()] **or** a column of
#' `global_covariates`) to an effect type:
#' \itemize{
#'   \item `"linear"` -- linear `beta * x` term.
#'   \item `"nl"`     -- smooth `s(x)` (thin-plate, paper's default).
#'   \item `"tv"`     -- smooth `s(time, by = x)` (time-varying).
#'   \item `"tvnl"`   -- tensor product `te(time, x)`.
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
#' @param shift_scale,window Passed to [sample_non_events()]: the shift mean
#'   is `shift_scale` times the average event time, and `window` is the
#'   observation window (default `c(min(time), max(time))`).
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
#' \donttest{
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
                                   shift_scale = 1, window = NULL,
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

  allowed_effects <- c("linear", "nl", "tv", "tvnl",
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

  # 1. One shared time-shifted case-control draw (paper Section 4; one
  # non-event per event), re-used across specs. Each control carries its own
  # back-shifted time t*_k, and events whose shifted risk set holds no other
  # dyad get no control and drop out.
  cc <- sample_non_events(event_log, n_controls = 1L,
                          scope = scope, mode = mode, seed = seed,
                          shift = "exponential", shift_scale = shift_scale,
                          window = window)
  # Dyadic statistics of every row, events and controls alike, against the
  # real events strictly before that row's own time.
  history <- event_log[, c("sender", "receiver", "time")]
  cc_feat <- if (length(all_dyad_stats)) {
    endogenous_features(cc, stats = all_dyad_stats, half_life = half_life,
                        history_log = history)
  } else cc
  if (length(all_dyad_stats)) {
    for (st in all_dyad_stats) {
      v <- cc_feat[[st]]; if (anyNA(v)) v[is.na(v)] <- 0; cc_feat[[st]] <- v
    }
  }
  ctrls <- cc_feat[cc_feat$event == 0L, , drop = FALSE]
  cases <- cc_feat[cc_feat$event == 1L & cc_feat$stratum %in% ctrls$stratum, ,
                   drop = FALSE]
  cases <- cases[order(cases$stratum), , drop = FALSE]
  ctrls <- ctrls[order(ctrls$stratum), , drop = FALSE]
  n <- nrow(cases)
  if (!n) stop("No event has a control in the shifted risk set; lower `shift_scale`.")

  # 2. The non-event's time in the design is its back-shifted time.
  ctrl_shifted_time <- ctrls$time

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

    df <- list(one = rep(1, n))
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
        # Dyadic / node-level stat. Event and control sit at different times,
        # so time-varying terms evaluate the smooth at each row's own time:
        # tv contributes f(t_k) x_ev - f(t*_k) x_nv.
        xc <- cases[[cov]]; xn <- ctrls[[cov]]
        dx <- xc - xn
        stat_mat <- cbind(case = xc, ctrl = xn)
        I_mat    <- cbind(case = rep(1, n), ctrl = rep(-1, n))
        T_mat    <- cbind(case = cases$time, ctrl = ctrl_shifted_time)
        XI_mat   <- cbind(case = xc, ctrl = -xn)
        d_col  <- paste0("d_", cov);  df[[d_col]]  <- dx
        X_col  <- paste0("X_", cov);  df[[X_col]]  <- stat_mat
        I_col  <- paste0("I_", cov);  df[[I_col]]  <- I_mat
        T_col  <- paste0("T_", cov);  df[[T_col]]  <- T_mat
        XI_col <- paste0("XI_", cov); df[[XI_col]] <- XI_mat
        rhs_terms <- c(rhs_terms, switch(eff,
          linear = d_col,
          tv    = sprintf("s(%s, by = %s%s)", T_col, XI_col, k_arg),
          nl    = sprintf("s(%s, by = %s%s)", X_col, I_col, k_arg),
          tvnl  = sprintf("te(%s, %s, by = %s%s)",
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
