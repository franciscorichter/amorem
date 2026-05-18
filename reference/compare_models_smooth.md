# Compare candidate specifications with smooth (TVE / NLE / TVNLE) effects

Mirrors
[`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md)
but lets each statistic in a specification take one of four effect types
instead of a single linear coefficient: linear, time-varying (TVE),
non-linear (NLE), or jointly time-varying non-linear (TVNLE). The smooth
machinery follows Boschi, Lerner & Wit (2025); the
matrix-of-event-vs-non-event trick is documented in their Section 3.3.

## Usage

``` r
compare_models_smooth(
  event_log,
  models,
  scope = c("all", "appearance", "citation"),
  mode = c("one", "two"),
  half_life = NULL,
  k = NULL,
  seed = NULL
)
```

## Arguments

- event_log:

  Data frame with `sender`, `receiver`, `time` columns.

- models:

  Named list of specifications. Each entry is itself a named character
  vector (or named list) mapping statistic names to effect types:
  `"linear"`, `"tve"`, `"nle"`, or `"tvnle"`. Example:


          list(
            linear = c(reciprocity_count   = "linear",
                       transitivity_count  = "linear"),
            nle    = c(reciprocity_time_recent  = "nle",
                       transitivity_time_recent = "nle"),
            tvnle  = c(reciprocity_time_recent  = "tvnle",
                       transitivity_time_recent = "tvnle"))
        

- scope, mode:

  Passed through to
  [`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md).

- half_life:

  Required when an exp-decay statistic is requested.

- k:

  Optional integer: knot count for `s()` and `te()` terms. Default
  `NULL` lets `mgcv` choose (`-1`).

- seed:

  Integer seed for the case-control sample.

## Value

Data frame with one row per specification and columns `model`,
`n_terms`, `n_obs`, `log_lik`, `AIC`, `delta_AIC`.

## Details

For each specification:

- One case-control sample is drawn from `event_log` with
  `n_controls = 1` (paired event / non-event design).

- For every requested statistic, both the case (event) and the control
  (non-event) features are computed via
  [`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md).

- The mgcv design uses the case-vs-control matrix trick:

  - linear -\> a single coefficient on `case - control` (column
    `d_stat`).

  - tve -\> `s(time, by = d_stat)` — smooth in time, multiplied by
    `d_stat`.

  - nle -\> `s(stat_mat, by = I_mat)` where `stat_mat` is a two-column
    matrix `cbind(case, control)` and `I_mat` is `cbind(1, -1)`.

  - tvnle -\> `te(time_mat, stat_mat, by = I_mat)` tensor product
    smooth, with time_mat both columns equal to the event time vector.

- The model is fitted with
  [`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html) and a degenerate
  logistic likelihood: response = `rep(1, n)`, formula =
  `one ~ -1 + ...`, `family = binomial`. This matches Boschi et al.
  equation 8.

AIC values are directly comparable across specifications because every
fit uses the same case-control sample. Returns the same tidy
`data.frame` as
[`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md).

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
Time-Homogeneity: Relational Hyper Event Models with Time-Varying
Non-Linear Effects*. arXiv:2509.05289.

## See also

[`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md)
for the linear-only variant.

## Examples

``` r
if (FALSE) { # \dontrun{
data(classroom_events)
compare_models_smooth(
  classroom_events,
  models = list(
    linear = c(reciprocity_time_recent  = "linear",
               transitivity_time_recent = "linear"),
    nle    = c(reciprocity_time_recent  = "nle",
               transitivity_time_recent = "nle"),
    tvnle  = c(reciprocity_time_recent  = "tvnle",
               transitivity_time_recent = "tvnle")),
  seed = 11)
} # }
```
