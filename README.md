# amore

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="man/figures/logo-github-dark.png">
    <img src="man/figures/logo-github-white.png" width="220" alt="amore logo" />
  </picture>
</p>

<p align="center">
  <a href="https://github.com/franciscorichter/amore/actions/workflows/R-CMD-check.yaml"><img src="https://github.com/franciscorichter/amore/actions/workflows/R-CMD-check.yaml/badge.svg" alt="R-CMD-check" /></a>
  <a href="https://franciscorichter.github.io/amore/"><img src="https://img.shields.io/badge/docs-pkgdown-blue" alt="pkgdown docs" /></a>
  <img src="https://img.shields.io/badge/status-prototype-blue" alt="status prototype" />
</p>

**amore** (Augmented Modelling of Relational Events) is an R package for **simulation and inference** in relational event models (REMs) and relational *hyper* event models (RHEMs). It targets dynamic network data in continuous time, with a focus on reproducible workflows: event logs, covariates, model fitting, and diagnostics.

Two complementary lines are supported under one case-control inference machinery:

- **Dyadic REMs** with timing / closure variants and actor-heterogeneity corrections, following [Juozaitienė & Wit (2024, *JRSS-A* 188(4))](https://doi.org/10.1093/jrsssa/qnae132).
- **Relational hyper event models** (set-valued senders × receivers) with subset-repetition covariates and smooth (linear / TVE / NLE / TVNLE) effects, following [Boschi, Lerner & Wit (2025, arXiv:2509.05289)](https://arxiv.org/abs/2509.05289).

## What it aims to provide

- **Simulation** utilities for relational event streams and exogenous covariates.
- **Inference** tools for fitting REMs and working with likelihood-based / counting-process formulations.
- **Covariate engineering** helpers for both exogenous and endogenous statistics (e.g., reciprocity, recency, shared partners), in a consistent API.

## Current capabilities

The package already supports the end-to-end workflow needed for exploratory and
simulation-based REM studies:

- **Data intake and cleaning.** `standardize_event_log()` harmonizes raw logs,
  drops loops/duplicates, and tags them as `amore_event_log` objects.
- **Exogenous actor covariates.** `simulate_actor_covariates()` generates static
  or AR(1) dynamic traits, while `attach_static_covariates()` merges user data.
- **Endogenous covariates.** Both the simulator and the post-hoc
  `compute_endogenous_features()` engine expose the full **68-stat**
  catalogue covering every paper definition from Juozaitienė & Wit
  (2024): reciprocity / transitivity / cyclic / sending balance /
  receiving balance, each across seven variant axes (count, binary,
  exp-decay, time-recent, time-first, ordered, interrupted). The
  C++ inner loop accelerates 46 of 68 stats on the post-hoc side
  (timing, exp-decay, interrupted families); the remaining 22
  ordered variants take the pure-R path. See *Endogenous network
  statistics* below for the full per-family tables.
- **Hyperedge data model.** `hyperedge_log()` accepts `(I, J, time)`
  events with set-valued senders and receivers. Functions
  `hyperedge_activity()` and `hyperedge_subrep()` implement the
  subset-repetition family of Boschi et al. (2025); the feature
  engine `compute_hyperedge_features()` exposes them as named
  stats (`activity`, `subrep_<rho>_<l>`, `subrep_<rho>`) and
  delegates dyadic-catalogue names to `compute_endogenous_features()`
  via `as_dyadic_log()`. The hyperedge simulator
  `simulate_hyperedge_events()` generates undirected multi-actor
  meetings.
- **Relational event simulation.** `simulate_relational_events()` runs
  two simulation algorithms — the default exact Gillespie
  (`method = "gillespie"`) and an approximate time-driven tau-leap
  (`method = "tau_leap", tau = ...`) — with optional case-control
  output, the full 68-stat endogenous catalogue wired into the inner
  loop, time-varying global covariates via a boundary-aware scheme
  (weekday/weekend rate switches, policy regimes, …), and a
  `risk = "remove"` rule for one-shot processes such as species
  invasions or first-citation events. The per-actor family
  (`recency`, `sender_outdegree`, `receiver_indegree`) works in
  bipartite / two-mode settings; the closure families (reciprocity,
  transitivity, cyclic, sending / receiving balance) currently
  require one-mode networks.
- **Non-event sampling.** `sample_non_events()` constructs nested
  case-control tables with appearance, citation, and remove risk-set
  rules.
- **Model comparison.** Two helpers share one case-control sample so
  AIC values are directly comparable across specifications:
  `compare_models()` for linear AIC tables with optional one-axis
  (`survival::frailty`) or two-axis (`coxme::coxme`) actor random
  effects; `compare_models_smooth()` for `linear` / `tv` / `nl` /
  `tvnl` effect choices per stat via `mgcv::gam`, following the
  Boschi et al. (2025) Section 3.3 design.
- **Bundled real-world datasets.** Four of the five datasets analysed
  in Juozaitienė & Wit (2024) ship under `data/` and `inst/extdata/`
  (`classroom_events`, `social_evolution_calls`, `radoslaw_email`,
  with their actor-covariate tables) so the package's documented
  workflows run on real REM data out of the box.
- **Cross-implementation parity.** Every shared statistic between the
  simulator and `compute_endogenous_features()` is guarded by a
  dedicated parity test (`test-sim-vs-posthoc-parity.R`) that runs
  the simulator on synthetic events and verifies the post-hoc engine
  reproduces every output column row-for-row.
- **Documentation + tests.** A nine-page wiki
  ([franciscorichter/amore/wiki](https://github.com/franciscorichter/amore/wiki))
  with verified, plot-rich coverage of every workflow, plus a
  ~3,000-assertion test suite that runs on every commit.

## Installation

```r
# install the development version from GitHub
# install.packages("pak")
pak::pak("franciscorichter/amore")

# alternatively, install from a local checkout
install.packages(".", repos = NULL, type = "source")
```

```r
library(amore)
```

## Quick start

The Gillespie algorithm generates relational events where inter-event
times are exponentially distributed with rate equal to the sum of all
dyadic hazards, and dyads are selected proportionally to their intensity.

```r
library(amore)
set.seed(1)

p      <- 20
actors <- as.character(1:p)

# Dyadic covariate x ~ N(0,1) with true effect b1 = 1
x            <- matrix(rnorm(p * p), nrow = p, ncol = p)
b1           <- 1
contribution <- b1 * x

# Simulate 500 events + 1 control per event for partial likelihood
events <- simulate_relational_events(
  n_events            = 500,
  senders             = actors,
  receivers           = actors,
  contribution_logits = contribution,
  allow_loops         = FALSE,
  n_controls          = 1
)

head(events)
```

## Core data components

Module A (Preprocesses) organizes dynamic network workflows around four
objects that can be composed as needed:

1. **Relational event data** — canonical log with `sender`, `receiver`,
   `time`, produced via simulations or ingested from data sources.
2. **Exogenous covariates** — actor or dyad-level inputs not generated by
   the event process (e.g., geography, demographics). These can be
   simulated via `simulate_actor_covariates()` or supplied as
   `contribution_logits`/lookup tables.
3. **Endogenous covariates (eventnet)** — summaries derived from the
   evolving event history (recency, reciprocity, shared partners). Use
   `compute_endogenous_features()` to generate baseline statistics that can
   be extended with custom feature builders.
4. **Inference data** — nested case-control tables returned by
   `simulate_relational_events(..., n_controls > 0)` to drive conditional
   logistic / GAM estimation.

A small preprocessing example:

```r
library(amore)

# 1. Event log direct from a data source
raw_events <- data.frame(
  source = c("a", "b", "b", "c"),
  target = c("b", "c", "a", "a"),
  ts = c(2.1, 2.4, 3.0, 3.5)
)

event_log <- standardize_event_log(
  raw_events,
  sender_col = "source",
  receiver_col = "target",
  time_col = "ts",
  drop_loops = TRUE
)
```

```r
# 2. Exogenous covariates
covs <- simulate_actor_covariates(
  senders = unique(event_log$sender),
  receivers = unique(event_log$receiver),
  covariate_names = c("activity", "popularity"),
  seed = 123
)

event_log <- attach_static_covariates(
  event_log,
  sender_covariates = covs$sender_covariates,
  receiver_covariates = covs$receiver_covariates
)
```

```r
# 3. Endogenous stats from the evolving event net
event_log <- compute_endogenous_features(event_log,
  stats = c("sender_outdegree", "receiver_indegree", "reciprocity", "recency")
)
```

### Exogenous covariate definitions

`simulate_actor_covariates()` returns two lookup tables with one row per actor.
For a sender/receiver and a given covariate name:

- **Static covariates** (default) are independent Gaussian draws centered at
  zero. `attach_static_covariates()` stores them in the event log as
  `sender_<name>` or `receiver_<name>`. In the example, `activity` represents a
  baseline propensity for sending events and `popularity` captures how
  attractive an actor is as a receiver.
- **Dynamic covariates** arise when `time_points` is supplied. Each actor and
  covariate follows an AR(1) trajectory controlled by the `rho` and `sd`
  arguments, so values drift smoothly through time while remaining correlated
  from one time stamp to the next.

### Endogenous network statistics

All endogenous summaries are evaluated immediately **before** an event is
logged.  They follow the taxonomy of
[Juozaitienė & Wit (2025, JRSS-A)](https://doi.org/10.1093/jrsssa/qnae132)
and use the *continuous* convention (effects persist even after a closure
event).  Pass one or more stat names to `compute_endogenous_features()`.

**Degree / baseline**

| Stat name | Description |
|-----------|-------------|
| `sender_outdegree` | Number of events the sender has issued so far. |
| `receiver_indegree` | Number of events the receiver has received so far. |
| `recency` | Elapsed time since the last event on the same ordered pair; `NA` when the dyad is brand new. |

**Reciprocity** — history of the reverse dyad (receiver → sender).
Continuous variants persist after a closure event; *interrupted*
variants reset to zero (or `NA` for time-* slots) each time the
same-direction dyad (sender → receiver) fires.

| Stat name | Description |
|-----------|-------------|
| `reciprocity` / `reciprocity_binary` | 1 if the reverse dyad has ever been observed, 0 otherwise. |
| `reciprocity_count` | Total number of past reverse-dyad events. |
| `reciprocity_exp_decay` | Exponentially weighted sum of past reverse-dyad events; older events contribute less according to `half_life`. |
| `reciprocity_time_recent` | Elapsed time since the most recent reverse-dyad event; `NA` if none. |
| `reciprocity_time_first` | Elapsed time since the first reverse-dyad event; `NA` if none. |
| `reciprocity_binary_interrupted` | Interrupted variant of `reciprocity_binary` (paper r^(1i)). |
| `reciprocity_count_interrupted` | Interrupted variant of `reciprocity_count` (paper r^(2i)). |
| `reciprocity_exp_decay_interrupted` | Interrupted variant of `reciprocity_exp_decay` (paper r^(3i)). |
| `reciprocity_time_recent_interrupted` | Interrupted variant of `reciprocity_time_recent` (paper r^(4ai)). |
| `reciprocity_time_first_interrupted` | Interrupted variant of `reciprocity_time_first` (paper r^(4bi)). |

**Transitivity** — two-path s → k → r (the sender previously contacted
some intermediary k who in turn contacted the receiver)

| Stat name | Description |
|-----------|-------------|
| `transitivity_binary` | 1 if any such intermediary k exists, 0 otherwise. |
| `transitivity_count` | Number of distinct intermediaries. |
| `transitivity_binary_ordered` | Like binary, but requiring the s → k event to precede the k → r event in time. |
| `transitivity_count_ordered` | Count with order restriction. |
| `transitivity_exp_decay` | Exp-decay weighted sum over two-paths (requires `half_life`). |
| `transitivity_exp_decay_ordered` | Exp-decay with order restriction. |
| `transitivity_time_recent` | Time since the most recently formed two-path; `NA` if none. |
| `transitivity_time_first` | Time since the first-ever two-path; `NA` if none. |
| `transitivity_time_recent_ordered` | Time since the most recent ordered two-path; `NA` if none. |
| `transitivity_time_first_ordered` | Time since the first-ever ordered two-path; `NA` if none. |
| `transitivity_time_recent_interrupted` | Interrupted variant (paper t^(7ai)): time since the most recent two-path since the most recent closure event s → r. |
| `transitivity_time_first_interrupted` | Interrupted variant (paper t^(7bi)): time since the first two-path since the most recent closure event s → r. |

**Cyclic closure** — two-path r → k → s, closed by event s → r (the
receiver previously contacted k, and k previously contacted the sender)

| Stat name | Description |
|-----------|-------------|
| `cyclic_binary` | 1 if any cyclic two-path exists, 0 otherwise. |
| `cyclic_count` | Number of cyclic intermediaries. |
| `cyclic_exp_decay` | Exp-decay weighted sum over cyclic two-paths (paper c^(5c)). |
| `cyclic_time_recent` | Time since the most recent cyclic two-path formation; `NA` if none. |
| `cyclic_time_first` | Time since the first-ever cyclic two-path; `NA` if none. |
| `cyclic_time_recent_interrupted` | Interrupted variant of `cyclic_time_recent`. |
| `cyclic_time_first_interrupted` | Interrupted variant of `cyclic_time_first`. |

**Sending balance** — shared target: both s → k and r → k exist (the
sender and receiver have both contacted the same third actor k)

| Stat name | Description |
|-----------|-------------|
| `sending_balance_binary` | 1 if any shared target exists, 0 otherwise. |
| `sending_balance_count` | Number of shared targets. |
| `sending_balance_exp_decay` | Exp-decay weighted sum over shared-target two-paths (paper sb^(5c)). |
| `sending_balance_time_recent` | Time since the most recent shared-target two-path formation; `NA` if none. |
| `sending_balance_time_first` | Time since the first-ever shared-target two-path; `NA` if none. |
| `sending_balance_time_recent_interrupted` | Interrupted variant (paper sb^(7ai)). |
| `sending_balance_time_first_interrupted` | Interrupted variant (paper sb^(7bi)). |

**Receiving balance** — shared source: both k → s and k → r exist (the
sender and receiver have both been contacted by the same third actor k)

| Stat name | Description |
|-----------|-------------|
| `receiving_balance_binary` | 1 if any shared source exists, 0 otherwise. |
| `receiving_balance_count` | Number of shared sources. |
| `receiving_balance_exp_decay` | Exp-decay weighted sum over shared-source two-paths (paper rb^(5c)). |
| `receiving_balance_time_recent` | Time since the most recent shared-source two-path formation; `NA` if none. |
| `receiving_balance_time_first` | Time since the first-ever shared-source two-path; `NA` if none. |
| `receiving_balance_time_recent_interrupted` | Interrupted variant (paper rb^(7ai)). |
| `receiving_balance_time_first_interrupted` | Interrupted variant (paper rb^(7bi)). |

All `*_exp_decay` statistics require a `half_life` argument that controls
how quickly the influence of past events diminishes.

```r
# 4. Inference-ready case-control data
cases_controls <- simulate_relational_events(
  n_events = 100,
  senders = unique(event_log$sender),
  receivers = unique(event_log$receiver),
  contribution_logits = matrix(0, nrow = 3, ncol = 3),
  allow_loops = FALSE,
  n_controls = 1
)
```

### Sampling non-events from observed logs

To create case-control tables from empirical event data, use
`sample_non_events()` to append synthetic controls to each realized event:

```r
case_control_df <- sample_non_events(
  event_log,
  n_controls = 2,
  scope = "appearance",
  mode = "two",
  allow_loops = FALSE,
  seed = 2026
)

head(case_control_df[, c("sender", "receiver", "event", "stratum")])
```

The helper keeps the original events (`event = 1`) and appends `n_controls`
counterfactual dyads (`event = 0`) per stratum so conditional logistic / GAM
estimators can compare realized vs. sampled alternatives. Candidate dyads are
constructed via two knobs plus an optional risk-set rule:

1. **scope**
   - `"all"`: every actor ever seen in the data belongs to the sampling pool.
   - `"appearance"`: only actors that have appeared prior to the focal event are
     eligible, which mimics nested case-control sampling.
2. **mode**
   - `"one"`: draw both sender and receiver from the same candidate set (useful
     for single-mode networks).
   - `"two"`: draw senders and receivers from separate candidate pools (default
     for bipartite or directed settings).
3. **risk**
   - `"standard"`: risk set never shrinks beyond the chosen scope.
   - `"remove"`: once a realized dyad `(s_i, r_i)` occurs, it is removed from
     consideration in later strata (e.g., species invasion that cannot repeat).

Set `allow_loops = TRUE` when self-ties should be considered and adjust
`max_attempts` to control resampling when many candidate pairs coincide with the
observed event.

The three sampling schemes we discussed earlier map directly onto these knobs:

| Strategy label                | `scope`         | `mode`                    |
|------------------------------|-----------------|---------------------------|
| **all + one-mode**           | `"all"`        | `"one"`                |
| **all + two-mode**           | `"all"`        | `"two"`                |
| **appearance + one/two-mode**| `"appearance"` | `"one"` or `"two"`    |
| **citation**                 | `"citation"`   | typically `"two"`       |
| **remove one/two-mode**      | `"all"` or `"appearance"` | `"one"` / `"two"`; set `risk = "remove"` |

The last option is listed twice because you may want either a single-mode or a
two-mode draw while still restricting to previously active actors.

For the citation sampler, senders are the papers that debut at the event time
while receivers must have appeared strictly earlier. The `risk = "remove"` flag
deletes realized dyads from future candidate sets to mimic one-off events such as
biological invasions. Regardless of the configuration, each stratum contains the
observed event (`event = 1`) followed by its sampled controls (`event = 0`), so
conditional likelihood estimators can contrast what happened with what could have
happened instead.

### Inference with GAM

The case-control output lets you recover parameters via a GAM:

```r
library(mgcv)

get_x  <- function(s, r) x[cbind(as.integer(s), as.integer(r))]
events$x_val <- mapply(get_x, events$sender, events$receiver)

cases    <- events[events$event == 1, ]
controls <- events[events$event == 0, ]
cases    <- cases[order(cases$stratum), ]
controls <- controls[order(controls$stratum), ]

fit_df <- data.frame(y = 1, delta_x = cases$x_val - controls$x_val)
fit    <- gam(y ~ delta_x - 1, family = binomial, data = fit_df)

coef(fit)
#> delta_x ≈ 1  (recovers b1)
```

### Exogenous dyadic covariates

The package ships a 56 × 56 US state distance matrix and supports
non-linear effects via `contribution_logits`.  For example, using geographic
distance with a smooth true effect:

```r
data("dist_matrix", package = "amore")

dist_log     <- log(dist_matrix / 100000 + 1)
true_effect  <- sin(-dist_log / 1.5)

events <- simulate_relational_events(
  n_events        = 800,
  senders         = rownames(dist_matrix),
  receivers       = rownames(dist_matrix),
  contribution_logits = true_effect,
  allow_loops     = FALSE,
  n_controls      = 1
)
```

See the [Simulation](https://github.com/franciscorichter/amore/wiki/Simulation)
wiki page for the full workflow including GAM recovery of the non-linear
distance effect.

### Endogenous mechanisms during simulation

`simulate_relational_events()` can also drive the next-event rate from the
realized history. Pass `endogenous_stats` and matching `endogenous_effects`:

```r
set.seed(2024)
actors <- as.character(1:10)

cc <- simulate_relational_events(
  n_events            = 1500,
  senders             = actors,
  receivers           = actors,
  baseline_rate       = 1,
  allow_loops         = FALSE,
  n_controls          = 1,
  endogenous_stats    = "reciprocity_count",
  endogenous_effects  = 0.6
)

head(cc[, c("stratum", "event", "sender", "receiver", "reciprocity_count")])
```

The output gains one column per stat carrying the value each row's dyad had
at its event time, so the coefficient is directly recoverable by conditional
logistic / GAM regression on the case–control table (see
`tests/testthat/test-endogenous-simulation.R`). The simulator's
`endogenous_stats` argument accepts the full 41-stat catalogue documented
under *Endogenous network statistics* above; each stat is also computable
post-hoc by `compute_endogenous_features()`, with every shared name
cross-validated by `test-sim-vs-posthoc-parity.R`.

### Time-varying global covariates

Global covariates (e.g. weekday vs weekend, weather regime, policy state)
take the same value for every dyad at a given time but vary over time. Pass
a `global_covariates` table with a `time_start` column plus one column per
covariate, together with matching `global_effects`:

```r
set.seed(1)
gc <- data.frame(
  time_start = seq(0, 10, by = 1),
  weekday    = rep(c(0, 1), length.out = 11)
)

ev <- simulate_relational_events(
  n_events           = 200,
  senders            = letters[1:5],
  receivers          = letters[1:5],
  baseline_rate      = 0.3,
  horizon            = 11,
  global_covariates  = gc,
  global_effects     = c(weekday = 2)
)

mean(ev$weekday == 1)  # share of events in weekday=1 intervals
```

Under the hood the simulator uses a **boundary-aware Gillespie** scheme: if
a sampled waiting time would cross an interval boundary, the clock is
advanced to the boundary without recording an event and the next waiting
time is redrawn under the new global multiplier. Dyad-selection
probabilities are unchanged (the global factor multiplies all rates
equally), only the inter-event timing reflects the time-varying global
state. Each output row carries the global covariate values it experienced
at its event time, and the feature composes with the endogenous machinery
above so both can be active simultaneously.

### Tau-leap simulator

`simulate_relational_events()` offers a second algorithm:

```r
ev <- simulate_relational_events(
  n_events       = 1000,
  senders        = letters[1:6],
  receivers      = letters[1:6],
  baseline_rate  = 1,
  method         = "tau_leap",
  tau            = 0.05
)
```

Instead of drawing one waiting time at a time (Gillespie), the tau-leap
algorithm advances the clock by a fixed `tau` and Poisson-samples the
number of events on each dyad in `[t, t+tau)` using the rates at the
start of the step. As `tau` → 0 the distribution converges to exact
Gillespie. Tau-leap is most useful when the per-event recomputation in
the Gillespie path dominates wall-clock — for example, in high-rate
regimes or with a large endogenous state space. Choose `tau` small
enough that (a) `lambda * tau << 1` on every active dyad and (b) `tau`
is smaller than the shortest interval in `global_covariates`; within-step
global-boundary crossings are not resolved.

All features (case-control sampling, endogenous mechanisms, global
covariates, output columns) compose with both algorithms.

### Bundled real-world REM datasets

Four of the five empirical datasets analysed in
[Juozaitienė & Wit (2024)](https://doi.org/10.1093/jrsssa/qnae132)
ship directly with the package, both as tidy event tables in `data/`
(loadable via `data(...)`) and as their original raw sources under
`inst/extdata/`:

| Dataset | Event table | Events | Actors | Source |
|---------|-------------|-------:|------:|--------|
| Classroom session | `classroom_events` | 691 | 20 | McFarland (2001) via `networkDynamic` |
| Social Evolution phone calls | `social_evolution_calls` | 439 | 54 | Madan et al. (2011) via `goldfish` |
| Manufacturing emails | `radoslaw_email` | 82,927 | 167 | Michalski et al. (2014) via Network Repository |

Each dataset comes with a companion actor-covariate table where
appropriate (`classroom_actors`, `social_evolution_actors`). Times are
normalised to minutes (Classroom) or days since the first event;
original Unix epochs are preserved as a `unix_origin` attribute. The
Enron email dataset of the original paper is intentionally not
bundled because the only publicly archived version is an aggregated
daily edge-weight table, not the event-level slice the paper
analyses.

### Comparing candidate specifications by AIC

`compare_models()` runs the full case-control + binomial-GLM
pipeline across a list of candidate specifications and returns a
tidy AIC table. The single case-control sample is shared across
every spec so AIC values are directly comparable:

```r
data(classroom_events)
compare_models(
  classroom_events,
  models = list(
    count       = c("reciprocity_count", "transitivity_count"),
    continuous  = c("reciprocity_time_recent", "transitivity_time_recent"),
    interrupted = c("reciprocity_time_recent_interrupted",
                    "transitivity_time_recent_interrupted")),
  seed = 11)
#>         model n_terms n_obs   log_lik     AIC delta_AIC
#> 1       count       2   691 -305.5234 615.047    0.0000
#> 2  continuous       2   691 -421.1244 846.249  231.2017
#> 3 interrupted       2   691 -439.6917 883.383  268.3367
```

The [Estimation](https://github.com/franciscorichter/amore/wiki/Estimation)
and [Real-data analysis](https://github.com/franciscorichter/amore/wiki/Real-data-analysis)
wiki pages walk through the full workflow, including how to inspect
coefficients of a chosen specification, how sender frailty flips the
AIC ranking on Classroom, and a simulator → inference round-trip that
recovers the true generative spec.

## Documentation

The **wiki** is the canonical reference and is re-run on every release:
<https://github.com/franciscorichter/amore/wiki>

| Page | What you'll find |
|---|---|
| [Quick start](https://github.com/franciscorichter/amore/wiki/Quick-start) | install + a 10-line simulate-and-recover example |
| [Simulation](https://github.com/franciscorichter/amore/wiki/Simulation) | the five dyadic mechanisms, Gillespie vs τ-leap |
| [Endogenous catalogue](https://github.com/franciscorichter/amore/wiki/Endogenous-catalogue) | the 68-stat catalogue, six variant axes side-by-side |
| [Hyperedge models](https://github.com/franciscorichter/amore/wiki/Hyperedge-models) | `(I, J, time)` data model, subset repetition, two simulators |
| [Estimation](https://github.com/franciscorichter/amore/wiki/Estimation) | case-control sampling, `compare_models*()`, GOF tests |
| [Datasets](https://github.com/franciscorichter/amore/wiki/Datasets) | five bundled REM datasets with descriptive plots |
| [Real-data analysis](https://github.com/franciscorichter/amore/wiki/Real-data-analysis) | sender-frailty flip, smooth effect curves |
| [Validation experiments](https://github.com/franciscorichter/amore/wiki/Validation-experiments) | recovery, smooth, scaling, parity |

Other entry points:

- Issue tracker: <https://github.com/franciscorichter/amore/issues>
- Per-function help inside R:

  ```r
  ?simulate_relational_events
  ?compare_models
  ?gof_univariate
  ```

## Development

- During development, work from the package root and let R load the in-tree
  code with:

  ```r
  devtools::load_all()
  ```

- Document + namespace: `devtools::document()`
- Tests: `devtools::test()`
- Full check: `devtools::check()`
- Build pkgdown site: `pkgdown::build_site()`

## References

Methodological background for the models implemented in **amore**:

- Bianchi, F., Filippi-Mazzola, E., Lomi, A., & Wit, E. C. (2024). Relational
  Event Modeling. *Annual Review of Statistics and Its Application*, 11,
  297–319. <https://doi.org/10.1146/annurev-statistics-040722-060248>
- Boschi, M., & Wit, E. C. (2026). Introduction to Relational Event Modelling.
  *arXiv:2604.07063*. <https://arxiv.org/abs/2604.07063>
- Juozaitienė, R., & Wit, E. C. (2024). Relational event modelling with
  timing, closure and actor-heterogeneity effects.
  *Journal of the Royal Statistical Society Series A*, 188(4).
  <https://doi.org/10.1093/jrsssa/qnae132>
- Boschi, M., Lerner, J., & Wit, E. C. (2025). Relational hyper event models
  with time-varying non-linear effects. *arXiv:2509.05289*.
  <https://arxiv.org/abs/2509.05289>

## License

MIT, see `LICENSE`.
