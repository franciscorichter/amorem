## Submission

This is version 1.2.0 of **amorem** (CRAN has 1.1.0, published 2026-10-17).
We submit it soon after 1.1.0 because it fixes bugs that give wrong results or
break CRAN policy in 1.1.0:

* `sample_non_events(scope = "citation")` pooled the citing paper and the cited
  papers under the `mode = "one"` default introduced in 1.1.0, so most sampled
  controls had a sender other than the citing paper.
* `rem(method = "nn")` and `nn_uncertainty()` changed the caller's
  random-number state when given a seed; they no longer do (CRAN policy).
* `gof_rem()` stopped with an error on fits whose data had missing covariate
  values; `rem(method = "gam")` now records the rows it used and warns.
* Two references in the documentation had a wrong DOI or year.

The release also adds `gof_rem()` (goodness of fit for smooth fits) and new
datasets, each from a source whose licence allows redistribution (CC0, CC BY
4.0, MIT, or US public domain); the source, licence and citation are in each
help page. NEWS.md lists every change.

## Test environments

* local: macOS 15 (aarch64), R 4.4.0 — `R CMD check --as-cran`
* GitHub Actions: ubuntu-latest, R release

## R CMD check results

0 errors | 0 warnings | 3 notes:

* "Days since last update: 1" — see above.
* "installed package size ... 5.4Mb" (`data` 2.5Mb, `extdata` 1.7Mb): the new
  datasets, all compressed with xz.
* "checking for future file timestamps ... unable to verify current time": the
  local machine cannot reach the time server.

## Reverse dependencies

None.
