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
#'     `plot(type = "pdp")` shows per-feature curves. Trained by the built-in
#'     R engine, or by \pkg{torch} with `nn_control(engine = "torch")`.}
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
#'     species-invasiveness term). Needs both `x_ev` and `x_nv` (as written
#'     by [widen_case_control()]); a single column `x` is an error, since it
#'     gives the event and its control the same level and the term would be
#'     zero. Identified only when the event and control differ on `x`.
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
#' The event indicator may be numeric or integer 0/1, logical, or a character
#' or factor column with values `"0"`/`"1"` or `"FALSE"`/`"TRUE"`; it is read
#' by value, and any other value is an error.
#'
#' `offset()` terms enter the linear predictor with coefficient 1. For
#' `clogit` the expression is evaluated on the rows of `data`, as in
#' [survival::clogit()]. For `gam` it must name a column, `offset(o)`, which is
#' resolved like a linear term (an event-minus-control difference: column `o`,
#' else `d_o`, else `o_ev - o_nv`). The `nn` method does not take offsets.
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
#' Fits from `amorem` have class `"amorem_rem"`, which the other two packages
#' do not use, so their S3 methods for class `"rem"` never apply to them. When
#' more than one of these packages is attached, call `amorem::rem()`
#' explicitly.
#'
#' @param formula A formula; see *Formula syntax*.
#' @param data A data.frame of preprocessed case-control data (wide for the
#'   `gam` method; long with a case indicator and stratum for `clogit`). For
#'   `method = "gam"`, long case-control input (a `event`/`IS_OBSERVED`
#'   indicator with control rows) is detected and widened automatically via
#'   [widen_case_control()], with a message. The `gam` design pairs each case
#'   with one control, so widening keeps the first control of each stratum;
#'   when a stratum has several controls `rem()` warns, and
#'   `method = "clogit"` uses them all.
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
#' @return An object of class `"amorem_rem"`: a list with the fitted model (`$fit`),
#'   the `method`, the original `formula`, the parsed `terms`, the number of
#'   rows used by the fit `n` and, for `gam` and `clogit`, the logical vector
#'   `rows` marking which rows of `data` (after widening, for `gam`) the fit
#'   used. `clogit` and `nn` fits also store the resolved event-indicator
#'   column `case` and the `stratum` argument. Has [summary()], [coef()],
#'   [plot()], [logLik()] and [predict()] methods. For `gam` fits,
#'   `predict(fit, newdata)` takes wide data in the form `rem()` accepts
#'   (the columns named in *Column resolution*) and returns the linear
#'   predictor of each row, event minus control; further arguments go to
#'   [mgcv::predict.gam()]. For `clogit` and `nn` fits, `predict()` passes
#'   its arguments to the fitted model's own method.
#'
#' @seealso [compare_models_smooth()] (superseded), [simulate_relational_events()]
#'   (whose `wide = TRUE` output is a valid input here),
#'   [simulate_directed_hyperevents_tvnl()].
#'
#' @importFrom survival clogit strata coxph Surv frailty
#'
#' @examples
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   set.seed(1)
#'   w <- simulate_relational_events(
#'     n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
#'     n_controls = 1, endogenous_stats = "reciprocity_count",
#'     endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
#'   fit <- rem(~ reciprocity_count, data = w, method = "gam")
#'   coef(fit)
#'   summary(predict(fit, w))
#' }
#'
#' @export
rem <- function(formula, data,
                method = c("gam", "clogit", "nn"),
                case = NULL, stratum = NULL, time = NULL,
                k = NULL, bs = NULL, gam_method = NULL, nn = nn_control(), ...) {
  method <- match.arg(method)
  if (!inherits(formula, "formula")) stop("`formula` must be a formula.")
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")

  tt <- stats::terms(formula)
  term_labels <- attr(tt, "term.labels")
  if (!length(term_labels)) {
    stop("`formula` must have at least one term on the right-hand side.")
  }
  terms_info <- lapply(term_labels, .parse_rem_term,
                       env = environment(formula))
  offsets <- .rem_offsets(tt)

  if (method == "clogit") {
    if (!requireNamespace("survival", quietly = TRUE)) {
      stop("The `survival` package is required by rem(method = \"clogit\"). ",
           "Install it with install.packages(\"survival\").")
    }
    if (any(vapply(terms_info, function(t) t$type != "linear", logical(1)))) {
      stop("method = \"clogit\" supports linear terms only; smooth terms ",
           "(tv/nl/tvnl) require method = \"gam\".")
    }
    case <- .rem_case_name(formula, case, method)
    ci <- data[[case]]
    if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
    ci <- .as_event01(ci, case)
    strat <- .derive_stratum(data, case, stratum)
    vars <- vapply(terms_info, function(t) t$var, character(1))
    miss <- setdiff(vars, names(data))
    if (length(miss)) {
      stop("Covariate column(s) not found in `data`: ", paste(miss, collapse = ", "))
    }
    cl <- data.frame(.case = ci, .strat = strat, stringsAsFactors = FALSE)
    for (v in vars) cl[[v]] <- data[[v]]
    rhs <- c(sprintf("`%s`", vars), "strata(.strat)")
    if (length(offsets)) {
      # offset(expr) is evaluated on the rows of `data`, as survival::clogit does.
      off <- Reduce(`+`, lapply(offsets, function(e) {
        as.numeric(eval(e, data, environment(formula)))
      }))
      if (length(off) == 1L) off <- rep(off, nrow(data))
      cl[[".offset"]] <- off
      rhs <- c(rhs, "offset(.offset)")
    }
    fm <- stats::as.formula(paste(".case ~", paste(rhs, collapse = " + ")))
    fit <- survival::clogit(fm, data = cl)
    rows <- .rem_rows_used(fit$na.action, nrow(data))
    return(structure(
      list(fit = fit, method = method, formula = formula,
           terms = terms_info, n = sum(rows), rows = rows, gam_formula = fm,
           case = case, stratum = stratum),
      class = "amorem_rem"))
  }

  if (method == "nn") {
    if (any(vapply(terms_info, function(t) t$type != "linear", logical(1)))) {
      stop("method = \"nn\" takes bare covariate names only; the network ",
           "learns nonlinearities itself (tv/nl/tvnl/re are for method = \"gam\").")
    }
    if (length(offsets)) {
      stop("method = \"nn\" does not support offset() terms; use ",
           "method = \"clogit\" or \"gam\".")
    }
    if (!inherits(nn, "nn_control")) {
      stop("`nn` must be an nn_control() object.")
    }
    case <- .rem_case_name(formula, case, method)
    ci <- data[[case]]
    if (is.null(ci)) stop("case column '", case, "' not found in `data`.")
    ci <- .as_event01(ci, case)
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
    fit <- .rem_nn_fit(X, strat, ci == 1L, nn, vars)
    return(structure(
      list(fit = fit, method = method, formula = formula,
           terms = terms_info, n = nrow(data), gam_formula = NULL,
           case = case, stratum = stratum),
      class = "amorem_rem"))
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
    iv <- tryCatch(.as_event01(data[[ind]], ind), error = function(e) NULL)
    if (!is.null(iv) && any(!is.na(iv) & iv == 0L)) {
      message("rem(method = \"gam\"): `data` looks long-format (column '", ind,
              "' contains control rows); widening it with ",
              "widen_case_control() before fitting. Pass already-wide data ",
              "(one row per case) to silence this.")
      st <- .derive_stratum(data, ind, stratum)
      n_ctrl <- tabulate(match(st[!is.na(iv) & iv == 0L], unique(st)),
                         nbins = length(unique(st)))
      if (any(n_ctrl > 1L)) {
        warning("rem(method = \"gam\") uses one control per case: ",
                sum(n_ctrl > 1L), " stratum/strata have more than one control ",
                "and only the first control of each is used. Use ",
                "method = \"clogit\" to use every control.", call. = FALSE)
      }
      data <- widen_case_control(data, case = ind, stratum = stratum)
      stratum <- NULL
    }
  }

  n <- nrow(data)
  if (!n) stop("`data` has no rows.")

  des <- .rem_gam_design(data, terms_info, offsets, time = time, k = k, bs = bs)
  fm <- stats::as.formula(paste("one ~ -1 +", paste(des$rhs, collapse = " + ")))
  # Smoothness-selection method passed to mgcv::gam(). Default NULL lets mgcv
  # use its own default ("GCV.Cp"), which reproduces the Intro-to-REM tutorial
  # parameterization (see issue #88). Set gam_method = "REML" to recover the
  # REML fit used in some papers.
  gam_args <- list(formula = fm, family = stats::binomial(), data = des$df)
  if (!is.null(gam_method)) gam_args$method <- gam_method
  fit <- do.call(mgcv::gam, gam_args)
  # mgcv drops rows with missing values; record which rows the fit used so that
  # gof_rem() and other consumers of `data` stay aligned with the fit.
  rows <- .rem_rows_used(fit$na.action, n)

  structure(
    list(fit = fit, method = method, formula = formula,
         terms = terms_info, n = sum(rows), rows = rows, gam_formula = fm,
         time = time, offsets = offsets),
    class = "amorem_rem")
}

# Name of the event-indicator column: explicit `case`, else the formula's
# left-hand side.
.rem_case_name <- function(formula, case, method) {
  if (!is.null(case)) return(case)
  if (attr(stats::terms(formula), "response") == 0L) {
    stop("method = \"", method, "\" needs a 0/1 event indicator: put it on the ",
         "formula's left-hand side (e.g. `event ~ x`), or pass `case`.")
  }
  all.vars(formula)[1L]
}

# Logical vector of the rows a fit used, given its `na.action`; warns when
# rows were left out.
.rem_rows_used <- function(na_action, n) {
  rows <- rep(TRUE, n)
  if (length(na_action)) {
    rows[as.integer(na_action)] <- FALSE
    warning(sum(!rows), " of ", n, " rows have missing values and were ",
            "left out of the fit.", call. = FALSE)
  }
  rows
}

# The expressions inside the offset() terms of a terms object.
.rem_offsets <- function(tt) {
  idx <- attr(tt, "offset")
  if (is.null(idx)) return(list())
  vars <- as.list(attr(tt, "variables"))[-1L]
  lapply(vars[idx], function(e) e[[2L]])
}

# Convert an event indicator to integer 0/1 by value. Accepts numeric or
# integer 0/1, logical, and character or factor values "0"/"1" or
# "FALSE"/"TRUE" (any case). NA stays NA; anything else is an error.
.as_event01 <- function(x, name = "event") {
  bad <- function() {
    stop("event indicator '", name, "' must hold 0/1 values (numeric, ",
         "logical, or character/factor \"0\"/\"1\" or \"FALSE\"/\"TRUE\").",
         call. = FALSE)
  }
  if (is.logical(x)) return(as.integer(x))
  if (is.factor(x)) x <- as.character(x)
  if (is.character(x)) {
    u <- toupper(trimws(x))
    out <- rep(NA_integer_, length(u))
    out[u %in% c("1", "TRUE")] <- 1L
    out[u %in% c("0", "FALSE")] <- 0L
    if (any(is.na(out) & !is.na(x))) bad()
    return(out)
  }
  if (is.numeric(x)) {
    if (any(!is.na(x) & !(x %in% c(0, 1)))) bad()
    return(as.integer(x))
  }
  bad()
}

# Build the internal mgcv design for the gam backend from wide data: the
# columns of the model frame (`df`) and the right-hand side terms (`rhs`).
# Used by rem() for fitting and by predict() for new data. `levels` maps a
# re() column to the factor levels of the fit, so new data are coded alike.
.rem_gam_design <- function(data, terms_info, offsets = list(), time = NULL,
                            k = NULL, bs = NULL, levels = NULL) {
  n <- nrow(data)
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

  reserved <- c("one", ".I", ".time", ".T", ".TP", ".offset")
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
        stop("Cannot find columns for the re() term '", v, "': it needs the ",
             "event and control levels in '", v, "_ev' and '", v, "_nv' (e.g. ",
             "from widen_case_control()). A single ",
             "column '", v, "' gives the event and its control the same level, ",
             "so the term would be zero.")
      }
      rc <- paste0(".RE_", v)
      lev <- levels[[rc]]
      fmat <- if (is.null(lev)) factor(c(as.character(ev), as.character(nv)))
              else factor(c(as.character(ev), as.character(nv)), levels = lev)
      dim(fmat) <- c(n, 2L)
      df[[rc]] <- fmat
      rhs <- c(rhs, sprintf("s(%s, by = %s, bs = \"re\")", bt(rc), bt(".I")))
    }
  }
  if (need_time)   df[[".time"]] <- get_time()[, 1]
  if (need_ttrans) df[[".T"]] <- get_time_trans()
  if (length(offsets)) {
    # An offset column is an event-minus-control difference, resolved like a
    # linear term ('o', else 'd_o', else 'o_ev' - 'o_nv').
    off <- lapply(offsets, function(e) {
      if (is.character(e) && length(e) == 1L) e <- as.name(e)
      if (!is.name(e)) {
        stop("method = \"gam\" takes offset(<column>) with a bare column ",
             "name; compute `", deparse(e), "` as a column (or as '<name>_ev' / ",
             "'<name>_nv') first.")
      }
      get_diff(as.character(e))
    })
    df[[".offset"]] <- Reduce(`+`, off)
    rhs <- c(rhs, "offset(.offset)")
  }
  list(df = df, rhs = rhs)
}

#' @export
print.amorem_rem <- function(x, ...) {
  cat("Relational event model (rem)\n")
  cat("  method : ", x$method, "\n", sep = "")
  cat("  formula: ", deparse(x$formula), "\n", sep = "")
  cat("  n      : ", x$n, "\n", sep = "")
  invisible(x)
}

#' @export
summary.amorem_rem <- function(object, ...) summary(object$fit, ...)

#' @export
coef.amorem_rem <- function(object, ...) stats::coef(object$fit, ...)

#' @export
plot.amorem_rem <- function(x, ...) plot(x$fit, ...)

#' @export
logLik.amorem_rem <- function(object, ...) stats::logLik(object$fit)

#' @export
predict.amorem_rem <- function(object, newdata, ...) {
  if (missing(newdata) || is.null(newdata)) return(stats::predict(object$fit, ...))
  if (!identical(object$method, "gam")) {
    return(stats::predict(object$fit, newdata, ...))
  }
  if (!is.data.frame(newdata)) stop("`newdata` must be a data.frame.")
  # Build the internal design columns from the user's wide data, as rem() does.
  re_cols <- grep("^\\.RE_", names(object$fit$model), value = TRUE)
  lev <- lapply(object$fit$model[re_cols], levels)
  des <- .rem_gam_design(newdata, object$terms, object$offsets,
                         time = object$time, levels = lev)
  stats::predict(object$fit, newdata = des$df, ...)
}

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
  ci <- .as_event01(ci, case)
  if (anyNA(ci)) {
    stop("case column '", case, "' has missing values; pass a `stratum` ",
         "column to group the rows.")
  }
  cumsum(ci == 1L)
}
