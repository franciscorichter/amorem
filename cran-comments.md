## Submission

This is a minor release of **amorem**, version 1.1.0 (CRAN has 1.0.0). It fixes
user-facing correctness bugs, changes one default, and adds features.

Bug fixes that change results:

* `endogenous_features()` on case-control data counted the sampled controls as
  past events, so every statistic also counted hypothetical dyads. This was the
  default path inside `compare_models()`, `compare_models_smooth()`, `gof()` and
  `martingale_residuals()`. On simulated data with a reciprocity effect of 0.3
  the estimate was 0.20 before and 0.31 after. Only the observed events now build
  the history.
* `compare_models()` fitted the matched-set identifier as a factor covariate on
  **survival** < 3.7-3, which shifted the reported log-likelihood and AIC; the
  Cox formulas now use bare specials and Imports require `survival (>= 3.7-3)`.
* `compare_models_global()` now implements the time-shifted design of Lembo et
  al. (2025) as published.
* `widen_case_control()` paired cases with the wrong controls once rows were
  re-sorted by time; it now uses the `stratum` column when present.

Change in behaviour: `sample_non_events()` defaults to `mode = "one"`, the
default of every other function in the package.

New features: time-shifted case-control sampling for global covariates, per-term
basis arguments in `rem()` formulas, and a new dataset, `enso_nino34` (NOAA
paleoclimatology data, publicly available without restriction; the source and
citation are in its help page). NEWS.md lists every change.

## Test environments

* local: macOS 15 (aarch64), R 4.4.0 — `R CMD check --as-cran`
* win-builder: R-devel
* GitHub Actions: ubuntu-latest, R release

## R CMD check results

0 errors | 0 warnings | 2 notes, both from the local environment only:

* "checking installed package size ... installed size is 5.3Mb" on macOS
  (`extdata` 1.7Mb, `help` 1.8Mb). Version 1.0.0 shows no such NOTE on any CRAN
  check flavour.
* "checking for future file timestamps ... unable to verify current time": the
  local machine cannot reach the time server.

## Reverse dependencies

None.
