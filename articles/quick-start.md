# Quick start

## Quick start

A 10-line tour of `amore`: simulate a relational event stream with a
known driver, then recover the driver’s coefficient from the emitted
case-control table.

Numbers shown below are actual output, re-run on every release.

### Install

From GitHub:

``` r

# install.packages("remotes")
remotes::install_github("franciscorichter/amore")
```

Hard dependencies: `Rcpp`, `survival` (for `coxph` / `clogit`), `mgcv`
(for smooth-effect curves). Suggested: `coxme` (two-axis random
effects).

### Simulate, then recover

A 20-actor network, 1200 events, with a single endogenous mechanism —
*reciprocity* at strength `β = 0.6`:

``` r

library(amore)
suppressPackageStartupMessages(library(survival))

set.seed(1)
cc <- simulate_relational_events(
  n_events           = 1200,
  senders            = paste0("a", 1:20),
  receivers          = paste0("a", 1:20),
  baseline_rate      = 1,
  n_controls         = 1,                 # one matched non-event per event
  endogenous_stats   = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = 0.6))

fit <- clogit(event ~ reciprocity_count + strata(stratum), data = cc)
coef(fit)
#> reciprocity_count 
#>             0.542
confint(fit)
#>                       2.5 %    97.5 %
#> reciprocity_count    0.349     0.734
```

The 95% interval `(0.35, 0.73)` covers the true coefficient `0.6`. The
simulator emits a **case-control table** directly (with one sampled
non-event per event when `n_controls = 1`), so the recovery step is a
single `clogit` call.

For preprocessed case-control data (e.g. from `eventnet`) the same fit,
the case-1-control degenerate-logistic variant, and smooth (TV / NL /
TVNL) effects are all available through one interface,
[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md) —
see
[Estimation](https://franciscorichter.github.io/amore/articles/estimation.md).

### Where to go next

| Page | What it covers |
|----|----|
| [Simulation](https://franciscorichter.github.io/amore/articles/simulation.md) | The five dyadic simulator modes and the hyperedge simulator for multi-actor meetings |
| [Endogenous catalogue](https://franciscorichter.github.io/amore/articles/endogenous-catalogue.md) | The 68-stat dyadic table plus hyperedge-native subset repetition |
| [Estimation](https://franciscorichter.github.io/amore/articles/estimation.md) | Case-control sampling, linear/smooth/global-covariate model comparison, GOF tests |
| [Hyperedge models](https://franciscorichter.github.io/amore/articles/hyperedge-models.md) | RHEMs with set-valued sender/receiver hyperedges |
| [Real-data analysis](https://franciscorichter.github.io/amore/articles/real-data-analysis.md) | Classroom, Manufacturing, frailty, smooth effects |
| [Validation experiments](https://franciscorichter.github.io/amore/articles/validation-experiments.md) | Parity tests + MLE recovery + scaling |
| [Datasets](https://franciscorichter.github.io/amore/articles/datasets.md) | The three bundled REM datasets and their provenance |
