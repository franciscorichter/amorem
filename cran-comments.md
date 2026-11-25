## Submission

This is version 1.3.0 of **amorem** (CRAN has 1.2.0). Main changes (NEWS.md
lists every change):

* Fits from `rem()` have class `"amorem_rem"` instead of `"rem"`: the packages
  relevent and redeem register S3 methods on class `"rem"`, and loading either
  of them redirected the print, summary and predict methods of amorem fits.
* Statistics at tied times now use only events strictly before that time in
  every code path.
* Seven data objects (the McFarland classroom, Social Evolution, CollegeMsg and
  Email-EU-core logs) are no longer shipped, because their sources state no
  licence for the data. `fetch_dataset()` downloads them from their sources
  when a user asks for them. Its own example (in `\donttest`) calls it inside
  `tryCatch()` with `cache_dir = tempdir()` and prints nothing when the source
  cannot be reached; no other example and no vignette calls it, and tests that
  need it are skipped on CRAN.
* The remaining datasets come from sources whose licence allows
  redistribution (CC0, CC BY 4.0, MIT, or US public domain), or are public
  holiday dates; the source, licence and citation are in each help page.

## Test environments

* local: macOS 15 (aarch64), R 4.4.0 — `R CMD check --as-cran`
* GitHub Actions: ubuntu-latest, R release

## R CMD check results

0 errors | 0 warnings | 2 notes:

* "installed package size ... 5.0Mb" (`data` 2.0Mb, `extdata` 1.7Mb): the
  bundled datasets, all compressed with xz.
* "checking for future file timestamps ... unable to verify current time": the
  local machine cannot reach the time server.

## Reverse dependencies

None.
