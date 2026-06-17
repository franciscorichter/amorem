# Recency transform of inter-event time gaps

Maps non-negative time gaps \\\delta\\ to bounded recency weights via
\$\$ w(\delta) \\=\\ \exp\\\Bigl(-\frac{\delta}{2\\m}\Bigr), \$\$ where
\\m\\ is the median of the supplied (or reference) gaps. Large gaps map
toward 0; gaps near 0 map toward 1. The half-life of the kernel is \\2 m
\log 2\\, so the median gap itself is mapped to approximately \\e^{-1/2}
\approx 0.607\\.

## Usage

``` r
transform_recency(delta, half_life = NULL, reference = NULL)
```

## Arguments

- delta:

  Numeric vector of non-negative time gaps. NAs propagate.

- half_life:

  Optional positive scalar. If supplied, used directly as the kernel
  scale \\2 m\\, bypassing the median rule.

- reference:

  Optional numeric vector. If supplied, the median is computed on
  `reference` instead of `delta`. Useful when transforming new data
  using a scale fitted on training data.

## Value

Numeric vector the same length as `delta`, with values in `(0, 1]`. NAs
in `delta` are preserved.

## Details

This is the data-driven recency parametrisation used as a preprocessing
step for global and exogenous covariates in Lembo, Juozaitiene,
Vinciotti & Wit (2025) and matches the "recency" axis of
[`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md).

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
#>  [1] 0.2208296551 0.0941105091 0.7472066790 0.7560932803 0.4180571006
#>  [6] 0.0030581746 0.0855098156 0.3398110062 0.1476168834 0.7452079433
#> [11] 0.0619473618 0.2178257798 0.0841455618 0.0001436877 0.1213487880
#> [16] 0.1261242317 0.0234691064 0.2699568158 0.5097336458 0.3082144590
```
