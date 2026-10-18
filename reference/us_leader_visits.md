# US leader-to-leader visits, 1945–2019

Visits of foreign heads of state or government to the United States, and
travels of US presidents abroad, as directed visitor-to-host events.

## Usage

``` r
us_leader_visits
```

## Format

A data frame with 3,945 rows: `time` (days since the first visit),
`date`, `sender` (visiting country), `receiver` (host country),
`direction` (`"to_us"` or `"from_us"`).

## Source

US Leader-to-Leader Diplomatic Visits Dataset, 1946–2019. Harvard
Dataverse, [doi:10.7910/DVN/2ZNR5R](https://doi.org/10.7910/DVN/2ZNR5R)
, licence CC0 1.0.

## Details

Country names follow the visits table's cleaned names. Where that name
is missing (microstates and a few presidential trips) the raw name is
used, or the country of the listed locales; the two source tables'
spellings are merged ("Korea, Republic of" is South Korea, "Zaire" is
Congo - Kinshasa). A 1998 presidential trip labelled Congo whose locales
are all in Uganda is coded as Uganda. See
`data-raw/bundle_open_datasets.R`.
