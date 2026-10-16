# data-raw/enso_nino34.R
# Build the `enso_nino34` data object from the NOAA paleoclimatology file
# shipped under inst/extdata/enso_nino34/ (source: Li et al. 2013, NOAA study
# 14632, https://doi.org/10.25921/jfqm-9178; file
# https://www.ncei.noaa.gov/pub/data/paleo/treering/reconstructions/enso-li2013.txt,
# accessed 2026-10-16).
#
# Raw format: `#`-prefixed metadata lines, then a tab-delimited table with
# header `age_AD  sst.anom`: one row per year, 1301-2005, holding the
# reconstructed November-January Nino3.4 sea-surface temperature anomaly
# (deg C, relative to the 1971-2000 mean) of the winter ending in that year.

raw <- utils::read.delim("inst/extdata/enso_nino34/enso-li2013.txt",
                         comment.char = "#", fileEncoding = "UTF-8-BOM")
stopifnot(identical(names(raw), c("age_AD", "sst.anom")),
          nrow(raw) == 705L,
          identical(as.integer(raw$age_AD), 1301:2005),
          !anyNA(raw$sst.anom))

enso_nino34 <- data.frame(
  year   = as.integer(raw$age_AD),
  nino34 = as.numeric(raw$sst.anom)
)

usethis::use_data(enso_nino34, overwrite = TRUE, compress = "xz")
