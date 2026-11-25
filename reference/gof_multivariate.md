# Multivariate GOF test for smooth or random-effect covariates

Multivariate cumulative-residual test of Boschi & Wit (2025), Section
3.4, for the functional form of one covariate. The covariate's effect is
expanded in `q = k_basis - 1` event-minus-control columns \\h_i\\ of a
thin-plate spline basis
([`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html)), and the model with
these columns and the other covariates linear is refitted without
penalty. It contains the linear effect, so it is correct under the null.
With its fitted probabilities \\\pi_i\\, design rows \\x_i\\, inverse
information \\V = (X^\top W X)^{-1}\\, \\W =
\mathrm{diag}\\\pi_i(1-\pi_i)\\\\, and score \\\hat U = \sum_i (1-\pi_i)
x_i = 0\\, the process is \$\$W(u) = M^{-1/2} \hat J^{-1/2}
\Bigl\\\sum\_{i \le uM} (1-\pi_i) h_i - A(u) V \hat U\Bigr\\,\qquad A(u)
= \sum\_{i \le uM} \pi_i (1-\pi_i) h_i x_i^\top,\$\$ with \\\hat J =
M^{-1}\sum_i (1-\pi_i)^2 h_i h_i^\top\\, and the statistic is \\T\_\psi
= \sup_u \lVert W(u)\rVert^2\\. The second term is zero at the estimate
and is written for the replicates, in which it carries the effect of
estimating the coefficients. The p-value is the share of `n_sim`
multiplier replicates \$\$W^\*(u) = M^{-1/2} \hat J^{-1/2}
\Bigl\\\sum\_{i \le uM} g_i (1-\pi_i) h_i - A(u) V \sum_i g_i (1-\pi_i)
x_i\Bigr\\,\qquad g_i \sim N(0, 1),\$\$ with \\\sup_u \lVert
W^\*(u)\rVert^2 \ge T\_\psi\\ (Lin, Wei & Ying 1993, as in
[`gof_rem()`](https://franciscorichter.github.io/amorem/reference/gof_rem.md)).

## Usage

``` r
gof_multivariate(
  event_log,
  model,
  covariate,
  k_basis = 5,
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

  Named character vector of `<stat> = "linear"` mapping (for the rest of
  the model); the test target is `covariate` with a flexible smooth
  basis of dimension `k_basis - 1`.

- covariate:

  Name of the covariate to test under a smooth effect.

- k_basis:

  Spline-basis dimension for `covariate` (passed as `k` to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html); the resulting
  design matrix has `k_basis - 1` columns under thin-plate
  identifiability constraints).

- n_sim:

  Number of multiplier-bootstrap replicates for the p-value (default
  1000).

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

List with `statistic` (\\T\_\psi\\), `p_value`, `W` (n x q matrix), `u`,
`covariate` and `n_sim`. With `n_samples > 1`, `p_value` is the
Cauchy-combined p-value, `p_values` holds the per-sample p-values and
`n_samples` their number; the other fields are those of the first sample
(seed `seed`). With `n_samples = 1` the result is the single-sample
result, without `p_values` or `n_samples`.

## Details

The limit of \\W\\ is a Gaussian process with covariance set by how the
information \\A(u)\\ accumulates over the event sequence. It is a
standard \\q\\-dimensional Brownian bridge only when \\A(u)\\ grows in
proportion to \\u\\ in every direction, which fails for the spline
columns of a statistic that grows over the sequence (a count): the
columns for large values receive their information late. The multiplier
replicates have the covariance of the limit whatever the growth of
\\A(u)\\.

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
finite. The Monte Carlo p-values of `gof_multivariate()` and
[`gof_auxiliary()`](https://franciscorichter.github.io/amorem/reference/gof_auxiliary.md)
are first floored at \\1/(n\_{sim} + 1)\\ (`p_values` keeps the
unfloored values). Since \\T\\ is at most \\\max_s \tan\\\pi(1/2 -
p_s)\\\\, the combined p-value is then at least \\1/(n\_{sim} + 1)\\: a
combined p-value equal to that bound means \\p \< 1/n\_{sim}\\ in every
sample, and a smaller p-value needs a larger `n_sim`. The Kolmogorov
p-values of
[`gof_univariate()`](https://franciscorichter.github.io/amorem/reference/gof_univariate.md)
and
[`gof_global()`](https://franciscorichter.github.io/amorem/reference/gof_global.md)
are analytic and are not floored.

## References

Boschi M, Wit EC (2025). *Goodness of fit in relational event models*.
Statistics and Computing 36(4).

Lin DY, Wei LJ, Ying Z (1993). Checking the Cox model with cumulative
sums of martingale-based residuals. *Biometrika* 80(3), 557–572.
[doi:10.1093/biomet/80.3.557](https://doi.org/10.1093/biomet/80.3.557) .

Liu Y, Xie J (2020). Cauchy combination test: a powerful test with
analytic p-value calculation under arbitrary dependency structures.
*Journal of the American Statistical Association* 115(529), 393–402.
[doi:10.1080/01621459.2018.1554485](https://doi.org/10.1080/01621459.2018.1554485)
.

## Examples

``` r
if (requireNamespace("mgcv", quietly = TRUE)) {
  data(simulated_events)
  gof_multivariate(simulated_events,
    model = c(reciprocity_count  = "linear",
              transitivity_count = "linear"),
    covariate = "reciprocity_count", n_sim = 200, seed = 1)[c("statistic", "p_value")]
}
#> $statistic
#> [1] 1.514275
#> 
#> $p_value
#> [1] 0.435
#> 
```
