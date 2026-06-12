# amore 0.1.0

First public release.

* `rem()` unified fitter for preprocessed case-control data, with a
  `degenerate` (case-1-control logistic via `mgcv::gam()`) and a `clogit`
  backend.
* Smooth-term formula wrappers for the degenerate backend: `tv()`
  (time-varying linear), `nl()` (non-linear), `tvnl()` (time-varying
  non-linear), and `re()` (grouping random effect).
* `re()` reproduces the Intro-to-REM tutorial parameterization; `rem()` gains a
  `gam_method` argument (default uses mgcv's own smoothness selection, with
  `gam_method = "REML"` available).
* Simulation via `simulate_relational_events()` (Gillespie and tau-leap),
  endogenous-feature computation, non-event sampling, and goodness-of-fit
  helpers.
