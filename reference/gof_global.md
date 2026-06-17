# Omnibus GOF test via Cauchy combination

Implements the omnibus test of Boschi & Wit (2025), Section 3.6 / eq.
19. Runs
[`gof_univariate()`](https://franciscorichter.github.io/amorem/reference/gof_univariate.md)
per covariate in `model`, then combines the resulting p-values via the
Cauchy combination \\T_o = \tfrac{1}{L}\sum_l \tan(\pi(0.5 - P_l))\\
(Liu & Xie 2020), with analytic p-value \\\tfrac{1}{2} -
\arctan(T_o)/\pi\\.

## Usage

``` r
gof_global(
  event_log,
  model,
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

  Named character vector of `<stat> = "linear"` mapping.

- scope, mode, half_life, seed:

  See
  [`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md).

## Value

List with `statistic` (\\T_o\\), `p_value`, and `components`
(per-covariate `data.frame` with `covariate`, `statistic`, `p_value`).

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).
