## Submission

This is a new submission of **amore** (Augmented Modelling of Relational
Events), version 0.2.0 — tools for simulating, fitting, and checking
relational event models. (An earlier 0.1.0 was prepared; 0.2.0 adds a
neural-network estimation backend and small API refinements and is the
version intended for release.)

## Test environments

* local: macOS (aarch64), R 4.5.1 — `R CMD check --as-cran`
* win-builder devel and release
* GitHub Actions (ubuntu-latest, R release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

The incoming-feasibility check additionally reports a case-insensitive name
conflict with the package **AMORE**. Please note:

* **AMORE** ("A MORE flexible neural network package") was **archived** on
  CRAN and is no longer an active package. It is an unrelated neural-network
  package; **amore** concerns relational event models for dynamic networks.
* The names differ in case and the active namespaces do not collide. We
  believe the lowercase name **amore** is appropriate, but we are happy to
  rename if the CRAN team prefers a fully distinct name.

## Notes observed only in our local environment (not package defects)

* "checking HTML version of manual" — our local HTML Tidy is outdated.
* "checking for future file timestamps: unable to verify current time" — the
  time server was unreachable from our build host; no files carry future
  timestamps.

## Reverse dependencies

None (new submission).
