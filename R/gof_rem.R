#' Goodness of fit for a fitted relational event model
#'
#' Cumulative martingale-residual tests for a model fitted with
#' `rem(method = "gam")`, following Boschi & Wit (2025). The test works on the
#' fit itself, so it covers linear and smooth (`nl`, `tv`, `tvnl`) terms and the
#' penalised estimates `rem()` returns. The null distribution comes from a
#' multiplier bootstrap that subtracts the drift due to estimating the
#' coefficients, rather than from the asymptotic Brownian bridge used by
#' [gof_univariate()] and its siblings, which refit a linear model from the
#' event log.
#'
#' @section Tests:
#' \describe{
#'   \item{`"time"`}{The residual process of `term`'s columns, cumulated over
#'     event time. Detects an effect that changes over time when the model
#'     holds it constant.}
#'   \item{`"functional_form"`}{The residual process cumulated over the
#'     empirical quantiles of the covariate, pooling event and control values:
#'     at each quantile \eqn{u} the increment is
#'     \eqn{I(x_{ev} \le x_{(u)}) - I(x_{nv} \le x_{(u)})}{I(x_ev <= x_(u)) - I(x_nv <= x_(u))}.
#'     Detects a wrong shape of the covariate effect, e.g. a linear term fitted
#'     to a non-linear effect.}
#'   \item{`"functional_form_score"`}{As `"functional_form"`, with each
#'     indicator weighted by the term's basis evaluated at the event and at the
#'     control. Supported for linear and `nl()` terms.}
#' }
#' The statistic is the supremum over the grid of the absolute process
#' (`"functional_form"`) or of its Euclidean norm across the term's columns
#' (the other two tests); the p-value is the share of bootstrap replicates
#' whose supremum is at least as large.
#'
#' @param fit A `rem` object fitted with `method = "gam"`.
#' @param term Name of the covariate to test, as written in the `rem()`
#'   formula (e.g. `"x"` for `x`, `nl(x)` or `tv(x)`).
#' @param test Which process to test; see *Tests*.
#' @param data The wide data the model was fitted on. Needed for linear terms
#'   (to read `<term>_ev` / `<term>_nv`) and for `test = "time"` (to read the
#'   event times); `nl()` terms carry their event and control values in the
#'   fit.
#' @param time Name of the event-time column in `data`; defaults to the `time`
#'   argument of the `rem()` call. A column `<time>_ev` is used when `<time>`
#'   is absent.
#' @param n_sim Number of bootstrap replicates.
#' @param max_grid Maximum number of grid points of the process.
#' @param seed Optional seed for the bootstrap multipliers; the caller's random
#'   number state is restored afterwards.
#'
#' @return An object of class `"rem_gof"`: a list with `p_value`, `statistic`,
#'   the bootstrap suprema `statistic_sim`, the observed process `process`, the
#'   bootstrap processes `process_sim` (grid points x replicates), the grid
#'   (`x`, and `u` on the quantile scale), `test` and `term`. It has `print()`
#'   and `plot()` methods; `plot(x, n_show = 20, main = NULL, legend =
#'   "topright")` draws the observed process against `n_show` bootstrap
#'   processes, with the legend at a [graphics::legend()] position or none
#'   (`legend = NULL`).
#'
#' @references
#' Boschi M, Wit EC (2025). Goodness-of-fit tests for relational event models
#' based on cumulative martingale residuals. *Statistics and Computing* 36, 4.
#' \doi{10.1007/s11222-025-10751-2}.
#'
#' @seealso [rem()], [gof_univariate()], [martingale_residuals()].
#'
#' @examples
#' set.seed(1)
#' w <- simulate_relational_events(
#'   n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
#'   n_controls = 1, endogenous_stats = "reciprocity_count",
#'   endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
#' fit <- rem(~ reciprocity_count, data = w, method = "gam", time = "time")
#' g <- gof_rem(fit, "reciprocity_count", test = "functional_form", data = w,
#'              n_sim = 500, seed = 1)
#' g
#' plot(g)
#' @export
gof_rem <- function(fit, term,
                    test = c("time", "functional_form", "functional_form_score"),
                    data = NULL, time = NULL, n_sim = 2000, max_grid = 500,
                    seed = NULL) {
  # keep the rows the fit used (rem() leaves out rows with missing values)
  if (!is.null(data) && !is.null(fit$rows) && NROW(data) == length(fit$rows) && !all(fit$rows))
    data <- data[fit$rows, , drop = FALSE]
  test <- match.arg(test)
  if (!inherits(fit, "rem") || !identical(fit$method, "gam")) {
    stop("`fit` must be a rem() fit with method = \"gam\".")
  }
  if (!is.character(term) || length(term) != 1L) {
    stop("`term` must be a single covariate name.")
  }
  ti <- Filter(function(t) identical(t$var, term), fit$terms)
  if (!length(ti)) {
    stop("'", term, "' is not a term of the model (terms: ",
         paste(vapply(fit$terms, `[[`, "", "var"), collapse = ", "), ").")
  }
  ti <- ti[[1L]]
  gfit <- fit$fit
  if (is.null(gfit$Vp)) stop("The gam fit has no Vp matrix.")

  X <- stats::model.matrix(gfit)
  n <- nrow(X)
  cols <- .gof_rem_cols(gfit, X, ti)

  # Score contributions of the degenerate logistic fit.
  mu <- gfit$fitted.values
  eta <- gfit$linear.predictors
  mu_eta <- gfit$family$mu.eta(eta)
  w <- mu_eta * (gfit$y - mu) / (gfit$sig2 * gfit$family$variance(mu))
  U <- X * w
  Vp <- gfit$Vp                      # (I + S)^{-1}, the penalised inverse information
  U_hat <- colSums(U)

  grid <- switch(test,
    time = {
      tt <- .gof_rem_times(fit, data, time)
      .gof_rem_time_grid(X[, cols, drop = FALSE], tt, max_grid)
    },
    functional_form = {
      xv <- .gof_rem_values(fit, ti, data)
      .gof_rem_cov_grid(xv$ev, xv$nv, NULL, NULL, max_grid)
    },
    functional_form_score = {
      xv <- .gof_rem_values(fit, ti, data)
      h <- .gof_rem_basis(gfit, ti, xv)
      .gof_rem_cov_grid(xv$ev, xv$nv, h$ev, h$nv, max_grid)
    })

  if (!is.null(seed)) {
    withr::local_preserve_seed()
    set.seed(seed)
  }
  # Observed process, minus the drift from estimating the coefficients.
  B_list <- lapply(grid$phi, function(phi) t(mu_eta * X) %*% phi)
  G_obs <- do.call(cbind, Map(function(phi, B) {
    drift <- as.vector(t(B) %*% Vp %*% U_hat)
    (as.vector(w %*% phi) - drift) / sqrt(n)
  }, grid$phi, B_list))
  # Multiplier bootstrap of the same process, estimation effect included.
  Gm <- matrix(stats::rnorm(n * n_sim), n, n_sim)
  corr_Gm <- t(U %*% Vp) %*% Gm
  G_sim <- Map(function(phi, B) (t(phi) %*% (w * Gm) - t(B) %*% corr_Gm) / sqrt(n),
               grid$phi, B_list)

  if (test == "functional_form") {
    norm_obs <- abs(G_obs[, 1])
    norm_sim <- abs(G_sim[[1]])
  } else {
    norm_obs <- sqrt(rowSums(G_obs^2))
    norm_sim <- sqrt(Reduce(`+`, lapply(G_sim, function(g) g^2)))
  }
  T_obs <- max(norm_obs)
  T_sim <- apply(norm_sim, 2, max)

  structure(
    list(p_value = mean(T_sim >= T_obs), statistic = T_obs,
         statistic_sim = T_sim, process = norm_obs, process_sim = norm_sim,
         x = grid$x, u = grid$u, test = test, term = term, n = n,
         n_sim = n_sim),
    class = "rem_gof")
}

# Model-matrix columns of a rem() term.
.gof_rem_cols <- function(gfit, X, ti) {
  v <- ti$var
  if (ti$type == "linear") {
    idx <- which(colnames(X) == v)
    if (!length(idx)) stop("No model-matrix column for the linear term '", v, "'.")
    return(idx)
  }
  keys <- c(paste0(".X_", v), paste0(".RE_", v))
  for (s in gfit$smooth) {
    if (any(s$term %in% keys) || s$by %in% c(v, paste0(".XI_", v))) {
      return(s$first.para:s$last.para)
    }
  }
  stop("No smooth term found for '", v, "'.")
}

# Event time of each row (the case's time).
.gof_rem_times <- function(fit, data, time) {
  if (is.null(time)) time <- fit$time
  if (is.null(data) || is.null(time)) {
    stop("test = \"time\" needs `data` and a time column (`time`, or the ",
         "`time` used in rem()).")
  }
  tt <- data[[time]]
  if (is.null(tt)) tt <- data[[paste0(time, "_ev")]]
  if (is.null(tt)) stop("time column '", time, "' not found in `data`.")
  if (length(tt) != fit$n) stop("`data` does not have the rows the model was fitted on.")
  as.numeric(tt)
}

# Event and control values of the covariate.
.gof_rem_values <- function(fit, ti, data) {
  v <- ti$var
  if (ti$type %in% c("nl", "tvnl")) {
    m <- fit$fit$model[[paste0(".X_", v)]]
    return(list(ev = as.numeric(m[, 1]), nv = as.numeric(m[, 2])))
  }
  if (is.null(data)) stop("This test needs `data` to read '", v, "_ev' / '", v, "_nv'.")
  ev <- data[[paste0(v, "_ev")]]; nv <- data[[paste0(v, "_nv")]]
  if (is.null(ev) || is.null(nv)) {
    stop("This test needs the event and control values '", v, "_ev' / '", v,
         "_nv' in `data`.")
  }
  if (length(ev) != fit$n) stop("`data` does not have the rows the model was fitted on.")
  list(ev = as.numeric(ev), nv = as.numeric(nv))
}

# The term's basis at the event and at the control value.
.gof_rem_basis <- function(gfit, ti, xv) {
  if (ti$type == "linear") return(list(ev = cbind(xv$ev), nv = cbind(xv$nv)))
  if (ti$type != "nl") {
    stop("test = \"functional_form_score\" supports linear and nl() terms.")
  }
  xc <- paste0(".X_", ti$var)
  sm <- Filter(function(s) xc %in% s$term, gfit$smooth)[[1L]]
  one <- rep(1, length(xv$ev))
  at <- function(x) {
    d <- data.frame(x, one); names(d) <- c(xc, sm$by)
    mgcv::PredictMat(sm, d)
  }
  list(ev = at(xv$ev), nv = at(xv$nv))
}

.gof_rem_thin <- function(x, max_grid) {
  x <- sort(unique(x))
  if (length(x) > max_grid) x <- x[unique(round(seq(1, length(x), length.out = max_grid)))]
  x
}

.gof_rem_time_grid <- function(delta_h, times, max_grid) {
  x <- .gof_rem_thin(times, max_grid)
  ind <- outer(times, x, "<=")
  list(x = x, u = stats::ecdf(times)(x),
       phi = lapply(seq_len(ncol(delta_h)), function(k) ind * delta_h[, k]))
}

.gof_rem_cov_grid <- function(x_ev, x_nv, h_ev, h_nv, max_grid) {
  pooled <- c(x_ev, x_nv)
  x <- .gof_rem_thin(pooled, max_grid)
  ind_ev <- outer(x_ev, x, "<=")
  ind_nv <- outer(x_nv, x, "<=")
  phi <- if (is.null(h_ev)) list(ind_ev - ind_nv)
         else lapply(seq_len(ncol(h_ev)), function(k) ind_ev * h_ev[, k] - ind_nv * h_nv[, k])
  list(x = x, u = stats::ecdf(pooled)(x), phi = phi)
}

#' @export
print.rem_gof <- function(x, ...) {
  label <- switch(x$test,
    time = "time specification",
    functional_form = "functional form",
    functional_form_score = "functional form (score)")
  cat("Martingale-residual GoF test of '", x$term, "': ", label, "\n", sep = "")
  cat(sprintf("  sup statistic = %.4f, p-value = %.4f (%d bootstrap replicates, n = %d)\n",
              x$statistic, x$p_value, x$n_sim, x$n))
  invisible(x)
}

#' @export
plot.rem_gof <- function(x, n_show = 20, main = NULL, legend = "topright", ...) {
  if (is.null(main)) main <- sprintf("%s: %s", x$term, x$test)
  k <- seq_len(min(n_show, ncol(x$process_sim)))
  xs <- if (x$test == "time") x$x else x$u
  xlab <- if (x$test == "time") "event time" else "quantile of the covariate"
  graphics::matplot(xs, x$process_sim[, k, drop = FALSE], type = "l", lty = 1,
                    col = "grey80",
                    ylim = c(0, 1.3 * max(x$process, x$process_sim[, k])),
                    xlab = xlab, ylab = "|cumulative residual process|",
                    main = main, ...)
  graphics::lines(xs, x$process, lwd = 2)
  if (!is.null(legend)) graphics::legend(legend, bty = "n",
                   legend = c("observed", "bootstrap", sprintf("p = %.3f", x$p_value)),
                   col = c("black", "grey70", NA), lwd = c(2, 1, NA))
  invisible(x)
}
