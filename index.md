## amore

End-to-end **simulation, sampling, feature engineering, model
selection, and inference** for relational event models (REMs) in R.

A Gillespie-style event simulator with three composable layers
(exogenous, endogenous, time-varying global covariates), a
parallel post-hoc feature engine that exposes the same
**41-statistic** endogenous catalogue — covering the full
continuous / ordered / exp-decay / interrupted family from
Juozaitienė & Wit (2024, *JRSS-A*) — and a one-call
[`compare_models()`](reference/compare_models.html) helper that
fits competing specifications and returns a tidy AIC table.

Three real-world REM datasets ship with the package, so the
documented workflows run on real data out of the box.

### 30-second tour

```r
library(amore)

# 1. Bundled datasets, ready to load
data(classroom_events)   # 691 events,    20 actors (McFarland 2001)
data(social_evolution_calls) # 439 events, 54 actors  (Madan et al. 2011)
data(radoslaw_email)     # 82,927 emails, 167 actors (Michalski et al. 2014)

# 2. Compute endogenous features post-hoc
feat <- compute_endogenous_features(
  classroom_events,
  stats = c("reciprocity_count", "reciprocity_time_recent_interrupted",
            "transitivity_count", "transitivity_time_recent_interrupted"))

# 3. Compare candidate specifications by AIC
compare_models(
  classroom_events,
  models = list(
    count       = c("reciprocity_count", "transitivity_count"),
    continuous  = c("reciprocity_time_recent", "transitivity_time_recent"),
    interrupted = c("reciprocity_time_recent_interrupted",
                    "transitivity_time_recent_interrupted")),
  seed = 11)

# 4. Simulate a stream with known endogenous structure
set.seed(2026)
sim <- simulate_relational_events(
  n_events = 1500,
  senders = LETTERS[1:8], receivers = LETTERS[1:8],
  baseline_rate = 1, allow_loops = FALSE,
  endogenous_stats   = c("reciprocity_count", "transitivity_count"),
  endogenous_effects = c(reciprocity_count = 0.4, transitivity_count = 0.2))
```

### What's inside

- **`simulate_relational_events()`** — exact Gillespie or τ-leap;
  composes exogenous, endogenous, and time-varying global
  covariates; emits plain event logs or stratified case–control
  data for partial-likelihood inference.
- **`compute_endogenous_features()`** — the same 41-stat catalogue
  computed post-hoc from any `(sender, receiver, time)` event log.
  Every shared name is cross-validated row-by-row against the
  simulator by `test-sim-vs-posthoc-parity.R`.
- **`sample_non_events()`** — nested case–control sampling with
  appearance / citation / remove risk-set rules.
- **`compare_models()`** — single-call AIC comparison across
  competing endogenous specifications, with `n_controls = 1`
  (binomial GLM on differences) or `n_controls > 1` (stratified
  conditional logistic via `survival::coxph`).
- **`standardize_event_log()`**, **`attach_static_covariates()`**,
  **`simulate_actor_covariates()`** — utilities for ingest and
  exogenous covariate engineering.

### The endogenous catalogue

Same 41-stat catalogue is exposed by both the simulator and the
post-hoc engine, organised by family × variant:

| Family            | count/binary | ordered | exp-decay | time (recent/first) | interrupted time |
|-------------------|:---:|:---:|:---:|:---:|:---:|
| Reciprocity       | ✓ | — | ✓ | ✓ | ✓ |
| Transitivity      | ✓ | ✓ | ✓ | ✓ | ✓ |
| Cyclic            | ✓ | — | ✓ | ✓ | ✓ |
| Sending balance   | ✓ | — | ✓ | ✓ | ✓ |
| Receiving balance | ✓ | — | ✓ | ✓ | ✓ |

The **reciprocity interrupted** column covers all five variants
(binary / count / exp-decay / time-recent / time-first); the four
closure families' interrupted column covers the *time-recent* and
*time-first* variants empirically preferred by Juozaitienė & Wit
(2024) Table 3. See [`?compute_endogenous_features`](reference/compute_endogenous_features.html)
for the full list.

### Where to next

- The [model-comparison vignette](articles/model-comparison.html)
  walks through the full pipeline on `classroom_events` and ends
  with a simulator → inference round-trip.
- The [endogenous-and-global vignette](articles/endogenous-and-global.html)
  composes endogenous mechanisms with time-varying global covariates.
- The [species-invasion vignette](articles/species-invasion.html)
  covers the `risk = "remove"` one-shot mode.
- The [whitepaper](https://github.com/franciscorichter/amore/blob/main/paper/whitepaper.pdf)
  has the full statistical methods, the validation experiments,
  smooth-effect curve replication, and the limitations / roadmap.

### Reference

Juozaitienė R, Wit EC (2024). It's about time: revisiting
reciprocity and triadicity in relational event analysis.
*JRSS-A* 188(4), 1246–1262. [doi:10.1093/jrsssa/qnae132](https://doi.org/10.1093/jrsssa/qnae132).
