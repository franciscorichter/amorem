# Goodness-of-fit test for a single FLE covariate

Implements the univariate cumulative martingale residual test of Boschi
& Wit (2025), Section 3.3. The test statistic is \\T_x = \sup_u \|\hat
W\[u\]\|\\ where \\\hat W\[u\]\\ is the normalised cumulative score
process for the requested covariate; under correct specification \\\hat
W\\ converges to a standard Brownian bridge, so the p-value follows the
Kolmogorov-Smirnov distribution \\2 \sum\_{k\ge 1} (-1)^{k-1} e^{-2 k^2
t^2}\\.

## Usage

``` r
gof_univariate(
  event_log,
  model,
  covariate,
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

- covariate:

  Name of the covariate in `model` to test.

- scope, mode, half_life, seed:

  See
  [`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md).

## Value

A list with `statistic` (\\T_x\\), `p_value` (KS), `W` (numeric vector
of length `n`, the normalised process), and `u` (the time grid in
`[0, 1]`).

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).

## Examples

``` r
if (FALSE) { # \dontrun{
data(classroom_events)
gof_univariate(classroom_events,
  model = c(reciprocity_count  = "linear",
            transitivity_count = "linear"),
  covariate = "reciprocity_count", seed = 1)
} # }
```
