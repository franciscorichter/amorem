# GOF test for an auxiliary (unmodelled) statistic

Implements the auxiliary-statistic test of Boschi & Wit (2025), Section
3.7 / eq. 20. Tests whether a covariate `auxiliary` that is *not* part
of `model` has nonetheless been adequately captured indirectly by the
fitted model. Uses the simulation-based p-value described in the paper:
`n_sim` replicates of \\G^\*\[\hat\gamma, u\]\\ are drawn from i.i.d.
standard normals, the test statistic \\T\_\phi = \sup_u \|G\[\hat\gamma,
u\]\|\\ is computed, and the empirical p-value is the fraction of
replicates with \\T\_{\phi,b}^\* \ge T\_\phi\\.

## Usage

``` r
gof_auxiliary(
  event_log,
  model,
  auxiliary,
  n_sim = 1000,
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

  Named character vector of `<stat> = "linear"` mapping for the *fitted*
  covariates (must not contain `auxiliary`).

- auxiliary:

  Name of the statistic to test as an unmodelled feature; must be a
  statistic computable by
  [`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md).

- n_sim:

  Number of Monte Carlo replicates (default 1000).

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

List with `statistic` (\\T\_\phi\\), `p_value`, `G`, `u`, `auxiliary`
and `n_sim`. With `n_samples > 1`, `p_value` is the Cauchy-combined
p-value, `p_values` holds the per-sample p-values and `n_samples` their
number; the other fields are those of the first sample (seed `seed`).
With `n_samples = 1` the result is the single-sample result, without
`p_values` or `n_samples`.

## Several control samples

The test is computed on one case-control sample, so its p-value depends
on which controls were drawn. With `n_samples` \\= S \> 1\\ the p-values
\\p_1, \dots, p_S\\ of the same test on \\S\\ control samples are
combined as \$\$T = \frac{1}{S}\sum\_{s=1}^S \tan\\\pi(1/2 - p_s)\\,
\qquad p = \frac{1}{2} - \frac{\arctan T}{\pi}\$\$ (Liu & Xie 2020), the
rule
[`gof_global()`](https://franciscorichter.github.io/amorem/reference/gof_global.md)
uses across covariates. The samples share the events, so the \\p_s\\ are
dependent. The Cauchy combination is valid under arbitrary dependence
among the \\p_s\\: when each \\p_s\\ is uniform under the null, the tail
of \\T\\ is asymptotically standard Cauchy whatever their dependence
(Liu & Xie 2020, Theorem 1), so \\p\\ controls the size at small levels;
with identical samples it returns their common p-value. Each \\p_s\\ is
clamped to \\\[10^{-15}, 1 - 10^{-15}\]\\ so that the tangent stays
finite. The Monte Carlo p-values of
[`gof_multivariate()`](https://franciscorichter.github.io/amorem/reference/gof_multivariate.md)
and `gof_auxiliary()` are first floored at \\1/(n\_{sim} + 1)\\
(`p_values` keeps the unfloored values). Since \\T\\ is at most \\\max_s
\tan\\\pi(1/2 - p_s)\\\\, the combined p-value is then at least
\\1/(n\_{sim} + 1)\\: a combined p-value equal to that bound means \\p
\< 1/n\_{sim}\\ in every sample, and a smaller p-value needs a larger
`n_sim`. The Kolmogorov p-values of
[`gof_univariate()`](https://franciscorichter.github.io/amorem/reference/gof_univariate.md)
and
[`gof_global()`](https://franciscorichter.github.io/amorem/reference/gof_global.md)
are analytic and are not floored.

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
data(simulated_events)
gof_auxiliary(simulated_events,
  model = c(reciprocity_count = "linear"),
  auxiliary = "transitivity_count", n_sim = 200, seed = 1)[c("statistic", "p_value")]
#> $statistic
#> [1] 1.775988
#> 
#> $p_value
#> [1] 0.08
#> 
```
