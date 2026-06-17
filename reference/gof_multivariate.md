# Multivariate GOF test for smooth or random-effect covariates

Implements the multivariate test of Boschi & Wit (2025), Section 3.4.
Builds a `q`-dimensional cumulative residual process from the spline
basis of the requested covariate's smooth effect, normalises by the
inverse-square-root of the empirical variance-covariance matrix \\\hat
J\\ (eq. 17), and tests against a `q`-dimensional standard Brownian
bridge via \\T\_\psi = \sup_u \lVert\hat W\rVert^2\\. The p-value is
computed empirically by simulating `n_sim` Brownian bridge trajectories.

## Usage

``` r
gof_multivariate(
  event_log,
  model,
  covariate,
  k_basis = 5,
  n_sim = 1000,
  scope = "all",
  mode = "one",
  half_life = NULL,
  seed = NULL
)
```

## Arguments

- event_log:

  Dyadic event log.

- model:

  Named character vector of `<stat> = "linear"` mapping (for the rest of
  the model); the test target is `covariate` with a flexible smooth
  basis of dimension `k_basis - 1`.

- covariate:

  Name of the covariate to test under a smooth effect.

- k_basis:

  Spline-basis dimension for `covariate` (passed as `k` to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html); the resulting
  design matrix has `k_basis - 1` columns under thin-plate
  identifiability constraints).

- n_sim:

  Number of simulated Brownian bridges for the empirical p-value
  (default 1000).

- scope, mode, half_life, seed:

  See
  [`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md).

## Value

List with `statistic` (\\T\_\psi\\), `p_value`, `W` (n x q matrix), `u`,
and `covariate`.

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).
