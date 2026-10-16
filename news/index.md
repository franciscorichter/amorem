# Changelog

## amorem (development version)

### Bug fixes

- **[`compare_models_global()`](https://franciscorichter.github.io/amorem/reference/compare_models_global.md)
  now uses the paper’s time-shifted design.** It drew one shift per
  control row, never shifted the event, never checked the observation
  window (control times could precede the data), evaluated the controls’
  dyadic statistics at the event time, and let sampled controls enter
  the network history. On simulated data with a global effect of 1 it
  returned estimates of -1.74, 2.63 and -2.12 over three datasets. It
  now draws its sample with `sample_non_events(shift = "exponential")`,
  computes dyadic statistics against the real history at each row’s own
  time, evaluates `tv` / `tvnl` terms at each row’s own time, and drops
  events with no control; the same three datasets give 0.85, 1.02 and
  1.01. The shift mean is now `shift_scale` times the average event time
  (it was times the average inter-arrival time), and a `window` argument
  is passed through. Results of earlier
  [`compare_models_global()`](https://franciscorichter.github.io/amorem/reference/compare_models_global.md)
  fits change and should be re-run.

- [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
  and the `clogit` / `nn` backends of
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  use the `stratum` column written by
  [`sample_non_events()`](https://franciscorichter.github.io/amorem/reference/sample_non_events.md)
  when `stratum = NULL`, instead of rebuilding strata as
  `cumsum(case == 1)`. The rebuilt strata assumed each case was followed
  by its controls, which stops holding once
  [`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md)
  re-sorts rows by time with ties, or with shifted controls, and then
  paired cases with the wrong controls. Data without a `stratum` column
  (eventnet output) is handled as before.

- **[`sample_non_events()`](https://franciscorichter.github.io/amorem/reference/sample_non_events.md)
  risk-set edge cases
  ([\#102](https://github.com/franciscorichter/amorem/issues/102)).**

  - `exclude_pairs` and, under `risk = "remove"`, same-time events are
    now part of the check for whether any valid control exists, so a
    stratum whose every alternative is excluded gets no controls instead
    of stopping with “Unable to sample a valid non-event after
    `max_attempts` attempts”.
  - `scope = "appearance"` no longer falls back to all actors when no
    actor has appeared yet: the first event gets no controls, and
    controls are only ever drawn from actors seen in prior events, as
    documented. Results change for the first stratum(s) of
    `scope = "appearance"` fits.
  - Factor `sender` / `receiver` columns are coerced to character, so
    the output columns are character whatever the input type.
  - The documentation of `mode` states which risk set each mode gives:
    `"two"` never draws a receiver-only actor as a control sender (or
    vice versa), so networks with one node set should use
    `mode = "one"`.
  - The unreachable empty-pool fallbacks in the pair sampler were
    removed.

### New features

- **Time-shifted case-control sampling for global covariates
  ([\#101](https://github.com/franciscorichter/amorem/issues/101)).**
  `sample_non_events(shift = "exponential")` implements Section 4 of
  Lembo, Juozaitienė, Vinciotti & Wit (2025, JRSS-C): one exponential
  shift per dyad, each control drawn uniformly from the dyads whose
  back-shifted time lies in the observation `window` and stored at that
  time, so covariates that depend only on time no longer cancel within
  strata. `shift_scale` sets the mean shift as a multiple of the average
  event time, as in the paper. Risk-set rules (`exclude_pairs`,
  `risk = "remove"`, `scope = "appearance"`) are evaluated at the
  control’s own time; events with no other dyad in their shifted risk
  set get no control and are listed in `attr(, "shift")$uninformative`.
  The attribute also holds the shift mean, the window and the per-dyad
  shifts.

- `endogenous_features(history_log = )` and `prior_log` now work for
  every statistic, including `reciprocity_exp_decay`,
  `reciprocity_time_recent` and `reciprocity_time_first`, which the
  compiled engine does not cover.

- **Per-term basis settings in
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  formulas
  ([\#91](https://github.com/franciscorichter/amorem/issues/91)).**
  Smooth terms take the basis arguments of
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html) /
  [`mgcv::te()`](https://rdrr.io/pkg/mgcv/man/te.html) after the
  covariate, so terms in one model can use different basis dimensions
  and types: `tv(x, k = 20, bs = "cr") + nl(y, k = 5, bs = "ps")`.
  `tvnl()` takes one value per margin (`tvnl(x, k = c(5, 8))`). A new
  global `bs` argument joins the global `k` as the default for terms
  that set neither; existing formulas give the same model as before.

- `sample_non_events(exclude_concurrent = )` controls whether dyads with
  an event at the focal event’s own time can be controls. The default
  keeps the existing behaviour: excluded under `risk = "remove"`, at
  risk under `risk = "standard"` (the Breslow convention).

## amorem 1.0.1

### Bug fixes

- **[`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md)
  did not stratify on the matched sets under** survival **before
  3.7-3.** The Cox formula was built with a namespace-qualified
  `survival::strata(stratum)`, and `terms(specials = )` does not match a
  qualified call, so the matched-set identifier was silently fitted as
  an ordinary factor covariate in an unstratified model. Coefficients
  and the `delta_AIC` column were unaffected; the absolute `log_lik` was
  shifted by `-n_events * log(n_strata)` and the degrees of freedom
  inflated by `n_strata - 1`, so reported `AIC` values were wrong. The
  same applied to the
  [`frailty()`](https://rdrr.io/pkg/survival/man/frailty.html) terms on
  the random-effects path, which is why the `coxme` two-axis fit did not
  complete. All four call sites now use bare specials, which every
  **survival** version matches, and regression tests assert that
  `AIC == -2 * log_lik + 2 * df` and that no stratum dummies enter as
  covariates. Anyone who published absolute log-likelihood or AIC values
  from `compare_models(n_controls > 1)` should re-run them.

## amorem 1.0.0

CRAN release: 2026-06-29

First CRAN release, under the name **amorem**. The package was renamed
from the working name `amore`, which collided (case-insensitively) with
the archived CRAN package `AMORE`. This release consolidates the 0.9.0
development line into the first stable, installable version: the unified
[`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
front-end (the `clogit`, `gam`, and `nn` backends, including the
additive-spline architecture), the Gillespie / tau-leap simulation
engine, the endogenous-statistics catalogue, and the martingale-residual
goodness-of-fit family. Relative to 0.9.0 the package was renamed to
**amorem** and the exported feature functions dropped their `compute_`
prefix — `compute_endogenous_features()` and
`compute_hyperedge_features()` became
[`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md)
and
[`hyperedge_features()`](https://franciscorichter.github.io/amorem/reference/hyperedge_features.md);
the rest of the API is unchanged.

### New features

- **torch training engine for `rem(method = "nn")`.**
  `nn_control(engine = "torch")` trains the same model and
  conditional-logistic loss as the built-in pure-R engine using
  **torch** (libtorch autograd + Adam), markedly faster and, with
  `batch_strata`, scaling to large event logs (optionally on GPU). The
  fitted object is interchangeable with the R engine. `torch` is a
  *Suggests* dependency; the torch engine requires equal-sized strata.
- **[`nn_uncertainty()`](https://franciscorichter.github.io/amorem/reference/nn_uncertainty.md)**
  quantifies uncertainty for a neural fit by a stratum bootstrap,
  returning partial-dependence uncertainty bands and a concordance
  confidence interval (with
  [`print()`](https://rdrr.io/r/base/print.html) and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods) —
  the inferential counterpart the point-prediction `nn` backend
  otherwise lacks.

## amorem 0.9.0

New neural backend and a small number of API refinements; the version
intended for the first CRAN release.

- **STREAM-style additive splines:**
  `nn_control(architecture = "additive_spline", batch_strata = )` fits
  per-covariate B-spline effects by (mini-batch) stochastic gradient on
  the exact case-control partial likelihood — the construction of
  Filippi-Mazzola & Wit (2024, JRSS-C, <doi:10.1093/jrsssc/qlae023>) —
  giving interpretable additive smooth curves on the same objective as
  `clogit`, with mini-batching for large event logs.
- **New `rem(method = "nn")` backend:** a multilayer perceptron scores
  every candidate in a case-control stratum and is trained on the
  conditional-logistic partial likelihood (softmax over each risk set) —
  a nonlinear, prediction-oriented counterpart of `clogit`. Pure-R
  implementation (no extra dependencies), configured via
  [`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md);
  [`summary()`](https://rdrr.io/r/base/summary.html) reports in-sample
  (and, with a validation split, held-out) concordance and
  `plot(type = "pdp")` shows per-feature partial-dependence curves.
- **API:** the degenerate-logistic backend is now `method = "gam"` (was
  `"degenerate"`); the smooth-term wrappers are `tv()` / `nl()` /
  `tvnl()` (was `tve()` / `nle()` / `tvnle()`); `re()` is unchanged.
- [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)’s
  `case` argument now defaults to `NULL` and is taken from the formula’s
  left-hand side (e.g. `event ~ x`) for the `clogit`/`nn` backends.
- [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
  auto-detects the 0/1 indicator column (`event` or `IS_OBSERVED`) when
  `case` is not given.
- [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
  now carries the sender/receiver identifiers of the case and its
  matched control into the output (`sender_ev`/`receiver_ev`/
  `sender_nv`/`receiver_nv`); the new `keep_ids` argument controls this
  (default `TRUE`). The dyads behind each pair are no longer lost, and
  `re()` grouping terms can reach the actor levels
  ([\#92](https://github.com/franciscorichter/amorem/issues/92)).
- `rem(method = "gam")` now detects long-format case-control input (a
  `event`/`IS_OBSERVED` indicator with control rows) and widens it with
  [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
  before fitting, emitting a message — instead of silently misreading
  raw per-row values as event-minus-control differences
  ([\#93](https://github.com/franciscorichter/amorem/issues/93)).
- `compute_endogenous_features()` gains a `prior_log` argument for
  warm-starting the network state from events that precede the study
  window: its rows update the running state but never appear in the
  output, separating warm-starting from the non-event masking role of
  `history_log`
  ([\#94](https://github.com/franciscorichter/amorem/issues/94)).
- [`cpp_supported_stats()`](https://franciscorichter.github.io/amorem/reference/cpp_supported_stats.md)
  is now exported.

## amorem 0.1.0

First release.

- [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  unified fitter for preprocessed case-control data, with a `gam`
  (case-1-control logistic via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html)) and a `clogit`
  backend.
- Smooth-term formula wrappers for the `gam` backend (time-varying,
  non-linear, time-varying-non-linear) and an `re()` grouping random
  effect; `re()` reproduces the Intro-to-REM tutorial parameterization,
  and
  [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  exposes a `gam_method` argument.
- Simulation via
  [`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
  (Gillespie and tau-leap), the endogenous-statistic feature engine,
  non-event sampling, and the martingale-residual goodness-of-fit
  family.
