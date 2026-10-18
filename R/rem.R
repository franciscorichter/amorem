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
#'   \item{`"gam"`}{Degenerate logistic regression on a case-1-control
#'     design (Boschi, Lerner & Wit 2025): the response is a constant 1 and the
#'     linear predictor is built from event-minus-control differences. Supports
#'     smooth time-varying (`tv`), non-linear (`nl`) and time-varying
#'     non-linear (`tvnl`) effects via [mgcv::gam()].}
#'   \item{`"clogit"`}{Conditional logistic regression on a case-k-control
#'     design via [survival::clogit()] (linear terms only). The case/control
#'     strata are taken from `stratum`, or derived as `cumsum(case == 1)` when
#'     `stratum` is `NULL` (assuming each case is immediately followed by its
#'     controls, the eventnet blocked layout).}
#'   \item{`"nn"`}{Flexible conditional-logistic models on the same
#'     case-k-control design as `clogit`, trained by (mini-batch) gradient
#'     descent on the exact risk-set softmax partial likelihood. Two
#'     architectures via [nn_control()]: a multilayer perceptron scoring the
#'     full covariate vector jointly (interaction-capable), or an
#'     `additive_spline` predictor — per-covariate B-spline expansions fitted
#'     by stochastic gradient, the STREAM construction of Filippi-Mazzola &
#'     Wit (2024, JRSS-C). No coefficient table; `summary()` reports
#'     in-sample (and, with a validation split, held-out) concordance and
#'     `plot(type = "pdp")` shows per-feature curves. Pure-R implementation,
#'     no extra dependencies.}
#' }
#'
#' @section Formula syntax:
#' The right-hand side lists covariates. A bare name is a **linear** effect; wrap
#' a name to request a smooth effect (`gam` method only):
#' \itemize{
#'   \item `tv(x)`   — time-varying linear effect: `s(time, by = d_x)`.
#'   \item `nl(x)`   — non-linear effect: `s(cbind(x_ev, x_nv), by = c(1, -1))`.
#'   \item `tvnl(x)` — time-varying non-linear effect (tensor product).
#'   \item `re(x)`    — random effect of a grouping factor `x` (e.g. the
#'     sender), built from the matched `x_ev` / `x_nv` levels as
#'     `s(cbind(x_ev, x_nv), by = cbind(1, -1), bs = "re")`, contributing
#'     `f(event_level) - f(control_level)` (following the REM tutorial's
#'     species-invasiveness term). Falls back to a single column `x` when
#'     `x_ev` / `x_nv` are absent. Identified only when the event and control
#'     differ on `x`.
#' }
#' Smooth terms take the basis settings of [mgcv::s()] / [mgcv::te()] as
#' named arguments after the covariate, so each term can use its own basis
#' dimension and type: `tv(x, k = 20, bs = "cr") + nl(y, k = 5, bs = "ps")`.
#' Any `s()` / `te()` argument other than `by` is accepted (e.g. `m`, `fx`,
#' `sp`, `xt`); for `tvnl` a vector `k` or `bs` gives one value per margin,
#' time first (`tvnl(x, k = c(5, 8))`). Argument values are evaluated in the
#' formula's environment. A term without its own `k` / `bs` uses the global
#' `k` / `bs` arguments of `rem()`, and mgcv's defaults when those are `NULL`.
#' `re()` takes no further arguments (its basis is fixed to `bs = "re"`).
#'
#' For the `gam` method the left-hand side is ignored (the response is the
#' constant case indicator); for `clogit` the left-hand side names the 0/1 event
#' indicator column (e.g. `event ~ x`), unless `case` is given explicitly.
#'
#' @section Column resolution:
#' For a covariate `x`, the event/control difference is taken from column `x`,
#' else `d_x`, else `x_ev - x_nv`. Non-linear terms use `transform_x_ev` /
#' `transform_x_nv` when present (the eventnet spline-transformed covariate),
#' otherwise `x_ev` / `x_nv`. `tvnl` uses `transformed_time` when present.
#' Undirected logs (senders only, no receiver/`TARGET` column) are supported.
#'
#' @section Name clashes with other relational-event packages:
#' The name `rem()` is used by three CRAN packages: this one,
#' \pkg{relevent} (on CRAN since 2010) and \pkg{redeem} (2026). Attaching
#' more than one of them masks the others, and R will say so at load time.
#'
#' The deeper issue is dispatch rather than masking. `amorem`'s fitted object
#' has class `"rem"`, and \pkg{relevent} and \pkg{redeem} register S3 methods
#' on that same class name, so merely *loading* one of them --- attaching is
#' not required --- can re-point `print()`, `summary()`, `plot()`, `predict()`
#' and `logLik()` for objects fitted here. If you work with more than one of
#' these packages in a session, call `amorem::rem()` explicitly and be
#' deliberate about which package is loaded when you print or plot a fit.
#'
#' @param formula A formula; see *Formula syntax*.
#' @param data A data.frame of preprocessed case-control data (wide for the
#'   `gam` method; long with a case indicator and stratum for `clogit`). For
#'   `method = "gam"`, long case-control input (a `event`/`IS_OBSERVED`
#'   indicator with control rows) is detected and widened automatically via
#'   [widen_case_control()], with a message.
#' @param method Estimation backend; see *Description*.
#' @param case Optional name of the 0/1 event-indicator column for the `clogit`
#'   and `nn` backends. If `NULL` (default), the indicator is taken from the
#'   formula's left-hand side (e.g. `event ~ x`). Ignored by the `gam` method.
#' @param stratum Name of the column grouping each case with its controls,
#'   for `clogit` and `nn`. When `NULL`, a column named `stratum` (as written
#'   by [sample_non_events()]) is used if present; otherwise the strata are
#'   derived as `cumsum(case == 1)`.
#' @param time Name of the time column, required for `tv` / `tvnl` terms.
#'   A single column `time` gives the event and its control the same time.
#'   When it is absent and `time_ev` / `time_nv` are present (the wide form of
#'   time-shifted sampling, [sample_non_events()] with
#'   `shift = "exponential"`), each row is evaluated at its own time: `tv(x)`
#'   contributes \eqn{\beta(t)x_{ev} - \beta(t^*)x_{nv}}{beta(t) x_ev - beta(t*) x_nv}
#'   and needs `x_ev` / `x_nv`.
#' @param k Optional basis dimension passed to every `s()` / `te()` smooth
#'   that does not set its own `k` (see *Formula syntax*).
#' @param bs Optional basis type (e.g. `"tp"`, `"cr"`, `"ps"`) passed to every
#'   `s()` / `te()` smooth that does not set its own `bs`.
#' @param gam_method Smoothness-selection method for the `gam` backend,
#'   passed to [mgcv::gam()]. Defaults to `NULL`, which uses mgcv's own default
#'   (`"GCV.Cp"`) and reproduces the Intro-to-REM tutorial parameterization.
#'   Set to `"REML"` for the REML fit used in some papers.
#' @param nn An [nn_control()] object with the architecture and training
#'   hyper-parameters for `method = "nn"`. Ignored by the other backends.
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
#' @importFrom survival clogit strata coxph Surv frailty
#'
#' @examples
#' set.seed(1)
#' w <- simulate_relational_events(
#'   n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
#'   n_controls = 1, endogenous_stats = "reciprocity_count",
#'   endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
#' fit <- rem(~ reciprocity_count, data = w, method = "gam")
#' coef(fit)
#'
#' @export
rem <- function(formula, data,
                method = c("gam", "clogit", "nn"),
                case = NULL, stratum = NULL, time = NULL,
                k = NULL, bs = NULL, gam_method = NULL, nn = nn_control(), ...) {
  method <- match.arg(method)
  if (!inherits(formula, "formula")) stop("`formula` must be a formula.")
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")

  term_labels <- attr(stats::terms(formula), "term.labels")
  if (!length(term_labels)) {
    stop("`formula` must have at least one term on the right-hand side.")
  }
  terms_info <- lapply(term_labels, .parse_rem_term,
                       env = environment(formula))

  if (method == "clogit") {
    if (!requireNamespace("survival", quietly = TRUE)) {
      stop("The `survival` package is required by rem(method = \"clogit\"). ",
           "Install it with install.packages(\"survival\").")
    }
    if (any(vapply(terms_info, function(t) t$type != "linear", logical(1)))) {
      stop("method = \"clogit\" supports linear terms only; smooth terms ",
           "(tv/nl/tvnl) require method = \"gam\".")
    }
    # Resolve the event-indicator column: explicit `case`, else the formula LHS.
    if (is.null(case)) {
      if (attr(stats::terms(formula), "response") == 0L) {
        stop("method = \"clogit\" needs a 0/1 event indicator: put it on the ",
             "formula's left-hand side (e.g. `event ~ x`), or pass `case`.")
      }
      case <- all.vars(formula)[1L]
    }
    ci <- data[[case]]
    if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
    strat <- .derive_stratum(data, case, stratum)
    vars <- vapply(terms_info, function(t) t$var, character(1))
    miss <- setdiff(vars, names(data))
    if (length(miss)) {
      stop("Covariate column(s) not found in `data`: ", paste(miss, collapse = ", "))
    }
    cl <- data.frame(.case = as.integer(ci), .strat = strat,
                     stringsAsFactors = FALSE)
    for (v in vars) cl[[v]] <- data[[v]]
    fm <- stats::as.formula(paste0(
      ".case ~ ", paste(sprintf("`%s`", vars), collapse = " + "),
      " + strata(.strat)"))
    fit <- survival::clogit(fm, data = cl)
    return(structure(
      list(fit = fit, method = method, formula = formula,
           terms = terms_info, n = nrow(data), gam_formula = fm),
      class = "rem"))
  }

  if (method == "nn") {
    if (any(vapply(terms_info, function(t) t$type != "linear", logical(1)))) {
      stop("method = \"nn\" takes bare covariate names only; the network ",
           "learns nonlinearities itself (tv/nl/tvnl/re are for method = \"gam\").")
    }
    if (!inherits(nn, "nn_control")) {
      stop("`nn` must be an nn_control() object.")
    }
    # Same indicator resolution as clogit: explicit `case`, else formula LHS.
    if (is.null(case)) {
      if (attr(stats::terms(formula), "response") == 0L) {
        stop("method = \"nn\" needs a 0/1 event indicator: put it on the ",
             "formula's left-hand side (e.g. `event ~ x`), or pass `case`.")
      }
      case <- all.vars(formula)[1L]
    }
    ci <- data[[case]]
    if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
    strat <- .derive_stratum(data, case, stratum)
    vars <- vapply(terms_info, function(t) t$var, character(1))
    miss <- setdiff(vars, names(data))
    if (length(miss)) {
      stop("Covariate column(s) not found in `data`: ", paste(miss, collapse = ", "))
    }
    non_num <- vars[!vapply(data[vars], is.numeric, logical(1))]
    if (length(non_num)) {
      stop("method = \"nn\" needs numeric covariates; non-numeric: ",
           paste(non_num, collapse = ", "),
           ". Encode factors numerically (e.g. model.matrix) first.")
    }
    X <- as.matrix(data[, vars, drop = FALSE]); storage.mode(X) <- "double"
    fit <- .rem_nn_fit(X, strat, as.integer(ci) == 1L, nn, vars)
    return(structure(
      list(fit = fit, method = method, formula = formula,
           terms = terms_info, n = nrow(data), gam_formula = NULL),
      class = "rem"))
  }

  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("The `mgcv` package is required by rem(method = \"gam\"). ",
         "Install it with install.packages(\"mgcv\").")
  }

  # Guard against long-format data reaching the wide `gam` backend (issue #93).
  # The gam design is case-1-control: one row per case, each covariate supplied
  # as an event-minus-control difference. If a 0/1 indicator column
  # (`event`/`IS_OBSERVED`) with control rows is present, `data` is a long
  # case-control log; fitting it directly would silently misread the raw
  # per-row covariate values as differences. Auto-widen (loudly) instead.
  ind_cand <- intersect(c("event", "IS_OBSERVED"), names(data))
  if (length(ind_cand)) {
    ind <- ind_cand[1L]
    iv <- suppressWarnings(as.integer(data[[ind]]))
    if (any(!is.na(iv) & iv == 0L)) {
      message("rem(method = \"gam\"): `data` looks long-format (column '", ind,
              "' contains control rows); widening it with ",
              "widen_case_control() before fitting. Pass already-wide data ",
              "(one row per case) to silence this.")
      data <- widen_case_control(data, case = ind, stratum = stratum)
      stratum <- NULL
    }
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
  # Event and control times as an n x 2 matrix. One `time` column gives both
  # rows of a stratum the same time; `<time>_ev` / `<time>_nv` (wide output of
  # time-shifted sampling) give the control its own time.
  time_pair <- function(col) {
    one <- data[[col]]
    if (!is.null(one)) return(cbind(case = as.numeric(one), ctrl = as.numeric(one)))
    ev <- data[[paste0(col, "_ev")]]; nv <- data[[paste0(col, "_nv")]]
    if (!is.null(ev) && !is.null(nv)) return(cbind(case = as.numeric(ev), ctrl = as.numeric(nv)))
    NULL
  }
  get_time <- function() {
    if (is.null(time)) stop("`time` (a column name) is required for tv/tvnl terms.")
    tp <- time_pair(time)
    if (is.null(tp)) {
      stop("time column '", time, "' not found in `data` (looked for '", time,
           "' and '", time, "_ev'/'", time, "_nv').")
    }
    tp
  }
  get_time_trans <- function() {
    tp <- time_pair("transformed_time")
    if (is.null(tp)) get_time() else tp
  }

  reserved <- c("one", ".I", ".time", ".T", ".TP")
  df <- list(one = rep(1, n), .I = cbind(case = rep(1, n), ctrl = rep(-1, n)))
  rhs <- character(0)
  # Basis arguments for one smooth term: the term's own, then the global k/bs.
  smooth_args <- function(ti) {
    a <- ti$args
    if (is.null(a$k) && !is.null(k)) a$k <- k
    if (is.null(a$bs) && !is.null(bs)) a$bs <- bs
    if (!length(a)) return("")
    paste0(", ", paste(names(a), vapply(a, .deparse_arg, character(1)),
                       sep = " = ", collapse = ", "))
  }
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
    } else if (ti$type == "tv") {
      tp <- get_time()
      if (all(tp[, 1] == tp[, 2])) {
        # Shared time: beta(t) * (x_ev - x_nv).
        df[[v]] <- get_diff(v); need_time <- TRUE
        rhs <- c(rhs, sprintf("s(%s, by = %s%s)", bt(".time"), bt(v), smooth_args(ti)))
      } else {
        # Shifted control: beta(t) * x_ev - beta(t*) * x_nv, a by-matrix smooth
        # over the event and control times.
        ev <- data[[paste0(v, "_ev")]]; nv <- data[[paste0(v, "_nv")]]
        if (is.null(ev) || is.null(nv)) {
          stop("tv(", v, ") with different event and control times needs '",
               v, "_ev' and '", v, "_nv' columns.")
        }
        xi <- paste0(".XI_", v)
        df[[xi]] <- cbind(case = as.numeric(ev), ctrl = -as.numeric(nv))
        df[[".TP"]] <- tp
        rhs <- c(rhs, sprintf("s(%s, by = %s%s)", bt(".TP"), bt(xi), smooth_args(ti)))
      }
    } else if (ti$type == "nl") {
      xc <- paste0(".X_", v); df[[xc]] <- get_evnv(v)
      rhs <- c(rhs, sprintf("s(%s, by = %s%s)", bt(xc), bt(".I"), smooth_args(ti)))
    } else if (ti$type == "tvnl") {
      xc <- paste0(".X_", v); df[[xc]] <- get_evnv(v); need_ttrans <- TRUE
      rhs <- c(rhs, sprintf("te(%s, %s, by = %s%s)",
                            bt(".T"), bt(xc), bt(".I"), smooth_args(ti)))
    } else if (ti$type == "re") {
      # Actor (or other grouping) random effect, matching the matched
      # case-control construction of the REM tutorial (Intro-to-REM, 3.4): an
      # n x 2 factor matrix holding the grouping level of the event in column 1
      # and of the matched control in column 2, with by = cbind(1, -1), so the
      # term contributes f(event_level) - f(control_level) -- identifiable
      # whenever the event and control differ on this grouping.
      ev <- data[[paste0(v, "_ev")]]; nv <- data[[paste0(v, "_nv")]]
      if (is.null(ev) || is.null(nv)) {
        single <- data[[v]]
        if (is.null(single)) {
          stop("Cannot find columns for the re() term '", v, "' (looked for '",
               v, "_ev'/'", v, "_nv' or '", v, "').")
        }
        ev <- single; nv <- single
      }
      fmat <- factor(c(as.character(ev), as.character(nv)))
      dim(fmat) <- c(n, 2L)
      rc <- paste0(".RE_", v); df[[rc]] <- fmat
      rhs <- c(rhs, sprintf("s(%s, by = %s, bs = \"re\")", bt(rc), bt(".I")))
    }
  }
  if (need_time)   df[[".time"]] <- get_time()[, 1]
  if (need_ttrans) df[[".T"]] <- get_time_trans()

  fm <- stats::as.formula(paste("one ~ -1 +", paste(rhs, collapse = " + ")))
  # Smoothness-selection method passed to mgcv::gam(). Default NULL lets mgcv
  # use its own default ("GCV.Cp"), which reproduces the Intro-to-REM tutorial
  # parameterization (see issue #88). Set gam_method = "REML" to recover the
  # REML fit used in some papers.
  gam_args <- list(formula = fm, family = stats::binomial(), data = df)
  if (!is.null(gam_method)) gam_args$method <- gam_method
  fit <- do.call(mgcv::gam, gam_args)
  # mgcv drops rows with missing values; record which rows the fit used so that
  # gof_rem() and other consumers of `data` stay aligned with the fit.
  rows <- rep(TRUE, n)
  if (length(fit$na.action)) {
    rows[as.integer(fit$na.action)] <- FALSE
    warning(sum(!rows), " of ", n, " rows have missing covariate values and were ",
            "left out of the fit.", call. = FALSE)
  }

  structure(
    list(fit = fit, method = method, formula = formula,
         terms = terms_info, n = sum(rows), rows = rows, gam_formula = fm, time = time),
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

#' @export
predict.rem <- function(object, ...) stats::predict(object$fit, ...)

# Parse one formula term label. `tv(x, ...)`, `nl(x, ...)`, `tvnl(x, ...)` and
# `re(x)` become list(type, var, args), where `args` holds the named basis
# arguments evaluated in `env`; anything else is a linear term named by its label.
.parse_rem_term <- function(lbl, env = parent.frame()) {
  linear <- list(type = "linear", var = lbl, args = list())
  expr <- tryCatch(str2lang(lbl), error = function(e) NULL)
  if (!is.call(expr) || !is.name(expr[[1L]])) return(linear)
  type <- as.character(expr[[1L]])
  if (!type %in% c("tv", "nl", "tvnl", "re")) return(linear)

  call_args <- as.list(expr)[-1L]
  nms <- names(call_args)
  if (is.null(nms)) nms <- rep("", length(call_args))
  unnamed <- which(!nzchar(nms))
  if (length(unnamed) != 1L || unnamed != 1L) {
    stop("`", lbl, "`: give the covariate as the first argument and any ",
         "basis settings as named arguments, e.g. ", type, "(x, k = 10).")
  }
  v <- call_args[[1L]]
  if (!(is.name(v) || (is.character(v) && length(v) == 1L))) {
    stop("`", lbl, "`: the first argument must be a column name.")
  }
  args <- call_args[-1L]
  if (type == "re" && length(args)) {
    stop("`", lbl, "`: re() takes no further arguments (its basis is bs = \"re\").")
  }
  if ("by" %in% names(args)) {
    stop("`", lbl, "`: `by` is set by rem() and cannot be given in the term.")
  }
  args <- lapply(args, eval, envir = env)
  list(type = type, var = as.character(v), args = args)
}

# Render an evaluated argument value back into formula source.
.deparse_arg <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")

# Derive the case-control stratum vector aligned to data's rows.
# If `stratum` names a column, use it (forward-filling blanks, since eventnet
# leaves the stratum id empty on control rows). With `stratum = NULL`, use the
# `stratum` column that sample_non_events() writes when there is one -- rows
# reordered by time (endogenous_features() sorts them, and shifted controls
# have their own times) no longer keep each case next to its controls --
# and otherwise derive it as cumsum(case == 1), which labels each
# case-then-controls block.
.derive_stratum <- function(data, case, stratum) {
  if (is.null(stratum) && "stratum" %in% names(data)) stratum <- "stratum"
  if (!is.null(stratum)) {
    if (is.null(data[[stratum]])) {
      stop("stratum column '", stratum, "' not found in `data`.")
    }
    s <- as.character(data[[stratum]])
    blank <- is.na(s) | !nzchar(s)
    if (any(blank)) {                       # forward-fill from the case rows
      last <- NA_character_
      for (i in seq_along(s)) {
        if (!blank[i]) last <- s[i]
        s[i] <- last
      }
      if (anyNA(s)) {
        stop("Could not fill stratum for some rows; the first row must be a ",
             "case, or pass a fully populated `stratum` column.")
      }
    }
    return(s)
  }
  ci <- data[[case]]
  if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
  cumsum(as.integer(ci) == 1L)
}
