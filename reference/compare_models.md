# Compare candidate endogenous specifications by AIC

Convenience wrapper that runs the canonical case-control / no-intercept
binomial-GLM recipe on every specification in `models` and returns a
tidy AIC comparison table. One case-control sample is drawn from
`event_log` and shared across every specification so that the AIC values
are directly comparable.

## Usage

``` r
compare_models(
  event_log,
  models,
  n_controls = 1,
  scope = c("all", "appearance", "citation"),
  mode = c("one", "two"),
  half_life = NULL,
  seed = NULL
)
```

## Arguments

- event_log:

  Data frame with `sender`, `receiver`, and `time` columns.

- models:

  Named list of character vectors. Each entry names one candidate
  specification; the vector contents are the endogenous statistics it
  includes. Stats must be valid names for
  [`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md).

- n_controls:

  Number of controls per case in
  [`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md).
  Currently must be `1`.

- scope, mode:

  Passed through to
  [`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md);
  see that help page for semantics.

- half_life:

  Required when any specification contains an exp-decay stat. Shared
  across all specs that use one.

- seed:

  Optional integer seed for the case-control sample.

## Value

A data frame with one row per specification and columns `model`,
`n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`. Sorted ascending by
`AIC`. The model with the lowest AIC has `delta_AIC = 0`.

## Details

Each specification is a character vector of stat names accepted by
[`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md).
The function computes the union of all stats once, builds
case-minus-control differences, and fits one binomial GLM per
specification with the appropriate subset of columns. The fitted models
are equivalent to the partial-likelihood parametrisation used in
case-control REM inference (Vu et al. 2017; Juozaitienė & Wit 2024).

The helper currently supports `n_controls = 1` only; richer case-control
designs (more controls per case, conditional-logistic aggregation) are
on the roadmap.

## References

Juozaitienė R, Wit EC (2024). It's about time: revisiting reciprocity
and triadicity in relational event analysis. *Journal of the Royal
Statistical Society Series A* 188(4), 1246-1262.
[doi:10.1093/jrsssa/qnae132](https://doi.org/10.1093/jrsssa/qnae132) .

## See also

[`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md),
[`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md).

## Examples

``` r
if (FALSE) { # \dontrun{
data(classroom_events)
compare_models(
  classroom_events,
  models = list(
    count       = c("reciprocity_count", "transitivity_count"),
    continuous  = c("reciprocity_time_recent",
                    "transitivity_time_recent"),
    interrupted = c("reciprocity_time_recent_interrupted",
                    "transitivity_time_recent_interrupted")),
  seed = 11)
} # }
```
