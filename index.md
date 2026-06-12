## amore ![](reference/figures/logo.png)

**Augmented Modelling of Relational Events** — end-to-end **simulation,
sampling, feature engineering, model selection, and inference** for
relational event models (REMs) in R, in one consistent API.

The package consolidates four lines of recent methodological work:

- **Dyadic REMs** with timing / closure variants and one- or two-axis
  actor frailty, following [Juozaitienė & Wit (2024,
  *JRSS-A*)](https://doi.org/10.1093/jrsssa/qnae132).
- **Relational Hyper Event Models** (RHEMs) with set-valued
  sender/receiver hyperedges, subset-repetition covariates, and smooth
  effects (linear / `tv` / `nl` / `tvnl`), following [Boschi, Lerner &
  Wit (2025)](https://arxiv.org/abs/2509.05289).
- **Global covariate effects** — covariates varying in time but constant
  across pairs — via the time-shifted partial likelihood of [Lembo,
  Juozaitienė, Vinciotti & Wit (2025,
  *JRSS-C*)](https://doi.org/10.1093/jrsssc/qlaf058).
- **Cumulative martingale-residual GOF tests**, following [Boschi & Wit
  (2025, *Stat & Comp*
  36:4)](https://doi.org/10.1007/s11222-025-10751-2).

## Installation

``` r

# install.packages("remotes")
remotes::install_github("franciscorichter/amore")
```

## 30-second tour

``` r

library(amore)

# 1. Bundled datasets, ready to load
data(classroom_events)        # 691 events,    20 actors  (McFarland 2001)
data(social_evolution_calls)  # 439 events,    54 actors  (Madan et al. 2011)
data(radoslaw_email)          # 82,927 emails, 167 actors (Michalski et al. 2014)

# 2. Compute endogenous features post-hoc from any (sender, receiver, time) log
feat <- compute_endogenous_features(
  classroom_events, stats = c("reciprocity", "recency"))

# 3. Simulate a ready-to-fit case-1-control table with known structure ...
w <- simulate_relational_events(
  n_events = 1500, senders = LETTERS[1:8], receivers = LETTERS[1:8],
  n_controls = 1, endogenous_stats = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = 0.4), wide = TRUE)

# 4. ... and fit it with the default "gam" backend
fit <- rem(~ reciprocity_count, data = w, method = "gam")
summary(fit)
```

## What’s inside

- **[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)**
  — the unified fitter for preprocessed case-control data, with a
  conditional-logit backend (case-*k*-control) and a `gam` backend
  (case-1-control) supporting linear / `tv` / `nl` / `tvnl` smooth
  effects and `re()` random effects, plus
  [`summary()`](https://rdrr.io/r/base/summary.html) /
  [`coef()`](https://rdrr.io/r/stats/coef.html) /
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).
  [`widen_case_control()`](https://franciscorichter.github.io/amore/reference/widen_case_control.md)
  reshapes a long case-control log into the wide form
  [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
  expects.
- **[`simulate_relational_events()`](https://franciscorichter.github.io/amore/reference/simulate_relational_events.md)**
  — exact Gillespie or τ-leap; composes exogenous, endogenous, and
  time-varying global covariates; with `wide = TRUE` emits a
  ready-to-fit case-1-control table.
- **[`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md)**
  — the endogenous catalogue computed post-hoc from any
  `(sender, receiver, time)` log; via `history_log` it scores sampled
  non-events without polluting the event history.
- **[`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md)**
  — nested case-control sampling with appearance / citation / remove
  risk-set rules.
- **Goodness of fit** —
  [`gof_global()`](https://franciscorichter.github.io/amore/reference/gof_global.md),
  [`gof_multivariate()`](https://franciscorichter.github.io/amore/reference/gof_multivariate.md),
  [`gof_auxiliary()`](https://franciscorichter.github.io/amore/reference/gof_auxiliary.md),
  and pointwise
  [`martingale_residuals()`](https://franciscorichter.github.io/amore/reference/martingale_residuals.md).
- The earlier
  [`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md),
  [`compare_models_smooth()`](https://franciscorichter.github.io/amore/reference/compare_models_smooth.md)
  and
  [`compare_models_global()`](https://franciscorichter.github.io/amore/reference/compare_models_global.md)
  remain available (superseded by
  [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)).

## Guides

| Guide | What you’ll find |
|----|----|
| [Quick start](https://franciscorichter.github.io/amore/articles/quick-start.md) | install + simulate-and-recover in a few lines |
| [Simulation](https://franciscorichter.github.io/amore/articles/simulation.md) | the dyadic mechanisms, Gillespie vs τ-leap |
| [Endogenous catalogue](https://franciscorichter.github.io/amore/articles/endogenous-catalogue.md) | the statistic catalogue and its variant axes |
| [Estimation](https://franciscorichter.github.io/amore/articles/estimation.md) | case-control sampling, the three [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md) backends — `clogit` (linear), `gam` (smooth `tv`/`nl`/`tvnl`/`re` effects), `nn` (neural conditional logit) — model comparison, GOF |
| [Hyperedge models](https://franciscorichter.github.io/amore/articles/hyperedge-models.md) | the `(I, J, time)` data model and RHEM simulators |
| [Datasets](https://franciscorichter.github.io/amore/articles/datasets.md) | the bundled REM datasets |
| [Real-data analysis](https://franciscorichter.github.io/amore/articles/real-data-analysis.md) | sender-frailty flip, smooth effect curves |
| [Validation experiments](https://franciscorichter.github.io/amore/articles/validation-experiments.md) | recovery, smooth, scaling, parity, and the neural backend (gradient check + interaction recovery) |

Full per-function documentation is under
[Reference](https://franciscorichter.github.io/amore/reference/index.md).

## References

- Juozaitienė R., Wit E.C. (2024). *It’s about time: revisiting
  reciprocity and triadicity in relational event analysis.* JRSS-A
  188(4), 1246–1262.
  [doi:10.1093/jrsssa/qnae132](https://doi.org/10.1093/jrsssa/qnae132).
- Boschi M., Lerner J., Wit E.C. (2025). *Beyond Linearity and
  Time-Homogeneity: Relational Hyper Event Models with Time-Varying
  Non-Linear Effects.* arXiv:2509.05289.
- Lembo M., Juozaitienė R., Vinciotti V., Wit E.C. (2025). *Relational
  Event Models with Global Covariates.* JRSS-C.
- Boschi M., Wit E.C. (2025). *Goodness of fit in relational event
  models.* Statistics and Computing 36(4).
