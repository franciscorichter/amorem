## Submission

This is a new submission of **amore** (Augmented Modelling of Relational
Events), version 0.9.0 — tools for simulating, fitting, and checking
relational event models.

## Test environments

* local: macOS (aarch64), R 4.5.1 — `R CMD check --as-cran`
* win-builder devel and release
* GitHub Actions (ubuntu-latest, R release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

The incoming-feasibility check additionally reports a case-insensitive name
conflict with the package **AMORE**. We would like to keep the name **amore**,
for the following reasons:

* **AMORE** ("A MORE flexible neural network package") was **archived** on
  CRAN and is no longer an active package.
* It is unrelated in scope: AMORE concerned feed-forward neural networks,
  whereas **amore** provides relational event models for dynamic network data
  ("Augmented Modelling Of Relational Events").
* The names differ in case, and the package namespaces, exported objects, and
  documentation do not overlap.

## Notes observed only in our local environment (not package defects)

* "checking HTML version of manual" — our local HTML Tidy is outdated.
* "checking for future file timestamps: unable to verify current time" — the
  time server was unreachable from our build host; no files carry future
  timestamps.

## Reverse dependencies

None (new submission).
