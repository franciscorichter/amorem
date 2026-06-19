# Bootstrap uncertainty for the neural rem() backend

Quantifies uncertainty for a `rem(method = "nn")` fit by a **stratum
bootstrap**: the case-control strata are resampled with replacement, the
network is refit on each resample (reusing the original
[`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md)
settings, including the training `engine`), and the spread across refits
yields partial-dependence uncertainty bands and a concordance confidence
interval. This is the inferential counterpart that the point-prediction
`nn` backend otherwise lacks
([`coef()`](https://rdrr.io/r/stats/coef.html) returns `NULL`).

## Usage

``` r
nn_uncertainty(
  object,
  data,
  B = 200L,
  case = NULL,
  stratum = NULL,
  n_grid = 50L,
  level = 0.95,
  seed = NULL
)
```

## Arguments

- object:

  A fitted
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  object with `method = "nn"`.

- data:

  The case-control data frame the model was fit on (same columns).

- B:

  Number of bootstrap resamples.

- case, stratum:

  Event-indicator and stratum columns, resolved exactly as in
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  (defaults: the formula's left-hand side, and `cumsum(case == 1)`).

- n_grid:

  Grid resolution for the partial-dependence curves.

- level:

  Confidence level for the bands and the concordance interval.

- seed:

  Optional integer seed for the resampling.

## Value

An object of class `"nn_uncertainty"`: a per-feature list of
`data.frame(x, lo, med, hi)` bands, a `concordance` quantile interval,
and the settings `B`, `level`. Has
[`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

## Details

Each bootstrap partial-dependence curve is centred (its grid-mean
removed) before the pointwise quantiles are taken, so the bands describe
uncertainty in the *shape* of each effect, not the conditional-logit's
unidentified per-stratum offset.

## See also

[`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md),
[`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md)
