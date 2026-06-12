# Convert a long case-control event log to wide case-1-control format

Reshapes a long case-(k-)control dataset – one row per case and per
control, with a 0/1 case indicator – into a wide **case-1-control**
table with one row per case. For each covariate the event value
(`<cov>_ev`), the matched control value (`<cov>_nv`) and their
difference (`d_<cov>`, event minus control) are emitted, ready for the
`gam` backend of
[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md).

## Usage

``` r
widen_case_control(
  data,
  case = NULL,
  stratum = NULL,
  covariates = NULL,
  control_index = 1L
)
```

## Arguments

- data:

  A long case-control data.frame.

- case:

  Optional name of the 0/1 event-indicator column. If `NULL` (default),
  it is auto-detected from the package's `event` column (as produced by
  [`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md))
  or eventnet's `IS_OBSERVED`, preferring `event` when both are present.

- stratum:

  Optional name of the column grouping each case with its controls. When
  `NULL`, the stratum is derived as `cumsum(case == 1)` (assuming each
  case is immediately followed by its controls).

- covariates:

  Character vector of covariate columns to widen. When `NULL`, all
  numeric columns are used except the case indicator, the stratum, and
  the standard eventnet bookkeeping columns (`EVENT`, `INTEGER_TIME`,
  `TIME_POINT`, `TIME_UNIT`, `EVENT_INTERVAL`).

- control_index:

  Which control within each stratum to pair with the case (default the
  first). Lets a case-k-control log be reduced to case-1-control.

## Value

A data.frame with one row per case: a `stratum` column and, for each
covariate, `<cov>_ev`, `<cov>_nv` and `d_<cov>`. Strata without exactly
one case or without the requested control are dropped (with a message).

## Details

This is the preprocessing companion to
[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md) for
eventnet-style output, where a case row is followed by its controls and
the stratum id is left blank on control rows.

## See also

[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md),
[`simulate_relational_events()`](https://franciscorichter.github.io/amore/reference/simulate_relational_events.md)
(`wide = TRUE`).

## Examples

``` r
set.seed(1)
long <- data.frame(
  IS_OBSERVED = rep(c(1, 0, 0), 4),
  x = rnorm(12), y = rnorm(12))
widen_case_control(long, control_index = 1)
#>   stratum       x_ev      x_nv        d_x        y_ev        y_nv         d_y
#> 1       1 -0.6264538 0.1836433 -0.8100971 -0.62124058 -2.21469989  1.59345931
#> 2       2  1.5952808 0.3295078  1.2657730 -0.04493361 -0.01619026 -0.02874335
#> 3       3  0.4874291 0.7383247 -0.2508957  0.82122120  0.59390132  0.22731987
#> 4       4 -0.3053884 1.5117812 -1.8171696  0.78213630  0.07456498  0.70757132
```
