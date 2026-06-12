# Changelog

## amore 0.9.0

New neural backend and a small number of API refinements; the version
intended for the first CRAN release.

- **New `rem(method = "nn")` backend:** a multilayer perceptron scores
  every candidate in a case-control stratum and is trained on the
  conditional-logistic partial likelihood (softmax over each risk set) —
  a nonlinear, prediction-oriented counterpart of `clogit`. Pure-R
  implementation (no extra dependencies), configured via
  [`nn_control()`](https://franciscorichter.github.io/amore/reference/nn_control.md);
  [`summary()`](https://rdrr.io/r/base/summary.html) reports in-sample
  (and, with a validation split, held-out) concordance and
  `plot(type = "pdp")` shows per-feature partial-dependence curves.
- **API:** the degenerate-logistic backend is now `method = "gam"` (was
  `"degenerate"`); the smooth-term wrappers are `tv()` / `nl()` /
  `tvnl()` (was `tve()` / `nle()` / `tvnle()`); `re()` is unchanged.
- [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)’s
  `case` argument now defaults to `NULL` and is taken from the formula’s
  left-hand side (e.g. `event ~ x`) for the `clogit`/`nn` backends.
- [`widen_case_control()`](https://franciscorichter.github.io/amore/reference/widen_case_control.md)
  auto-detects the 0/1 indicator column (`event` or `IS_OBSERVED`) when
  `case` is not given.
- [`cpp_supported_stats()`](https://franciscorichter.github.io/amore/reference/cpp_supported_stats.md)
  is now exported.

## amore 0.1.0

First release.

- [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
  unified fitter for preprocessed case-control data, with a `gam`
  (case-1-control logistic via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html)) and a `clogit`
  backend.
- Smooth-term formula wrappers for the `gam` backend (time-varying,
  non-linear, time-varying-non-linear) and an `re()` grouping random
  effect; `re()` reproduces the Intro-to-REM tutorial parameterization,
  and
  [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
  exposes a `gam_method` argument.
- Simulation via
  [`simulate_relational_events()`](https://franciscorichter.github.io/amore/reference/simulate_relational_events.md)
  (Gillespie and tau-leap), the endogenous-statistic feature engine,
  non-event sampling, and the martingale-residual goodness-of-fit
  family.
