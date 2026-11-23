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

  Event-indicator and stratum columns. When `NULL` (default), the ones
  the
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  fit used are taken from `object`.

- n_grid:

  Number of grid points of each partial-dependence curve, which spans
  the 1st to 99th percentile of the feature in `data`.

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

## Examples

``` r
cc <- sample_non_events(classroom_events, n_controls = 2, seed = 1)
cc <- endogenous_features(cc, c("reciprocity_count", "transitivity_count"))
fit <- rem(event ~ reciprocity_count + transitivity_count, data = cc,
           method = "nn", nn = nn_control(hidden = 4, epochs = 50, seed = 1))
u <- nn_uncertainty(fit, cc, B = 5, seed = 1)
u
#> Bootstrap uncertainty for a neural rem() fit
#>   resamples    : 5 (5 successful)
#>   level        : 95%
#>   features     : reciprocity_count, transitivity_count
#>   concordance  : 0.669  [0.442, 0.700]
#> Use plot() for per-feature partial-dependence bands.
plot(u)
```
