# Changelog

## amore 0.1.0

First public release.

- [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
  unified fitter for preprocessed case-control data, with a `gam`
  (case-1-control logistic via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html)), a `clogit`,
  and a neural-network (`nn`) backend.
- `rem(method = "nn")`: a multilayer perceptron scores every candidate
  in a case-control stratum and is trained on the conditional-logistic
  partial likelihood (softmax over each risk set) — a nonlinear,
  prediction-oriented counterpart of `clogit`. Pure-R implementation (no
  extra dependencies), configured via
  [`nn_control()`](https://franciscorichter.github.io/amore/reference/nn_control.md);
  [`summary()`](https://rdrr.io/r/base/summary.html) reports held-out
  concordance and `plot(type = "pdp")` shows per-feature
  partial-dependence curves.
- Smooth-term formula wrappers for the `gam` backend: `tv()`
  (time-varying linear), `nl()` (non-linear), `tvnl()` (time-varying
  non-linear), and `re()` (grouping random effect).
- `re()` reproduces the Intro-to-REM tutorial parameterization;
  [`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
  gains a `gam_method` argument (default uses mgcv’s own smoothness
  selection, with `gam_method = "REML"` available).
- Simulation via
  [`simulate_relational_events()`](https://franciscorichter.github.io/amore/reference/simulate_relational_events.md)
  (Gillespie and tau-leap), endogenous-feature computation, non-event
  sampling, and goodness-of-fit helpers.
