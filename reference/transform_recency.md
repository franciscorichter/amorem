# Recency transform of inter-event time gaps

Maps non-negative time gaps \\\delta\\ to bounded recency weights via
\$\$ w(\delta) \\=\\ \exp\\\Bigl(-\frac{\delta}{2\\m}\Bigr), \$\$ where
\\m\\ is the median of the supplied (or reference) gaps. Large gaps map
toward 0; gaps near 0 map toward 1. The half-life of this kernel is \\2
m \log 2\\, so the median gap itself is mapped to approximately
\\e^{-1/2} \approx 0.607\\.

## Usage

``` r
transform_recency(delta, half_life = NULL, reference = NULL)
```

## Arguments

- delta:

  Numeric vector of non-negative time gaps. NAs propagate.

- half_life:

  Optional positive scalar, possibly `Inf`: the gap at which the weight
  is 0.5. Bypasses the median rule.

- reference:

  Optional numeric vector. If supplied, the median is computed on
  `reference` instead of `delta`. Useful when transforming new data
  using a scale fitted on training data.

## Value

Numeric vector the same length as `delta`, with values in `(0, 1]`. NAs
in `delta` are preserved.

## Details

When `half_life` \\T\\ is supplied, the weights are \\w(\delta) =
\exp(-\delta \log 2 / T) = 2^{-\delta/T}\\: a gap of \\T\\ maps to 0.5,
the same half-life convention as the `*_exp_decay` statistics of
[`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md)
and
[`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md).
`half_life = Inf` means no decay: every non-missing gap, including
`Inf`, maps to 1.

This is the data-driven recency parametrisation used as a preprocessing
step for global and exogenous covariates in Lembo, Juozaitiene,
Vinciotti & Wit (2025) and matches the "recency" axis of
[`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md).

## References

Lembo M, Juozaitiene R, Vinciotti V, Wit EC (2025). *Relational Event
Models with Global Covariates*. JRSS-C.

## Examples

``` r
set.seed(1)
gaps <- rexp(20, rate = 0.5)
transform_recency(gaps)
#>  [1] 0.64441165 0.50280024 0.91871222 0.92187776 0.77589724 0.18553812
#>  [7] 0.48897442 0.73050063 0.57315574 0.91799657 0.44520214 0.64184900
#> [13] 0.48669180 0.07621828 0.54139459 0.54750852 0.33567618 0.68319337
#> [19] 0.82196996 0.71005091
transform_recency(gaps, half_life = 1)
#>  [1] 0.351022724 0.194348037 0.817101127 0.823824808 0.546336891 0.018074041
#>  [7] 0.181856941 0.473236849 0.265514952 0.815585493 0.145443401 0.347706102
#> [13] 0.179840879 0.002170332 0.231793765 0.238078972 0.074218860 0.403462565
#> [19] 0.626824314 0.442282651
```
