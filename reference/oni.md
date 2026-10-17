# Oceanic Niño Index, 1950–present

Three-month running mean of the Niño 3.4 sea-surface temperature
anomaly, the NOAA measure of El Niño and La Niña. The instrumental
counterpart of the reconstruction in
[enso_nino34](https://franciscorichter.github.io/amorem/reference/enso_nino34.md).

## Usage

``` r
oni
```

## Format

A data frame with 920 rows: `year`, `season` (three-month window, e.g.
`"DJF"`), `sst` (degrees Celsius), `anomaly` (degrees Celsius).

## Source

NOAA Climate Prediction Center,
<https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt>, accessed
2026-10-17. A work of the US Government, public domain.
