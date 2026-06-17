# amorem 1.0.0

First CRAN release, under the name **amorem**. The package was renamed from the
working name `amore`, which collided (case-insensitively) with the archived CRAN
package `AMORE`. This release consolidates the 0.9.0 development line into the
first stable, installable version: the unified `rem()` front-end (the `clogit`,
`gam`, and `nn` backends, including the additive-spline architecture), the
Gillespie / tau-leap simulation engine, the endogenous-statistics catalogue, and
the martingale-residual goodness-of-fit family. No API changes relative to 0.9.0
beyond the package name.

# amorem 0.9.0

New neural backend and a small number of API refinements; the version
intended for the first CRAN release.

* **STREAM-style additive splines:** `nn_control(architecture =
  "additive_spline", batch_strata = )` fits per-covariate B-spline effects by
  (mini-batch) stochastic gradient on the exact case-control partial
  likelihood — the construction of Filippi-Mazzola & Wit (2024, JRSS-C,
  <doi:10.1093/jrsssc/qlae023>) — giving interpretable additive smooth
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
