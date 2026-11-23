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
  seed = NULL,
  n_samples = 1
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

- n_samples:

  Number of control samples (default 1). With `n_samples > 1` the test
  is run on `n_samples` case-control samples, drawn with seeds `seed`,
  `seed + 1`, ..., `seed + n_samples - 1` (or independently from the
  current random stream when `seed` is `NULL`), and the p-values are
  combined with the Cauchy combination; see *Several control samples*.

## Value

List with `statistic` (\\T_o\\), `p_value`, and `components`
(per-covariate `data.frame` with `covariate`, `statistic`, `p_value`).
With `n_samples > 1`, `components$p_value` is the Cauchy combination of
each covariate's p-values over the samples and `components$statistic`
its first-sample statistic; `p_values` holds the omnibus p-value of each
sample, `n_samples` their number, and `statistic` is the first sample's
\\T_o\\. `p_value` is the Cauchy combination of `p_values`, which equals
the Cauchy combination of all \\L \times S\\ covariate-by-sample
p-values. With `n_samples = 1` the result is the single-sample result,
without `p_values` or `n_samples`.

## Several control samples

The test is computed on one case-control sample, so its p-value depends
on which controls were drawn. With `n_samples` \\= S \> 1\\ the p-values
\\p_1, \dots, p_S\\ of the same test on \\S\\ control samples are
combined as \$\$T = \frac{1}{S}\sum\_{s=1}^S \tan\\\pi(1/2 - p_s)\\,
\qquad p = \frac{1}{2} - \frac{\arctan T}{\pi}\$\$ (Liu & Xie 2020), the
rule `gof_global()` uses across covariates. The samples share the
events, so the \\p_s\\ are dependent. The Cauchy combination is valid
under arbitrary dependence among the \\p_s\\: when each \\p_s\\ is
uniform under the null, the tail of \\T\\ is asymptotically standard
Cauchy whatever their dependence (Liu & Xie 2020, Theorem 1), so \\p\\
controls the size at small levels; with identical samples it returns
their common p-value. Each \\p_s\\ is clamped to \\\[10^{-15}, 1 -
10^{-15}\]\\ so that the tangent stays finite. The Monte Carlo p-values
of
[`gof_multivariate()`](https://franciscorichter.github.io/amorem/reference/gof_multivariate.md)
and
[`gof_auxiliary()`](https://franciscorichter.github.io/amorem/reference/gof_auxiliary.md)
are first floored at \\1/(n\_{sim} + 1)\\ (`p_values` keeps the
unfloored values). Since \\T\\ is at most \\\max_s \tan\\\pi(1/2 -
p_s)\\\\, the combined p-value is then at least \\1/(n\_{sim} + 1)\\: a
combined p-value equal to that bound means \\p \< 1/n\_{sim}\\ in every
sample, and a smaller p-value needs a larger `n_sim`. The Kolmogorov
p-values of
[`gof_univariate()`](https://franciscorichter.github.io/amorem/reference/gof_univariate.md)
and `gof_global()` are analytic and are not floored.

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).

Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
analytic p-value calculation under arbitrary dependency structures.
*Journal of the American Statistical Association* 115(529), 393–402.
[doi:10.1080/01621459.2018.1554485](https://doi.org/10.1080/01621459.2018.1554485)
.

## Examples

``` r
data(classroom_events)
gof_global(classroom_events,
  model = c(reciprocity_count  = "linear",
            transitivity_count = "linear"), seed = 1)
#> $statistic
#> [1] 1.896547
#> 
#> $p_value
#> [1] 0.1544529
#> 
#> $components
#>            covariate statistic    p_value
#> 1  reciprocity_count 0.8426279 0.47658667
#> 2 transitivity_count 1.2599088 0.08360382
#> 
```
