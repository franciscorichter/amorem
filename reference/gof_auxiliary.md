# GOF test for an auxiliary (unmodelled) statistic

Implements the auxiliary-statistic test of Boschi & Wit (2025), Section
3.7 / eq. 20. Tests whether a covariate `auxiliary` that is *not* part
of `model` has nonetheless been adequately captured indirectly by the
fitted model. Uses the simulation-based p-value described in the paper:
`n_sim` replicates of \\G^\*\[\hat\gamma, u\]\\ are drawn from i.i.d.
standard normals, the test statistic \\T\_\phi = \sup_u \|G\[\hat\gamma,
u\]\|\\ is computed, and the empirical p-value is the fraction of
replicates with \\T\_{\phi,b}^\* \ge T\_\phi\\.

## Usage

``` r
gof_auxiliary(
  event_log,
  model,
  auxiliary,
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

  Named character vector of `<stat> = "linear"` mapping for the *fitted*
  covariates (must not contain `auxiliary`).

- auxiliary:

  Name of the statistic to test as an unmodelled feature; must be a
  statistic computable by
  [`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md).

- n_sim:

  Number of Monte Carlo replicates (default 1000).

- scope, mode, half_life, seed:

  See
  [`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md).

## Value

List with `statistic` (\\T\_\phi\\), `p_value`, `G`, `u`, and
`auxiliary`.

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).
