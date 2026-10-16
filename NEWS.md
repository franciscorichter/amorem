# amorem 1.1.0

## Bug fixes

* **Endogenous statistics on case-control data no longer count the sampled
  controls as events.** `endogenous_features()` on the output of
  `sample_non_events()` (a 0/1 `event` column with control rows) now builds
  the network history from the `event == 1` rows only; the controls read it
  but never enter it. Before, every row updated the history, so each
  statistic also counted hypothetical dyads. This was the default path inside
  `compare_models()`, `compare_models_smooth()`, `gof()`,
  `martingale_residuals()` and the vignettes. On six simulated datasets with
  a reciprocity effect of 0.3, the estimate moved from 0.20 to 0.31 on
  average. Results of those functions change and should be re-run. Pass
  `history_log = event_log` to treat every row as an event.

* **`rem()` evaluates `tv()` and `tvnl()` terms at each row's own time.**
  When `data` has `time_ev` / `time_nv` instead of a single time column (the
  wide form of `sample_non_events(shift = "exponential")`), `tv(x)`
  contributes `beta(t) x_ev - beta(t*) x_nv` and `tvnl()` uses both times.
  Before, the event time was used for both rows. Models with a single time
  column give the same formula and fit as before.

* **`compare_models_global()` now uses the paper's time-shifted design.** It
  drew one shift per control row, never shifted the event, never checked the
  observation window (control times could precede the data), evaluated the
  controls' dyadic statistics at the event time, and let sampled controls
  enter the network history. On simulated data with a global effect of 1 it
  returned estimates of -1.74, 2.63 and -2.12 over three datasets. It now
  draws its sample with `sample_non_events(shift = "exponential")`, computes
  dyadic statistics against the real history at each row's own time,
  evaluates `tv` / `tvnl` terms at each row's own time, and drops events with
  no control; the same three datasets give 0.85, 1.02 and 1.01. The shift
  mean is now `shift_scale` times the average event time (it was times the
  average inter-arrival time), and a `window` argument is passed through.
  Results of earlier `compare_models_global()` fits change and should be
  re-run.

* `widen_case_control()` and the `clogit` / `nn` backends of `rem()` use the
  `stratum` column written by `sample_non_events()` when `stratum = NULL`,
  instead of rebuilding strata as `cumsum(case == 1)`. The rebuilt strata
  assumed each case was followed by its controls, which stops holding once
  `endogenous_features()` re-sorts rows by time with ties, or with shifted
  controls, and then paired cases with the wrong controls. Data without a
  `stratum` column (eventnet output) is handled as before.

* **`sample_non_events()` risk-set edge cases (#102).**
  - `exclude_pairs` and, under `risk = "remove"`, same-time events are now part
    of the check for whether any valid control exists, so a stratum whose every
    alternative is excluded gets no controls instead of stopping with "Unable
    to sample a valid non-event after `max_attempts` attempts".
  - `scope = "appearance"` no longer falls back to all actors when no actor
    has appeared yet: the first event gets no controls, and controls are only
    ever drawn from actors seen in prior events, as documented. Results change
    for the first stratum(s) of `scope = "appearance"` fits.
  - Factor `sender` / `receiver` columns are coerced to character, so the
    output columns are character whatever the input type.
  - The documentation of `mode` states which risk set each mode gives: `"two"`
    never draws a receiver-only actor as a control sender (or vice versa), so
    networks with one node set should use `mode = "one"`.
  - The unreachable empty-pool fallbacks in the pair sampler were removed.

## Changes in behaviour

* `sample_non_events()` now defaults to `mode = "one"`, the risk set of
  networks whose senders and receivers are one node set, and the default of
  `compare_models()`, `compare_models_smooth()`, `compare_models_global()`,
  `gof()` and `martingale_residuals()`. Calls that relied on the old default
  `mode = "two"` (bipartite networks) must now pass it.

## New features

* **New dataset `enso_nino34`:** the tree-ring reconstruction of the
  November–January Niño3.4 sea-surface temperature anomaly by Li et al.
  (2013), one value per year from 1301 to 2005 (NOAA NCEI study 14632), as a
  global covariate on a yearly clock. The raw NOAA file ships in
  `inst/extdata/enso_nino34/`, and `data-raw/enso_nino34.R` rebuilds the
  object.

* `vignette("species-invasion")` now simulates five centuries of invasions
  (1500–2005) driven by distance, a neighbour pressure and ENSO. It shows
  that ordinary case-control sampling gives an ENSO difference of zero in
  every stratum, and recovers all three effects with time-shifted sampling
  and `rem()`, reporting standard errors.

* **Time-shifted case-control sampling for global covariates (#101).**
  `sample_non_events(shift = "exponential")` implements Section 4 of Lembo,
  Juozaitienė, Vinciotti & Wit (2025, JRSS-C): one exponential shift per dyad,
  each control drawn uniformly from the dyads whose back-shifted time lies in
  the observation `window` and stored at that time, so covariates that depend
  only on time no longer cancel within strata. `shift_scale` sets the mean
  shift as a multiple of the average event time, as in the paper. Risk-set
  rules (`exclude_pairs`, `risk = "remove"`, `scope = "appearance"`) are
  evaluated at the control's own time; events with no other dyad in their
  shifted risk set get no control and are listed in
  `attr(, "shift")$uninformative`. The attribute also holds the shift mean,
  the window and the per-dyad shifts.

* `endogenous_features(history_log = )` and `prior_log` now work for every
  statistic, including `reciprocity_exp_decay`, `reciprocity_time_recent` and
  `reciprocity_time_first`, which the compiled engine does not cover.

* **Per-term basis settings in `rem()` formulas (#91).** Smooth terms take the
  basis arguments of `mgcv::s()` / `mgcv::te()` after the covariate, so terms
  in one model can use different basis dimensions and types:
  `tv(x, k = 20, bs = "cr") + nl(y, k = 5, bs = "ps")`. `tvnl()` takes one
  value per margin (`tvnl(x, k = c(5, 8))`). A new global `bs` argument joins
  the global `k` as the default for terms that set neither; existing formulas
  give the same model as before.

* `sample_non_events(exclude_concurrent = )` controls whether dyads with an
  event at the focal event's own time can be controls. The default keeps the
  existing behaviour: excluded under `risk = "remove"`, at risk under
  `risk = "standard"` (the Breslow convention).

# amorem 1.0.1

## Bug fixes

* **`compare_models()` did not stratify on the matched sets under **survival**
  before 3.7-3.** The Cox formula was built with a namespace-qualified
  `survival::strata(stratum)`, and `terms(specials = )` does not match a
  qualified call, so the matched-set identifier was silently fitted as an
  ordinary factor covariate in an unstratified model. Coefficients and the
  `delta_AIC` column were unaffected; the absolute `log_lik` was shifted by
  `-n_events * log(n_strata)` and the degrees of freedom inflated by
  `n_strata - 1`, so reported `AIC` values were wrong. The same applied to the
  `frailty()` terms on the random-effects path, which is why the `coxme`
  two-axis fit did not complete. All four call sites now use bare specials,
  which every **survival** version matches, and regression tests assert that
  `AIC == -2 * log_lik + 2 * df` and that no stratum dummies enter as
  covariates. Anyone who published absolute log-likelihood or AIC values from
  `compare_models(n_controls > 1)` should re-run them.

# amorem 1.0.0

First CRAN release, under the name **amorem**. The package was renamed from the
working name `amore`, which collided (case-insensitively) with the archived CRAN
package `AMORE`. This release consolidates the 0.9.0 development line into the
first stable, installable version: the unified `rem()` front-end (the `clogit`,
`gam`, and `nn` backends, including the additive-spline architecture), the
Gillespie / tau-leap simulation engine, the endogenous-statistics catalogue, and
the martingale-residual goodness-of-fit family. Relative to 0.9.0 the package was renamed to **amorem** and the exported feature
functions dropped their `compute_` prefix --- `compute_endogenous_features()` and
`compute_hyperedge_features()` became `endogenous_features()` and
`hyperedge_features()`; the rest of the API is unchanged.

## New features

* **torch training engine for `rem(method = "nn")`.** `nn_control(engine =
  "torch")` trains the same model and conditional-logistic loss as the built-in
  pure-R engine using **torch** (libtorch autograd + Adam), markedly faster
  and, with `batch_strata`, scaling to large event logs (optionally on GPU).
  The fitted object is interchangeable with the R engine. `torch` is a
  *Suggests* dependency; the torch engine requires equal-sized strata.
* **`nn_uncertainty()`** quantifies uncertainty for a neural fit by a stratum
  bootstrap, returning partial-dependence uncertainty bands and a concordance
  confidence interval (with `print()` and `plot()` methods) — the inferential
  counterpart the point-prediction `nn` backend otherwise lacks.

# amorem 0.9.0

New neural backend and a small number of API refinements; the version
intended for the first CRAN release.

* **STREAM-style additive splines:** `nn_control(architecture =
  "additive_spline", batch_strata = )` fits per-covariate B-spline effects by
  (mini-batch) stochastic gradient on the exact case-control partial
  likelihood — the construction of Filippi-Mazzola & Wit (2024, JRSS-C,
  [doi:10.1093/jrsssc/qlae023](https://doi.org/10.1093/jrsssc/qlae023)) — giving interpretable additive smooth
  curves on the same objective as `clogit`, with mini-batching for large
  event logs.
* **New `rem(method = "nn")` backend:** a multilayer perceptron scores every
  candidate in a case-control stratum and is trained on the
  conditional-logistic partial likelihood (softmax over each risk set) — a
  nonlinear, prediction-oriented counterpart of `clogit`. Pure-R implementation
  (no extra dependencies), configured via `nn_control()`; `summary()` reports
  in-sample (and, with a validation split, held-out) concordance and
  `plot(type = "pdp")` shows per-feature partial-dependence curves.
* **API:** the degenerate-logistic backend is now `method = "gam"` (was
  `"degenerate"`); the smooth-term wrappers are `tv()` / `nl()` / `tvnl()`
  (was `tve()` / `nle()` / `tvnle()`); `re()` is unchanged.
* `rem()`'s `case` argument now defaults to `NULL` and is taken from the
  formula's left-hand side (e.g. `event ~ x`) for the `clogit`/`nn` backends.
* `widen_case_control()` auto-detects the 0/1 indicator column (`event` or
  `IS_OBSERVED`) when `case` is not given.
* `widen_case_control()` now carries the sender/receiver identifiers of the
  case and its matched control into the output (`sender_ev`/`receiver_ev`/
  `sender_nv`/`receiver_nv`); the new `keep_ids` argument controls this
  (default `TRUE`). The dyads behind each pair are no longer lost, and `re()`
  grouping terms can reach the actor levels (#92).
* `rem(method = "gam")` now detects long-format case-control input (a
  `event`/`IS_OBSERVED` indicator with control rows) and widens it with
  `widen_case_control()` before fitting, emitting a message — instead of
  silently misreading raw per-row values as event-minus-control differences
  (#93).
* `compute_endogenous_features()` gains a `prior_log` argument for
  warm-starting the network state from events that precede the study window:
  its rows update the running state but never appear in the output, separating
  warm-starting from the non-event masking role of `history_log` (#94).
* `cpp_supported_stats()` is now exported.

# amorem 0.1.0

First release.

* `rem()` unified fitter for preprocessed case-control data, with a
  `gam` (case-1-control logistic via `mgcv::gam()`) and a `clogit` backend.
* Smooth-term formula wrappers for the `gam` backend (time-varying, non-linear,
  time-varying-non-linear) and an `re()` grouping random effect; `re()`
  reproduces the Intro-to-REM tutorial parameterization, and `rem()` exposes a
  `gam_method` argument.
* Simulation via `simulate_relational_events()` (Gillespie and tau-leap),
  the endogenous-statistic feature engine, non-event sampling, and the
  martingale-residual goodness-of-fit family.
