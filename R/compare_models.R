#' Compare candidate endogenous specifications by AIC
#'
#' @description
#' **Superseded** by [rem()], the unified front-end for fitting relational
#' event models on preprocessed case-control data. `compare_models()` remains
#' fully supported.
#'
#' Convenience wrapper that runs the canonical case-control / no-intercept
#' binomial-GLM recipe on every specification in `models` and returns a
#' tidy AIC comparison table. One case-control sample is drawn from
#' `event_log` and shared across every specification so that the AIC
#' values are directly comparable.
#'
#' Each specification is a character vector of stat names accepted by
#' [endogenous_features()]. The function computes the union of
#' all stats once, builds case-minus-control differences, and fits one
#' binomial GLM per specification with the appropriate subset of
#' columns. The fitted models are equivalent to the partial-likelihood
#' parametrisation used in case-control REM inference
#' (Vu et al. 2017; Juozaitienė & Wit 2024).
#'
#' For `n_controls = 1` the helper fits a no-intercept binomial GLM
#' on case-minus-control differences. For `n_controls > 1` it falls
#' back to `survival::clogit()` — a true conditional-logistic fit
#' that correctly handles multiple controls per stratum. The
#' `survival` package is in Suggests and is required only when
#' `n_controls > 1`.
#'
#' @param event_log Data frame with `sender`, `receiver`, and `time`
#'   columns.
#' @param models Named list of character vectors. Each entry names one
#'   candidate specification; the vector contents are the
#'   endogenous statistics it includes. Stats must be valid names for
#'   [endogenous_features()].
#' @param n_controls Number of controls per case in
#'   [sample_non_events()]. `1` uses a binomial GLM on differences;
#'   `> 1` uses `survival::clogit()` on the stratified case-control
#'   table.
#' @param random_effects Optional character vector. May be any of
#'   `NULL` (no random effects), `"sender"`, `"receiver"`, or
#'   `c("sender", "receiver")`. When supplied, requires
#'   `n_controls > 1`. With one axis, the stratified `coxph` fit
#'   adds a Gamma `survival::frailty()` term on the requested actor.
#'   With both axes, the fit dispatches to `coxme::coxme()` with two
#'   normal `~ 1 | actor` random effects, which avoids
#'   `survival::coxph`'s one-sparse-term cap and the dense-penalty
#'   segfault on stratified case-control designs. The two-axis
#'   path requires the `coxme` package (Suggests).
#'   This is the actor-heterogeneity correction used by Juozaitienė
#'   & Wit (2024) and changes which specification AIC selects on
#'   real-world data (timing variants typically win over count
#'   baselines once actor effects are absorbed). Defaults to `NULL`
#'   (no random effects).
#' @param scope,mode Passed through to [sample_non_events()]; see that
#'   help page for semantics.
#' @param half_life Required when any specification contains an
#'   exp-decay stat. Shared across all specs that use one.
#' @param seed Optional integer seed for the case-control sample.
#' @param recency How a time-since statistic (`recency` and every
#'   `*_time_recent` / `*_time_first` statistic, interrupted and ordered
#'   ones included) enters the model; see *Time-since statistics*.
#'   `"weight"` (default) uses the recency weight
#'   \eqn{w = 2^{-\delta/T}}{w = 2^(-delta/T)} of [transform_recency()]
#'   (median rule) with \eqn{w = 0}{w = 0} when there is no earlier event,
#'   plus an indicator column `<stat>_none` of no earlier event; `"zero"`
#'   sets the elapsed time \eqn{\delta}{delta} of no earlier event to 0, the
#'   coding of amorem 1.2.0. Count, binary and exp-decay statistics are
#'   unaffected (their missing values are set to 0 either way).
#' @param keep_fits Logical; when `TRUE`, the returned table carries the fitted
#'   model objects (one per spec, named by model, `NULL` for specs that failed)
#'   as `attr(result, "fits")`, e.g. for plotting estimated effects. Defaults to
#'   `FALSE`.
#' @return A data frame with one row per specification and columns
#'   `model`, `n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`. Sorted
#'   ascending by `AIC`. The model with the lowest AIC has
#'   `delta_AIC = 0`. `n_terms` counts the model columns: the statistics
#'   of the specification and, with `recency = "weight"`, their indicator
#'   columns.
#' @section Time-since statistics:
#' [endogenous_features()] returns `NA` for the elapsed time
#' \eqn{\delta}{delta} of a time-since statistic when there is no earlier
#' event of that kind. Setting it to 0 (`recency = "zero"`) gives "no earlier
#' event" the value of "an event a moment ago", and a linear effect of
#' \eqn{\delta}{delta} then ranks such a specification by a coding rather
#' than by the data. With `recency = "weight"` each time-since statistic
#' \eqn{\delta}{delta} enters as two columns,
#' \deqn{w = \exp\{-\delta/(2m)\} = 2^{-\delta/T},\ T = 2m\log 2,
#'   \qquad w = 0 \text{ and } \texttt{<stat>\_none} = 1
#'   \text{ when there is no earlier event,}}{w = exp(-delta/(2m)) = 2^(-delta/T), T = 2 m log 2;  w = 0 and <stat>_none = 1 when there is no earlier event,}
#' where \eqn{m}{m} is the median of the non-missing \eqn{\delta}{delta}
#' over the rows (events and controls) of the case-control sample
#' ([transform_recency()] with its default). The weight is bounded, 1 for an
#' event a moment ago and tending to 0 for an event long ago, and the
#' indicator lets no earlier event differ from an event long ago. The
#' indicator is added only when some row has no earlier event. In
#' [compare_models_smooth()] and [compare_models_global()] the requested
#' effect type applies to \eqn{w}{w} and the indicator enters linearly.
#' The simulator [simulate_relational_events()] uses
#' \eqn{\delta}{delta} with 0 for no earlier event, so a fit of simulated
#' data with the generating linear effect of \eqn{\delta}{delta} uses
#' `recency = "zero"`.
#' @seealso [endogenous_features()], [sample_non_events()].
#' @references
#' Juozaitienė R, Wit EC (2024). It's about time: revisiting reciprocity
#' and triadicity in relational event analysis. *Journal of the Royal
#' Statistical Society Series A* 188(4), 1246-1262.
#' \doi{10.1093/jrsssa/qnae132}.
#' @export
#' @examples
#' \donttest{
#' data(simulated_events)
#' compare_models(
#'   simulated_events,
#'   models = list(
#'     count       = c("reciprocity_count", "transitivity_count"),
#'     continuous  = c("reciprocity_time_recent",
#'                     "transitivity_time_recent"),
#'     interrupted = c("reciprocity_time_recent_interrupted",
#'                     "transitivity_time_recent_interrupted")),
#'   seed = 11)
#' # elapsed time with "no earlier event" set to 0 (amorem 1.2.0)
#' compare_models(
#'   simulated_events,
#'   models = list(
#'     count       = c("reciprocity_count", "transitivity_count"),
#'     continuous  = c("reciprocity_time_recent",
#'                     "transitivity_time_recent")),
#'   seed = 11, recency = "zero")
#' }
compare_models <- function(event_log,
                            models,
                            n_controls = 1,
                            scope = c("all", "appearance", "citation"),
                            mode = c("one", "two"),
                            random_effects = NULL,
                            half_life = NULL,
                            seed = NULL,
                            keep_fits = FALSE,
                            recency = c("weight", "zero")) {
  recency <- match.arg(recency)
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
  if (!is.numeric(n_controls) || length(n_controls) != 1 || n_controls < 1) {
    stop("`n_controls` must be a positive integer.")
  }
  n_controls <- as.integer(n_controls)
  if (!is.null(random_effects)) {
    bad <- setdiff(random_effects, c("sender", "receiver"))
    if (length(bad)) {
      stop("`random_effects` must be a subset of c(\"sender\", \"receiver\"). ",
           "Got: ", paste(bad, collapse = ", "))
    }
    if (anyDuplicated(random_effects)) {
      stop("`random_effects` must not contain duplicates.")
    }
    if (n_controls == 1L) {
      stop("`random_effects` requires `n_controls > 1`. The n_controls = 1 ",
           "path fits a binomial GLM on case-minus-control differences ",
           "and does not support frailty terms; bump n_controls to use ",
           "actor random effects.")
    }
    if (length(random_effects) == 2L &&
        !requireNamespace("coxme", quietly = TRUE)) {
      stop("Two-axis `random_effects = c(\"sender\", \"receiver\")` requires ",
           "the `coxme` package. Install it with install.packages(\"coxme\").")
    }
  }
  if (n_controls > 1L && !requireNamespace("survival", quietly = TRUE)) {
    stop("The `survival` package is required when `n_controls > 1`. ",
         "Install it with install.packages(\"survival\").")
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
  cc_feat <- endogenous_features(cc, stats = all_stats,
                                          half_life = half_life)
  # Time-since statistics: recency weight + indicator, or NA -> 0; every
  # other statistic NA -> 0.
  rc <- .code_recency(cc_feat, all_stats, recency)
  cc_feat <- rc$data
  cols_of <- function(stat_set) .spec_columns(stat_set, rc$none)
  all_cols <- cols_of(all_stats)

  if (n_controls == 1L) {
    # Differences-based binomial GLM is the right tool for 1 control
    # per case; it is asymptotically equivalent to the case-control
    # partial likelihood for that design and avoids the survival
    # dependency.
    cases <- cc_feat[cc_feat$event == 1L, , drop = FALSE]
    ctrls <- cc_feat[cc_feat$event == 0L, , drop = FALSE]
    cases <- cases[order(cases$stratum), , drop = FALSE]
    ctrls <- ctrls[order(ctrls$stratum), , drop = FALSE]
    if (nrow(cases) != nrow(ctrls)) {
      stop("Internal: case and control counts disagree after stratum sort.")
    }
    diff_df <- as.data.frame(
      as.matrix(cases[, all_cols, drop = FALSE]) -
      as.matrix(ctrls[, all_cols, drop = FALSE]))
    names(diff_df) <- paste0("d_", all_cols)
    diff_df$one <- 1

    rows <- vector("list", length(models))
    fits <- vector("list", length(models))
    names(fits) <- names(models)
    for (i in seq_along(models)) {
      stat_set <- models[[i]]
      fm <- stats::as.formula(paste("one ~",
        paste(paste0("d_", cols_of(stat_set)), collapse = " + "), "- 1"))
      fit <- stats::glm(fm, family = "binomial", data = diff_df)
      rows[[i]] <- data.frame(
        model   = names(models)[i],
        n_terms = length(cols_of(stat_set)),
        n_obs   = nrow(diff_df),
        log_lik = as.numeric(stats::logLik(fit)),
        AIC     = stats::AIC(fit),
        stringsAsFactors = FALSE)
      fits[[i]] <- fit
    }
  } else {
    # Multiple controls per case: fit a true conditional-logistic
    # model via survival::coxph (which is what survival::clogit calls
    # internally, but calling coxph directly avoids the requirement
    # that survival be attached to the search path). The stratum
    # identifies the matched set; the response is Surv(rep(1, n),
    # event) which collapses to ordinary logistic stratified by
    # `stratum`. AIC values are comparable because every fit uses
    # the same case-control sample.
    cc_feat_sorted <- cc_feat[order(cc_feat$stratum, -cc_feat$event), ,
                              drop = FALSE]
    surv_resp <- survival::Surv(rep(1, nrow(cc_feat_sorted)),
                                 cc_feat_sorted$event)
    cc_feat_sorted$.surv <- surv_resp
    # Random-effects setup. Two paths:
    #   - 0 or 1 axis  : stratified survival::coxph with frailty() term.
    #   - 2 axes       : coxme::coxme with two ~ 1 | actor random effects.
    # The two-axis path mirrors Juozaitiene & Wit (2024)'s full
    # frailty model. We pick coxme for the two-axis case because
    # survival::coxph caps sparse frailty() at one term per fit and
    # the dense-penalty fallback segfaults on stratified case-control
    # designs of typical size.
    two_axis <- length(random_effects) == 2L
    frailty_terms <- character(0)
    if (!two_axis) {
      if ("sender" %in% random_effects) {
        cc_feat_sorted$.sender_factor <- factor(cc_feat_sorted$sender)
        frailty_terms <- c(frailty_terms,
                           "frailty(.sender_factor)")
      } else if ("receiver" %in% random_effects) {
        cc_feat_sorted$.receiver_factor <- factor(cc_feat_sorted$receiver)
        frailty_terms <- c(frailty_terms,
                           "frailty(.receiver_factor)")
      }
    } else {
      cc_feat_sorted$.sender_factor   <- factor(cc_feat_sorted$sender)
      cc_feat_sorted$.receiver_factor <- factor(cc_feat_sorted$receiver)
    }

    rows <- vector("list", length(models))
    fits <- vector("list", length(models))
    names(fits) <- names(models)
    for (i in seq_along(models)) {
      stat_set <- models[[i]]
      if (two_axis) {
        # Modern coxme embeds random effects in the formula via
        # `(1 | factor)` terms. The strata() term stays in the same
        # formula. The deprecated `random = list(...)` argument is
        # avoided.
        rhs_terms <- c(cols_of(stat_set), "strata(stratum)",
                       "(1 | .sender_factor)", "(1 | .receiver_factor)")
        fm <- stats::as.formula(paste(".surv ~",
          paste(rhs_terms, collapse = " + ")))
        fit <- tryCatch(
          coxme::coxme(fm, data = cc_feat_sorted),
          error = function(e) {
            warning(sprintf("compare_models: spec '%s' failed to fit (%s)",
                            names(models)[i], conditionMessage(e)),
                    call. = FALSE)
            NULL
          })
      } else {
        rhs_terms <- c(cols_of(stat_set), "strata(stratum)", frailty_terms)
        fm <- stats::as.formula(paste(".surv ~",
          paste(rhs_terms, collapse = " + ")))
        # frailty() inside coxph can fail to converge on small data or
        # highly correlated actor effects; report NA rather than letting
        # the whole compare_models call bomb out.
        fit <- tryCatch(
          survival::coxph(fm, data = cc_feat_sorted, method = "breslow"),
          error = function(e) {
            warning(sprintf("compare_models: spec '%s' failed to fit (%s)",
                            names(models)[i], conditionMessage(e)),
                    call. = FALSE)
            NULL
          })
      }
      rows[[i]] <- if (is.null(fit)) {
        data.frame(
          model   = names(models)[i],
          n_terms = length(cols_of(stat_set)),
          n_obs   = length(unique(cc_feat_sorted$stratum)),
          log_lik = NA_real_,
          AIC     = NA_real_,
          stringsAsFactors = FALSE)
      } else {
        data.frame(
          model   = names(models)[i],
          n_terms = length(cols_of(stat_set)),
          n_obs   = length(unique(cc_feat_sorted$stratum)),
          log_lik = as.numeric(stats::logLik(fit)),
          AIC     = stats::AIC(fit),
          stringsAsFactors = FALSE)
      }
      fits[[i]] <- fit
    }
  }
  out <- do.call(rbind, rows)
  out$delta_AIC <- out$AIC - min(out$AIC, na.rm = TRUE)
  out <- out[order(out$AIC), , drop = FALSE]
  rownames(out) <- NULL
  if (keep_fits) attr(out, "fits") <- fits
  out
}

# --- internal: time-since statistics (`recency`, `*_time_recent`,
# `*_time_first`, interrupted and ordered variants), whose NA means "no
# earlier event".
.is_time_since_stat <- function(st) {
  st == "recency" | grepl("_time_(recent|first)", st)
}

# --- internal: code the statistics of a case-control feature table.
# recency = "zero": every NA -> 0. recency = "weight": a time-since
# statistic delta becomes w = transform_recency(delta) (median rule over
# all rows) with w = 0 for NA, and the column `<stat>_none` = 1{NA} is
# added when some row is NA; every other statistic NA -> 0. Returns the
# table and `none`, the named vector stat -> indicator column.
.code_recency <- function(feat, stats, recency = c("weight", "zero")) {
  recency <- match.arg(recency)
  none <- character(0)
  for (st in stats) {
    v <- feat[[st]]
    na <- is.na(v)
    if (recency == "weight" && .is_time_since_stat(st)) {
      if (all(na)) {
        v <- rep(0, length(v))
      } else {
        m <- stats::median(v[!na])
        if (!is.finite(m) || m <= 0) {
          stop("compare_models: the median elapsed time of `", st,
               "` is not positive, so its recency weight is undefined; ",
               "use recency = \"zero\".", call. = FALSE)
        }
        v <- transform_recency(v)
        v[na] <- 0
        if (any(na)) {
          nm <- paste0(st, "_none")
          feat[[nm]] <- as.numeric(na)
          none[st] <- nm
        }
      }
    } else if (any(na)) {
      v[na] <- 0
    }
    feat[[st]] <- v
  }
  list(data = feat, none = none)
}

# --- internal: model columns of a specification: its statistics, each
# time-since statistic followed by its indicator when it has one.
.spec_columns <- function(stat_set, none) {
  unlist(lapply(stat_set, function(st) {
    if (st %in% names(none)) c(st, none[[st]]) else st
  }), use.names = FALSE)
}
