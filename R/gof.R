# Cumulative martingale residual GOF tests for relational event models,
# following Boschi & Wit (2025, Statistics & Computing). All four entry
# points draw a case-control sample (n_controls = 1, matching the paper's
# NCC m = 2 setup) and fit one linear partial-likelihood model on it; with
# n_samples > 1 they repeat this on several control samples and combine
# the p-values with the Cauchy combination.

# --- internal: Cauchy combination (Liu & Xie 2020). Returns the
# statistic T = mean(tan(pi (0.5 - p))) and its p-value 0.5 - atan(T)/pi.
# p-values are clamped inside (0, 1) so tan() does not overflow.
.gof_cauchy <- function(p) {
  p_clamped <- pmin(pmax(p, 1e-15), 1 - 1e-15)
  T_c <- mean(tan(pi * (0.5 - p_clamped)))
  list(statistic = T_c, p_value = 0.5 - atan(T_c) / pi)
}

.gof_check_n_samples <- function(n_samples) {
  if (!is.numeric(n_samples) || length(n_samples) != 1L ||
      is.na(n_samples) || n_samples < 1 ||
      n_samples != round(n_samples)) {
    stop("`n_samples` must be a positive integer.")
  }
  as.integer(n_samples)
}

# Seeds of the control samples: seed, seed + 1, ..., or NULL for every
# sample when `seed` is NULL (independent draws from the current stream).
.gof_sample_seeds <- function(seed, n_samples) {
  if (is.null(seed)) return(rep(list(NULL), n_samples))
  as.list(seed + seq_len(n_samples) - 1L)
}

# --- internal: run the single-sample test `run(seed)` on n_samples
# control samples and combine the p-values. With n_samples = 1 the
# single-sample result is returned unchanged.
.gof_over_samples <- function(run, seed, n_samples) {
  n_samples <- .gof_check_n_samples(n_samples)
  if (n_samples == 1L) return(run(seed))
  outs <- lapply(.gof_sample_seeds(seed, n_samples), run)
  p <- vapply(outs, function(x) x$p_value, numeric(1))
  res <- outs[[1L]]
  # A Monte Carlo p-value (gof_multivariate, gof_auxiliary) is a multiple
  # of 1/n_sim and can be 0; it enters the combination floored at
  # 1/(n_sim + 1), the smallest p-value n_sim replicates can resolve.
  p_comb <- if (is.null(res$n_sim)) p else pmax(p, 1 / (res$n_sim + 1))
  res$p_value <- .gof_cauchy(p_comb)$p_value
  res$p_values <- p
  res$n_samples <- n_samples
  res
}

# --- internal: fit the linear partial-likelihood model and return
# everything downstream gof_* functions need.
.gof_fit_linear <- function(event_log, model,
                             scope = "all", mode = "one",
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
    stop("Only effect type \"linear\" is supported here. Got: ",
         paste(unique(model[bad]), collapse = ", "))
  }
  stat_set <- names(model)
  cc <- sample_non_events(event_log, n_controls = 1L,
                          scope = scope, mode = mode, seed = seed)
  cc_feat <- endogenous_features(cc, stats = stat_set,
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
  D <- X_case - X_ctrl                       # n x p case-minus-control
  colnames(D) <- paste0("d_", stat_set)
  diff_df <- as.data.frame(D)
  diff_df$one <- 1
  fm <- stats::as.formula(paste("one ~",
    paste(colnames(D), collapse = " + "), "- 1"))
  fit <- stats::glm(fm, family = "binomial", data = diff_df)
  beta <- stats::coef(fit)
  names(beta) <- stat_set
  eta <- as.numeric(D %*% beta)
  fitted_p <- stats::plogis(eta)             # P(case beats control)
  list(cases = cases, ctrls = ctrls,
       stat_set = stat_set, beta = beta,
       Delta = D, fitted_p = fitted_p, fit = fit)
}

# --- internal: build the centered, normalized cumulative residual
# process Ŵ[u] on the n grid for a chosen sub-design matrix Hd
# (n x q). Used by gof_univariate (q = 1) and gof_multivariate (q > 1).
.gof_W_process <- function(Hd, fitted_p) {
  # G_k = (1 - π_k) · h_{d, k}   (NCC m = 2, eq. 13)
  resid <- 1 - fitted_p
  G_k <- Hd * resid                           # n x q
  cum <- apply(G_k, 2, cumsum)                # n x q cumulative
  # Re-center so the process ends at zero (correct under correct
  # specification at the MLE).
  n <- nrow(G_k)
  if (n == 0L) stop("Empty case-control table.")
  end_val <- cum[n, , drop = FALSE]
  u <- seq_len(n) / n
  # Subtract a linear ramp so cum_centered ends at zero -- matches the
  # "subtract the unpenalised score" step in eq. 16 (the score equals
  # the final value of the cumulative process at the MLE).
  ramp <- outer(u, as.numeric(end_val))       # n x q
  cum_centered <- cum - ramp
  # Sandwich variance estimator Ĵ = (1/n) Σ G_k G_k^T  (eq. 17).
  J <- crossprod(G_k) / n                     # q x q
  list(cum_centered = cum_centered, J = J, u = u, G_k = G_k)
}

# --- internal: matrix inverse square root via eigendecomposition with
# a small ridge so near-singular Ĵ doesn't blow up the test statistic.
.gof_inv_sqrt <- function(J, ridge = 1e-8) {
  if (length(J) == 1L) return(matrix(1 / sqrt(as.numeric(J) + ridge), 1L, 1L))
  e <- eigen(J + ridge * diag(nrow(J)), symmetric = TRUE)
  vals <- pmax(e$values, ridge)
  e$vectors %*% diag(1 / sqrt(vals)) %*% t(e$vectors)
}

# --- internal: KS distribution function for the supremum of a 1-d
# Brownian bridge. Truncated series, accurate to <1e-12 for t > 0.1.
.gof_ks_pvalue <- function(t) {
  if (!is.finite(t) || t <= 0) return(1)
  k <- seq_len(100)
  p <- 2 * sum((-1)^(k - 1) * exp(-2 * k^2 * t^2))
  max(min(p, 1), 0)
}

#' Goodness-of-fit test for a single FLE covariate
#'
#' Implements the univariate cumulative martingale residual test of
#' Boschi & Wit (2025), Section 3.3. The test statistic is
#' \eqn{T_x = \sup_u |\hat W[u]|}{T_x = sup_u |W[u]|} where
#' \eqn{\hat W[u]}{W[u]} is the normalised cumulative score process for
#' the requested covariate; under correct specification \eqn{\hat W}{W}
#' converges to a standard Brownian bridge, so the p-value follows the
#' Kolmogorov-Smirnov distribution
#' \eqn{2 \sum_{k\ge 1} (-1)^{k-1} e^{-2 k^2 t^2}}{2 sum (-1)^(k-1) exp(-2 k^2 t^2)}.
#'
#' @param event_log Dyadic event log.
#' @param model Named character vector of `<stat> = "linear"` mapping.
#' @param covariate Name of the covariate in `model` to test.
#' @param scope,mode,half_life,seed See [compare_models()].
#' @param n_samples Number of control samples (default 1). With
#'   `n_samples > 1` the test is run on `n_samples` case-control samples,
#'   drawn with seeds `seed`, `seed + 1`, ..., `seed + n_samples - 1` (or
#'   independently from the current random stream when `seed` is `NULL`),
#'   and the p-values are combined with the Cauchy combination; see
#'   *Several control samples*.
#' @return A list with `statistic` (\eqn{T_x}{T_x}), `p_value` (KS),
#'   `W` (numeric vector of length `n`, the normalised process),
#'   `u` (the time grid in `[0, 1]`) and `covariate`.
#'   With `n_samples > 1`, `p_value` is the Cauchy-combined p-value,
#'   `p_values` holds the per-sample p-values and `n_samples` their
#'   number; the other fields are those of the first sample (seed `seed`).
#'   With `n_samples = 1` the result is the single-sample result, without
#'   `p_values` or `n_samples`.
#' @section Several control samples:
#' The test is computed on one case-control sample, so its p-value depends
#' on which controls were drawn. With `n_samples` \eqn{= S > 1}{= S > 1}
#' the p-values \eqn{p_1, \dots, p_S}{p_1, ..., p_S} of the same test on
#' \eqn{S}{S} control samples are combined as
#' \deqn{T = \frac{1}{S}\sum_{s=1}^S \tan\{\pi(1/2 - p_s)\}, \qquad
#'   p = \frac{1}{2} - \frac{\arctan T}{\pi}}{T = (1/S) sum_s tan(pi (1/2 - p_s)),  p = 1/2 - atan(T)/pi}
#' (Liu & Xie 2020), the rule [gof_global()] uses across covariates. The
#' samples share the events, so the \eqn{p_s}{p_s} are dependent. The
#' Cauchy combination is valid under arbitrary dependence among the
#' \eqn{p_s}{p_s}: when each \eqn{p_s}{p_s} is uniform under the null, the
#' tail of \eqn{T}{T} is asymptotically standard Cauchy whatever their
#' dependence (Liu & Xie 2020, Theorem 1), so \eqn{p}{p} controls the size
#' at small levels; with identical samples it returns their common p-value.
#' Each \eqn{p_s}{p_s} is clamped to
#' \eqn{[10^{-15}, 1 - 10^{-15}]}{[1e-15, 1 - 1e-15]} so that the tangent
#' stays finite. The Monte Carlo p-values of [gof_multivariate()] and
#' [gof_auxiliary()] are first floored at \eqn{1/(n_{sim} + 1)}{1/(n_sim + 1)}
#' (`p_values` keeps the unfloored values). Since \eqn{T}{T} is at most
#' \eqn{\max_s \tan\{\pi(1/2 - p_s)\}}{max_s tan(pi (1/2 - p_s))}, the
#' combined p-value is then at least \eqn{1/(n_{sim} + 1)}{1/(n_sim + 1)}:
#' a combined p-value equal to that bound means
#' \eqn{p < 1/n_{sim}}{p < 1/n_sim} in every sample, and a smaller
#' p-value needs a larger `n_sim`. The Kolmogorov p-values of
#' [gof_univariate()] and [gof_global()] are analytic and are not floored.
#'
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#'
#'   Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
#'   analytic p-value calculation under arbitrary dependency structures.
#'   *Journal of the American Statistical Association* 115(529),
#'   393--402. \doi{10.1080/01621459.2018.1554485}.
#' @examples
#' \donttest{
#' data(simulated_events)
#' gof_univariate(simulated_events,
#'   model = c(reciprocity_count  = "linear",
#'             transitivity_count = "linear"),
#'   covariate = "reciprocity_count", seed = 1)
#' # the same test on 5 control samples, p-values Cauchy-combined
#' gof_univariate(simulated_events,
#'   model = c(reciprocity_count  = "linear",
#'             transitivity_count = "linear"),
#'   covariate = "transitivity_count", seed = 1,
#'   n_samples = 5)[c("p_value", "p_values")]
#' }
#' @export
gof_univariate <- function(event_log, model, covariate,
                            scope = "all", mode = "one",
                            half_life = NULL, seed = NULL,
                            n_samples = 1) {
  .gof_over_samples(function(sd) {
    .gof_univariate_one(event_log, model, covariate, scope, mode,
                        half_life, sd)
  }, seed, n_samples)
}

.gof_univariate_one <- function(event_log, model, covariate,
                                scope, mode, half_life, seed) {
  prep <- .gof_fit_linear(event_log, model, scope, mode, half_life, seed)
  if (!covariate %in% prep$stat_set) {
    stop("`covariate` must be one of: ",
         paste(prep$stat_set, collapse = ", "))
  }
  d <- match(covariate, prep$stat_set)
  Hd <- prep$Delta[, d, drop = FALSE]
  w  <- .gof_W_process(Hd, prep$fitted_p)
  inv_sq <- .gof_inv_sqrt(w$J)
  n <- nrow(Hd)
  W <- as.numeric((w$cum_centered / sqrt(n)) %*% inv_sq)
  T_x <- max(abs(W))
  list(statistic = T_x,
       p_value   = .gof_ks_pvalue(T_x),
       W         = W,
       u         = w$u,
       covariate = covariate)
}

#' Multivariate GOF test for smooth or random-effect covariates
#'
#' Multivariate cumulative-residual test of Boschi & Wit (2025),
#' Section 3.4, for the functional form of one covariate. The covariate's
#' effect is expanded in `q = k_basis - 1` event-minus-control columns
#' \eqn{h_i}{h_i} of a thin-plate spline basis (`mgcv::s()`), and the
#' model with these columns and the other covariates linear is refitted
#' without penalty. It contains the linear effect, so it is correct under
#' the null. With its fitted probabilities \eqn{\pi_i}{pi_i}, design rows
#' \eqn{x_i}{x_i}, inverse information
#' \eqn{V = (X^\top W X)^{-1}}{V = (X'WX)^-1}, \eqn{W = \mathrm{diag}\{\pi_i(1-\pi_i)\}}{W = diag(pi_i (1 - pi_i))},
#' and score \eqn{\hat U = \sum_i (1-\pi_i) x_i = 0}{U = sum (1 - pi_i) x_i = 0},
#' the process is
#' \deqn{W(u) = M^{-1/2} \hat J^{-1/2} \Bigl\{\sum_{i \le uM} (1-\pi_i) h_i
#'   - A(u) V \hat U\Bigr\},\qquad
#'   A(u) = \sum_{i \le uM} \pi_i (1-\pi_i) h_i x_i^\top,}{W(u) = M^(-1/2) J^(-1/2) { sum_{i <= uM} (1 - pi_i) h_i - A(u) V U },  A(u) = sum_{i <= uM} pi_i (1 - pi_i) h_i x_i',}
#' with \eqn{\hat J = M^{-1}\sum_i (1-\pi_i)^2 h_i h_i^\top}{J = M^-1 sum (1 - pi_i)^2 h_i h_i'},
#' and the statistic is \eqn{T_\psi = \sup_u \lVert W(u)\rVert^2}{T_psi = sup_u ||W(u)||^2}.
#' The second term is zero at the estimate and is written for the
#' replicates, in which it carries the effect of estimating the
#' coefficients. The
#' p-value is the share of `n_sim` multiplier replicates
#' \deqn{W^*(u) = M^{-1/2} \hat J^{-1/2} \Bigl\{\sum_{i \le uM} g_i (1-\pi_i) h_i
#'   - A(u) V \sum_i g_i (1-\pi_i) x_i\Bigr\},\qquad g_i \sim N(0, 1),}{W*(u) = M^(-1/2) J^(-1/2) { sum_{i <= uM} g_i (1 - pi_i) h_i - A(u) V sum_i g_i (1 - pi_i) x_i },  g_i ~ N(0, 1),}
#' with \eqn{\sup_u \lVert W^*(u)\rVert^2 \ge T_\psi}{sup ||W*||^2 >= T_psi}
#' (Lin, Wei & Ying 1993, as in [gof_rem()]).
#'
#' The limit of \eqn{W}{W} is a Gaussian process with covariance set by
#' how the information \eqn{A(u)}{A(u)} accumulates over the event
#' sequence. It is a standard \eqn{q}{q}-dimensional Brownian bridge only
#' when \eqn{A(u)}{A(u)} grows in proportion to \eqn{u}{u} in every
#' direction, which fails for the spline columns of a statistic that grows
#' over the sequence (a count): the columns for large values receive their
#' information late. The multiplier replicates have the covariance of the
#' limit whatever the growth of \eqn{A(u)}{A(u)}.
#'
#' @param event_log Dyadic event log.
#' @param model Named character vector of `<stat> = "linear"` mapping
#'   (for the rest of the model); the test target is `covariate` with
#'   a flexible smooth basis of dimension `k_basis - 1`.
#' @param covariate Name of the covariate to test under a smooth effect.
#' @param k_basis Spline-basis dimension for `covariate` (passed as `k`
#'   to `mgcv::s()`; the resulting design matrix has `k_basis - 1`
#'   columns under thin-plate identifiability constraints).
#' @param n_sim Number of multiplier-bootstrap replicates for the
#'   p-value (default 1000).
#' @param scope,mode,half_life,seed See [compare_models()].
#' @inheritParams gof_univariate
#' @return List with `statistic` (\eqn{T_\psi}{T_psi}), `p_value`,
#'   `W` (n x q matrix), `u`, `covariate` and `n_sim`.
#'   With `n_samples > 1`, `p_value` is the Cauchy-combined p-value,
#'   `p_values` holds the per-sample p-values and `n_samples` their
#'   number; the other fields are those of the first sample (seed `seed`).
#'   With `n_samples = 1` the result is the single-sample result, without
#'   `p_values` or `n_samples`.
#' @inheritSection gof_univariate Several control samples
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#'
#'   Lin DY, Wei LJ, Ying Z (1993). Checking the Cox model with cumulative
#'   sums of martingale-based residuals. *Biometrika* 80(3), 557--572.
#'   \doi{10.1093/biomet/80.3.557}.
#'
#'   Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
#'   analytic p-value calculation under arbitrary dependency structures.
#'   *Journal of the American Statistical Association* 115(529),
#'   393--402. \doi{10.1080/01621459.2018.1554485}.
#' @examples
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   data(simulated_events)
#'   gof_multivariate(simulated_events,
#'     model = c(reciprocity_count  = "linear",
#'               transitivity_count = "linear"),
#'     covariate = "reciprocity_count", n_sim = 200, seed = 1)[c("statistic", "p_value")]
#' }
#' @export
gof_multivariate <- function(event_log, model, covariate,
                              k_basis = 5, n_sim = 1000,
                              scope = "all", mode = "one",
                              half_life = NULL, seed = NULL,
                              n_samples = 1) {
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    stop("Package 'mgcv' is required for gof_multivariate().")
  }
  if (!is.numeric(k_basis) || length(k_basis) != 1L || k_basis < 3) {
    stop("`k_basis` must be a single integer >= 3.")
  }
  k_basis <- as.integer(k_basis)
  if (!is.numeric(n_sim) || length(n_sim) != 1L || n_sim < 50) {
    stop("`n_sim` must be a single integer >= 50.")
  }
  n_sim <- as.integer(n_sim)
  .gof_over_samples(function(sd) {
    .gof_multivariate_one(event_log, model, covariate, k_basis, n_sim,
                          scope, mode, half_life, sd)
  }, seed, n_samples)
}

.gof_multivariate_one <- function(event_log, model, covariate, k_basis,
                                  n_sim, scope, mode, half_life, seed) {
  prep <- .gof_fit_linear(event_log, model, scope, mode, half_life, seed)
  if (!covariate %in% prep$stat_set) {
    stop("`covariate` must be one of: ",
         paste(prep$stat_set, collapse = ", "))
  }
  # Re-fit with a smooth-by-difference design on `covariate` (Boschi
  # et al. 2025 sec. 3.3 trick) so the test target has a q-dim basis.
  x_case <- prep$cases[[covariate]]
  x_ctrl <- prep$ctrls[[covariate]]
  X_mat <- cbind(x_case, x_ctrl)
  I_mat <- cbind(rep(1, length(x_case)), rep(-1, length(x_case)))
  other <- setdiff(prep$stat_set, covariate)
  d_other <- if (length(other)) prep$Delta[, paste0("d_", other), drop = FALSE]
             else NULL
  gam_df <- data.frame(one = 1, X_mat = X_mat, I_mat = I_mat)
  if (!is.null(d_other)) {
    for (st in other) gam_df[[paste0("d_", st)]] <- prep$Delta[, paste0("d_", st)]
  }
  smooth_term <- sprintf("s(X_mat, by = I_mat, k = %d)", k_basis)
  lin_terms <- if (length(other)) paste(paste0("d_", other), collapse = " + ")
               else NULL
  rhs <- paste(c(smooth_term, lin_terms), collapse = " + ")
  fm <- stats::as.formula(paste("one ~ -1 +", rhs))
  fit <- mgcv::gam(fm, family = stats::binomial(),
                   data = gam_df, method = "REML")
  # Extract the smooth's design matrix columns. mgcv's by-variable
  # construction with I_mat = cbind(1, -1) makes the lpmatrix columns
  # already equal to (basis at case) - (basis at control), so they
  # are the q-dim Δh we want for the cumulative residual process.
  lp <- stats::predict(fit, type = "lpmatrix")
  smooth_cols <- grepl("^s\\(X_mat\\):I_mat\\.[0-9]+$", colnames(lp))
  if (!any(smooth_cols)) {
    stop("Internal: smooth basis columns not found in lpmatrix.")
  }
  Hd <- lp[, smooth_cols, drop = FALSE]
  X <- lp                                       # full design, n x p
  n <- nrow(Hd)
  # The REML fit only supplies the basis. The test refits the q spline
  # columns and the other covariates without penalty: under the null
  # (a linear effect, inside the span of the basis) this model is
  # correct, its score is 0 at the estimate, and the estimation term
  # below is the exact first-order expansion. A penalised fit selects its
  # smoothing parameter from the same data, which a bootstrap that holds
  # the parameter fixed does not reproduce.
  refit <- stats::glm.fit(X, rep(1, n), family = stats::binomial())
  if (!refit$converged) {
    warning("gof_multivariate(): the unpenalised refit did not converge.",
            call. = FALSE)
  }
  mu <- as.numeric(refit$fitted.values)
  resid <- 1 - mu                               # score weight, all y = 1
  wt <- mu * (1 - mu)                           # information weight
  info <- crossprod(X * sqrt(wt))               # X'WX
  Vp <- tryCatch(solve(info), error = function(e) {
    stop("gof_multivariate(): the information matrix of the spline refit ",
         "is singular; lower `k_basis`.", call. = FALSE)
  })
  # Standardise the q smooth columns once by J^{-1/2},
  # J = n^{-1} sum (1 - pi_i)^2 h_i h_i'; every quantity below is linear
  # in h_i, so this is the same as standardising the process.
  J <- crossprod(Hd * resid) / n
  inv_sq <- .gof_inv_sqrt(J)
  Ht <- Hd %*% inv_sq                           # n x q
  q <- ncol(Ht)
  G_k <- Ht * resid                             # score increments
  U <- X * resid                                # full score increments
  U_hat <- colSums(U)                           # 0 at the estimate
  # Estimation term A(u) Vp U, A(u) = sum_{i <= uM} pi(1-pi) h_i x_i'.
  # Under the null the observed process is
  #   C(u; theta0) - A(u) Vp C(1; theta0) + o_p(n^{1/2}),
  # which the multiplier bootstrap below reproduces for any growth of
  # the information A(u) along the event sequence.
  VpU <- as.numeric(Vp %*% U_hat)
  W <- matrix(0, n, q)
  A_list <- vector("list", q)
  for (k in seq_len(q)) {
    A_k <- apply(X * (wt * Ht[, k]), 2, cumsum)  # n x p, row u = A_k(u)
    A_list[[k]] <- A_k
    W[, k] <- (cumsum(G_k[, k]) - as.numeric(A_k %*% VpU)) / sqrt(n)
  }
  T_psi <- max(rowSums(W^2))
  # Multiplier bootstrap (Lin, Wei & Ying 1993): g_i ~ N(0, 1).
  if (!is.null(seed)) {
    withr::local_preserve_seed()
    set.seed(seed)
  }
  Gm <- matrix(stats::rnorm(n * n_sim), n, n_sim)
  corr <- crossprod(U %*% Vp, Gm)               # p x n_sim: Vp sum g_i U_i
  norm2 <- matrix(0, n, n_sim)
  for (k in seq_len(q)) {
    Wk <- (apply(G_k[, k] * Gm, 2, cumsum) - A_list[[k]] %*% corr) / sqrt(n)
    norm2 <- norm2 + Wk^2
  }
  T_sim <- apply(norm2, 2, max)
  p <- mean(T_sim >= T_psi)
  list(statistic = T_psi, p_value = p, W = W, u = seq_len(n) / n,
       covariate = covariate, n_sim = n_sim)
}

#' Omnibus GOF test via Cauchy combination
#'
#' Implements the omnibus test of Boschi & Wit (2025), Section 3.6 /
#' eq. 19. Runs `gof_univariate()` per covariate in `model`, then
#' combines the resulting p-values via the Cauchy combination
#' \eqn{T_o = \tfrac{1}{L}\sum_l \tan(\pi(0.5 - P_l))}{T_o = (1/L) sum tan(pi(0.5-P_l))}
#' (Liu & Xie 2020), with analytic p-value
#' \eqn{\tfrac{1}{2} - \arctan(T_o)/\pi}{0.5 - atan(T_o)/pi}.
#'
#' @param event_log Dyadic event log.
#' @param model Named character vector of `<stat> = "linear"` mapping.
#' @param scope,mode,half_life,seed See [compare_models()].
#' @inheritParams gof_univariate
#' @return List with `statistic` (\eqn{T_o}{T_o}), `p_value`,
#'   and `components` (per-covariate `data.frame` with `covariate`,
#'   `statistic`, `p_value`).
#'   With `n_samples > 1`, `components$p_value` is the Cauchy combination
#'   of each covariate's p-values over the samples and
#'   `components$statistic` its first-sample statistic; `p_values` holds
#'   the omnibus p-value of each sample, `n_samples` their number, and
#'   `statistic` is the first sample's \eqn{T_o}{T_o}. `p_value` is the
#'   Cauchy combination of `p_values`, which equals the Cauchy combination
#'   of all \eqn{L \times S}{L x S} covariate-by-sample p-values.
#'   With `n_samples = 1` the result is the single-sample result, without
#'   `p_values` or `n_samples`.
#' @inheritSection gof_univariate Several control samples
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#'
#'   Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
#'   analytic p-value calculation under arbitrary dependency structures.
#'   *Journal of the American Statistical Association* 115(529),
#'   393--402. \doi{10.1080/01621459.2018.1554485}.
#' @examples
#' data(simulated_events)
#' gof_global(simulated_events,
#'   model = c(reciprocity_count  = "linear",
#'             transitivity_count = "linear"), seed = 1)
#' @export
gof_global <- function(event_log, model,
                        scope = "all", mode = "one",
                        half_life = NULL, seed = NULL,
                        n_samples = 1) {
  if (!is.character(model) || !length(model)) {
    stop("`model` must be a non-empty named character vector.")
  }
  n_samples <- .gof_check_n_samples(n_samples)
  stat_set <- names(model)
  per <- lapply(stat_set, function(cov) {
    gof_univariate(event_log, model, cov, scope, mode, half_life, seed,
                   n_samples = n_samples)
  })
  p_vec <- vapply(per, function(x) x$p_value, numeric(1))
  components <- data.frame(
    covariate = stat_set,
    statistic = vapply(per, function(x) x$statistic, numeric(1)),
    p_value   = p_vec,
    stringsAsFactors = FALSE)
  if (n_samples == 1L) {
    cc <- .gof_cauchy(p_vec)
    return(list(statistic = cc$statistic, p_value = cc$p_value,
                components = components))
  }
  # Omnibus test of each sample: Cauchy combination across covariates.
  p_mat <- vapply(per, function(x) x$p_values, numeric(n_samples))
  p_mat <- matrix(p_mat, nrow = n_samples)          # samples x covariates
  per_sample <- apply(p_mat, 1L, function(p) .gof_cauchy(p)$p_value)
  T_first <- .gof_cauchy(p_mat[1L, ])$statistic
  list(statistic = T_first, p_value = .gof_cauchy(per_sample)$p_value,
       components = components, p_values = per_sample,
       n_samples = n_samples)
}

#' GOF test for an auxiliary (unmodelled) statistic
#'
#' Implements the auxiliary-statistic test of Boschi & Wit (2025),
#' Section 3.7 / eq. 20. Tests whether a covariate `auxiliary` that is
#' *not* part of `model` has nonetheless been adequately captured
#' indirectly by the fitted model. Uses the simulation-based p-value
#' described in the paper: `n_sim` replicates of
#' \eqn{G^*[\hat\gamma, u]}{G*[γ̂,u]} are drawn from i.i.d. standard
#' normals, the test statistic
#' \eqn{T_\phi = \sup_u |G[\hat\gamma, u]|}{T_φ = sup_u |G[γ̂, u]|} is
#' computed, and the empirical p-value is the fraction of replicates
#' with \eqn{T_{\phi,b}^* \ge T_\phi}{T*_{φ,b} >= T_φ}.
#'
#' @param event_log Dyadic event log.
#' @param model Named character vector of `<stat> = "linear"` mapping
#'   for the *fitted* covariates (must not contain `auxiliary`).
#' @param auxiliary Name of the statistic to test as an unmodelled
#'   feature; must be a statistic computable by
#'   [endogenous_features()].
#' @param n_sim Number of Monte Carlo replicates (default 1000).
#' @param scope,mode,half_life,seed See [compare_models()].
#' @inheritParams gof_univariate
#' @return List with `statistic` (\eqn{T_\phi}{T_φ}), `p_value`,
#'   `G`, `u`, `auxiliary` and `n_sim`.
#'   With `n_samples > 1`, `p_value` is the Cauchy-combined p-value,
#'   `p_values` holds the per-sample p-values and `n_samples` their
#'   number; the other fields are those of the first sample (seed `seed`).
#'   With `n_samples = 1` the result is the single-sample result, without
#'   `p_values` or `n_samples`.
#' @inheritSection gof_univariate Several control samples
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#'
#'   Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
#'   analytic p-value calculation under arbitrary dependency structures.
#'   *Journal of the American Statistical Association* 115(529),
#'   393--402. \doi{10.1080/01621459.2018.1554485}.
#' @examples
#' data(simulated_events)
#' gof_auxiliary(simulated_events,
#'   model = c(reciprocity_count = "linear"),
#'   auxiliary = "transitivity_count", n_sim = 200, seed = 1)[c("statistic", "p_value")]
#' @export
gof_auxiliary <- function(event_log, model, auxiliary,
                           n_sim = 1000,
                           scope = "all", mode = "one",
                           half_life = NULL, seed = NULL,
                           n_samples = 1) {
  if (!is.character(auxiliary) || length(auxiliary) != 1L ||
      !nzchar(auxiliary)) {
    stop("`auxiliary` must be a single non-empty statistic name.")
  }
  if (auxiliary %in% names(model)) {
    stop("`auxiliary` must NOT be part of `model`.")
  }
  .gof_over_samples(function(sd) {
    .gof_auxiliary_one(event_log, model, auxiliary, n_sim, scope, mode,
                       half_life, sd)
  }, seed, n_samples)
}

.gof_auxiliary_one <- function(event_log, model, auxiliary, n_sim,
                               scope, mode, half_life, seed) {
  prep <- .gof_fit_linear(event_log, model, scope, mode, half_life, seed)
  # Compute the auxiliary statistic on the same case-control sample.
  cc_combined <- rbind(prep$cases, prep$ctrls)
  cc_combined <- cc_combined[order(cc_combined$stratum, -cc_combined$event), ]
  aux_feat <- endogenous_features(cc_combined, stats = auxiliary,
                                           half_life = half_life)
  cases_aux <- aux_feat[aux_feat$event == 1L, ]
  ctrls_aux <- aux_feat[aux_feat$event == 0L, ]
  cases_aux <- cases_aux[order(cases_aux$stratum), ]
  ctrls_aux <- ctrls_aux[order(ctrls_aux$stratum), ]
  phi_case <- cases_aux[[auxiliary]]
  phi_ctrl <- ctrls_aux[[auxiliary]]
  phi_case[is.na(phi_case)] <- 0
  phi_ctrl[is.na(phi_ctrl)] <- 0
  Delta_phi <- phi_case - phi_ctrl

  # Eq. 20: cumulative score-like increment for the auxiliary feature.
  n <- length(Delta_phi)
  resid <- 1 - prep$fitted_p
  G_k <- Delta_phi * resid
  cum <- cumsum(G_k)
  end_val <- cum[n]
  u <- seq_len(n) / n
  G <- cum - u * end_val                       # centered at 0 at u=1
  T_phi <- max(abs(G)) / sqrt(n)

  # Simulation under the fitted null: replicate G_k^* = N_k · G_k where
  # N_k ~ N(0, 1) i.i.d. (paper's eq. 20 multiplier construction).
  if (!is.null(seed)) {
    withr::local_preserve_seed()
    set.seed(seed + 17L)
  }
  T_star <- numeric(n_sim)
  for (b in seq_len(n_sim)) {
    Nk <- stats::rnorm(n)
    cum_b <- cumsum(G_k * Nk)
    end_b <- cum_b[n]
    G_b <- cum_b - u * end_b
    T_star[b] <- max(abs(G_b)) / sqrt(n)
  }
  p <- mean(T_star >= T_phi)
  list(statistic = T_phi, p_value = p, G = G, u = u,
       auxiliary = auxiliary, n_sim = n_sim)
}
