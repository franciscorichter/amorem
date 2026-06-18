#' Bootstrap uncertainty for the neural rem() backend
#'
#' Quantifies uncertainty for a `rem(method = "nn")` fit by a **stratum
#' bootstrap**: the case-control strata are resampled with replacement, the
#' network is refit on each resample (reusing the original [nn_control()]
#' settings, including the training `engine`), and the spread across refits
#' yields partial-dependence uncertainty bands and a concordance confidence
#' interval. This is the inferential counterpart that the point-prediction
#' `nn` backend otherwise lacks (`coef()` returns `NULL`).
#'
#' Each bootstrap partial-dependence curve is centred (its grid-mean removed)
#' before the pointwise quantiles are taken, so the bands describe uncertainty
#' in the *shape* of each effect, not the conditional-logit's unidentified
#' per-stratum offset.
#'
#' @param object A fitted [rem()] object with `method = "nn"`.
#' @param data The case-control data frame the model was fit on (same columns).
#' @param B Number of bootstrap resamples.
#' @param case,stratum Event-indicator and stratum columns, resolved exactly as
#'   in [rem()] (defaults: the formula's left-hand side, and
#'   `cumsum(case == 1)`).
#' @param n_grid Grid resolution for the partial-dependence curves.
#' @param level Confidence level for the bands and the concordance interval.
#' @param seed Optional integer seed for the resampling.
#'
#' @return An object of class `"nn_uncertainty"`: a per-feature list of
#'   `data.frame(x, lo, med, hi)` bands, a `concordance` quantile interval, and
#'   the settings `B`, `level`. Has `print()` and `plot()` methods.
#' @seealso [rem()], [nn_control()]
#' @export
nn_uncertainty <- function(object, data, B = 200L, case = NULL, stratum = NULL,
                           n_grid = 50L, level = 0.95, seed = NULL) {
  if (!inherits(object, "rem") || !identical(object$method, "nn")) {
    stop("`object` must be a rem(method = \"nn\") fit.", call. = FALSE)
  }
  fit <- object$fit; control <- fit$control; vars <- fit$features
  if (is.null(case)) case <- all.vars(object$formula)[1L]
  ci <- data[[case]]
  if (is.null(ci)) stop("case column '", case, "' not found in `data`.", call. = FALSE)
  strat <- .derive_stratum(data, case, stratum)
  X <- as.matrix(data[, vars, drop = FALSE]); storage.mode(X) <- "double"
  is_event <- as.integer(ci) == 1L
  strata <- unique(strat)

  mu <- colMeans(X); sdv <- apply(X, 2L, stats::sd); sdv[sdv == 0] <- 1
  grids <- lapply(seq_along(vars), function(j)
    seq(mu[j] - 2 * sdv[j], mu[j] + 2 * sdv[j], length.out = n_grid))
  names(grids) <- vars

  pdp_of <- function(f) vapply(seq_along(vars), function(j) {
    nd <- as.data.frame(matrix(rep(mu, each = n_grid), n_grid, length(vars),
                               dimnames = list(NULL, vars)))
    nd[[vars[j]]] <- grids[[j]]
    cv <- stats::predict(f, nd)
    cv - mean(cv)                                  # centre: shape, not offset
  }, numeric(n_grid))

  concord_of <- function(f) {
    sc <- stats::predict(f, as.data.frame(X))
    top <- tapply(seq_along(sc), strat, function(ix) ix[which.max(sc[ix])])
    mean(is_event[as.integer(top)])
  }

  if (!is.null(seed)) set.seed(seed)
  curves <- array(NA_real_, c(n_grid, length(vars), B))
  conc <- rep(NA_real_, B)
  for (b in seq_len(B)) {
    bs <- sample(strata, length(strata), replace = TRUE)
    rows <- unlist(lapply(bs, function(s) which(strat == s)), use.names = FALSE)
    relab <- rep(seq_along(bs),
                 times = vapply(bs, function(s) sum(strat == s), integer(1)))
    fb <- tryCatch(
      .rem_nn_fit(X[rows, , drop = FALSE], relab, is_event[rows], control, vars),
      error = function(e) NULL)
    if (is.null(fb)) next
    curves[, , b] <- pdp_of(fb)
    conc[b] <- concord_of(fb)
  }

  a <- (1 - level) / 2
  bands <- lapply(seq_along(vars), function(j) {
    cj <- matrix(curves[, j, ], n_grid, B)
    data.frame(x   = grids[[j]],
               lo  = apply(cj, 1L, stats::quantile, probs = a,     na.rm = TRUE),
               med = apply(cj, 1L, stats::quantile, probs = 0.5,   na.rm = TRUE),
               hi  = apply(cj, 1L, stats::quantile, probs = 1 - a, na.rm = TRUE))
  })
  names(bands) <- vars
  structure(list(
    bands = bands, features = vars, B = B, level = level,
    n_ok = sum(!is.na(conc)),
    concordance = stats::quantile(conc, c(a, 0.5, 1 - a), na.rm = TRUE)),
    class = "nn_uncertainty")
}

#' @export
print.nn_uncertainty <- function(x, ...) {
  cat("Bootstrap uncertainty for a neural rem() fit\n")
  cat("  resamples    : ", x$B, " (", x$n_ok, " successful)\n", sep = "")
  cat("  level        : ", sprintf("%.0f%%", 100 * x$level), "\n", sep = "")
  cat("  features     : ", paste(x$features, collapse = ", "), "\n", sep = "")
  ci <- x$concordance
  cat("  concordance  : ", sprintf("%.3f  [%.3f, %.3f]", ci[2L], ci[1L], ci[3L]),
      "\n", sep = "")
  cat("Use plot() for per-feature partial-dependence bands.\n")
  invisible(x)
}

#' Plot partial-dependence uncertainty bands
#'
#' @param x An [nn_uncertainty()] object.
#' @param ... Passed to the underlying `plot()`.
#' @return `x`, invisibly.
#' @export
plot.nn_uncertainty <- function(x, ...) {
  p <- length(x$features)
  old <- graphics::par(mfrow = grDevices::n2mfrow(p)); on.exit(graphics::par(old))
  for (j in seq_len(p)) {
    b <- x$bands[[j]]
    plot(b$x, b$med, type = "n", ylim = range(b$lo, b$hi),
         xlab = x$features[j], ylab = "centred partial score",
         main = x$features[j], ...)
    graphics::polygon(c(b$x, rev(b$x)), c(b$lo, rev(b$hi)),
                      col = grDevices::adjustcolor("steelblue", 0.25), border = NA)
    graphics::lines(b$x, b$med, col = "steelblue", lwd = 2)
    graphics::abline(h = 0, lty = 3, col = "grey50")
  }
  invisible(x)
}
