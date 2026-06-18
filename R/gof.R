# Cumulative martingale residual GOF tests for relational event models,
# following Boschi & Wit (2025, Statistics & Computing). All four entry
# points share a single case-control sample (drawn at n_controls = 1,
# matching the paper's NCC m = 2 setup) and a single fitted partial-
# likelihood model.

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
#' @return A list with `statistic` (\eqn{T_x}{T_x}), `p_value` (KS),
#'   `W` (numeric vector of length `n`, the normalised process),
#'   and `u` (the time grid in `[0, 1]`).
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#' @examples
#' \dontrun{
#' data(classroom_events)
#' gof_univariate(classroom_events,
#'   model = c(reciprocity_count  = "linear",
#'             transitivity_count = "linear"),
#'   covariate = "reciprocity_count", seed = 1)
#' }
#' @export
gof_univariate <- function(event_log, model, covariate,
                            scope = "all", mode = "one",
                            half_life = NULL, seed = NULL) {
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
#' Implements the multivariate test of Boschi & Wit (2025), Section 3.4.
#' Builds a `q`-dimensional cumulative residual process from the spline
#' basis of the requested covariate's smooth effect, normalises by the
#' inverse-square-root of the empirical variance-covariance matrix
#' \eqn{\hat J}{J} (eq. 17), and tests against a `q`-dimensional
#' standard Brownian bridge via \eqn{T_\psi = \sup_u \lVert\hat W\rVert^2}{T_psi = sup ||W||^2}.
#' The p-value is computed empirically by simulating `n_sim` Brownian
#' bridge trajectories.
#'
#' @param event_log Dyadic event log.
#' @param model Named character vector of `<stat> = "linear"` mapping
#'   (for the rest of the model); the test target is `covariate` with
#'   a flexible smooth basis of dimension `k_basis - 1`.
#' @param covariate Name of the covariate to test under a smooth effect.
#' @param k_basis Spline-basis dimension for `covariate` (passed as `k`
#'   to `mgcv::s()`; the resulting design matrix has `k_basis - 1`
#'   columns under thin-plate identifiability constraints).
#' @param n_sim Number of simulated Brownian bridges for the empirical
#'   p-value (default 1000).
#' @param scope,mode,half_life,seed See [compare_models()].
#' @return List with `statistic` (\eqn{T_\psi}{T_psi}), `p_value`,
#'   `W` (n x q matrix), `u`, and `covariate`.
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#' @export
gof_multivariate <- function(event_log, model, covariate,
                              k_basis = 5, n_sim = 1000,
                              scope = "all", mode = "one",
                              half_life = NULL, seed = NULL) {
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
  # Use the GAM's own fitted probability rather than refitting linear.
  fitted_p_gam <- as.numeric(stats::fitted(fit))
  w <- .gof_W_process(Hd, fitted_p_gam)
  inv_sq <- .gof_inv_sqrt(w$J)
  n <- nrow(Hd)
  q <- ncol(Hd)
  W <- (w$cum_centered / sqrt(n)) %*% inv_sq    # n x q
  T_psi <- max(rowSums(W^2))
  # Empirical p-value via simulated q-dim standard Brownian bridges.
  sim_stats <- .gof_simulate_BB_supnorm2(n = n, q = q, n_sim = n_sim,
                                          seed = seed)
  p <- mean(sim_stats >= T_psi)
  list(statistic = T_psi, p_value = p, W = W, u = w$u,
       covariate = covariate, n_sim = n_sim)
}

# --- internal: simulate the distribution of sup_u ||Z^0(u)||^2 where
# Z^0 is a q-dim standard Brownian bridge, evaluated on an n-grid.
.gof_simulate_BB_supnorm2 <- function(n, q, n_sim, seed = NULL) {
  if (!is.null(seed)) {
    old <- .Random.seed
    on.exit(assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
    set.seed(seed)
  }
  u <- seq_len(n) / n
  out <- numeric(n_sim)
  for (b in seq_len(n_sim)) {
    # q-dim standard Brownian motion at n grid points.
    inc <- matrix(stats::rnorm(n * q, sd = sqrt(1 / n)), nrow = n, ncol = q)
    Bt  <- apply(inc, 2, cumsum)
    B1  <- Bt[n, ]
    Z0  <- Bt - outer(u, B1)
    out[b] <- max(rowSums(Z0^2))
  }
  out
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
#' @return List with `statistic` (\eqn{T_o}{T_o}), `p_value`,
#'   and `components` (per-covariate `data.frame` with `covariate`,
#'   `statistic`, `p_value`).
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#' @export
gof_global <- function(event_log, model,
                        scope = "all", mode = "one",
                        half_life = NULL, seed = NULL) {
  if (!is.character(model) || !length(model)) {
    stop("`model` must be a non-empty named character vector.")
  }
  stat_set <- names(model)
  per <- lapply(stat_set, function(cov) {
    gof_univariate(event_log, model, cov, scope, mode, half_life, seed)
  })
  p_vec <- vapply(per, function(x) x$p_value, numeric(1))
  # Clamp p-values strictly inside (0, 1) so tan() doesn't overflow.
  p_clamped <- pmin(pmax(p_vec, 1e-15), 1 - 1e-15)
  L <- length(p_clamped)
  T_o <- mean(tan(pi * (0.5 - p_clamped)))
  p_global <- 0.5 - atan(T_o) / pi
  components <- data.frame(
    covariate = stat_set,
    statistic = vapply(per, function(x) x$statistic, numeric(1)),
    p_value   = p_vec,
    stringsAsFactors = FALSE)
  list(statistic = T_o, p_value = p_global, components = components)
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
#' @return List with `statistic` (\eqn{T_\phi}{T_φ}), `p_value`,
#'   `G`, `u`, and `auxiliary`.
#' @references Boschi M, Wit EC (2025). *Goodness of fit in relational
#'   event models*. Statistics and Computing 36(4).
#' @export
gof_auxiliary <- function(event_log, model, auxiliary,
                           n_sim = 1000,
                           scope = "all", mode = "one",
                           half_life = NULL, seed = NULL) {
  if (!is.character(auxiliary) || length(auxiliary) != 1L ||
      !nzchar(auxiliary)) {
    stop("`auxiliary` must be a single non-empty statistic name.")
  }
  if (auxiliary %in% names(model)) {
    stop("`auxiliary` must NOT be part of `model`.")
  }
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
    old <- .Random.seed
    on.exit(assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
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
