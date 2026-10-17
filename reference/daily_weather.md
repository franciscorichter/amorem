# Daily weather at the places and periods of the bundled event logs

Daily maximum and minimum temperature and precipitation from NOAA
GHCN-Daily for Boston Logan (September–December 2008, Social Evolution),
Santa Ana John Wayne airport (April–October 2004, CollegeMsg), and
Warsaw-Okecie and Wroclaw-Strachowice (January–October 2010,
manufacturing email).

## Usage

``` r
daily_weather
```

## Format

A data frame with 944 rows: `station`, `name`, `date`, `tmax` and `tmin`
(degrees Celsius), `prcp` (millimetres). Missing values are `NA`.

## Source

NOAA National Centers for Environmental Information, Global Historical
Climatology Network Daily, <https://www.ncei.noaa.gov/>, accessed
2026-10-17. A work of the US Government, public domain.
