# Alien species first records, prepared for relational event models

First records of established alien species (mammals, birds, plants,
insects) in 259 regions, 1880–2005, as one-shot species-to-region
events: each pair fires at most once (`risk = "remove"`). The first
record is dated `stop`; `start` is the start of the last interval over
which the pair was at risk with unchanged covariates in the
counting-process release.

## Usage

``` r
alien_invasions
```

## Format

A data frame with 11,730 rows, ordered by `stop`: `species`, `region`,
`start`, `stop` (years), `taxonomy`. `start` equals `stop` in 421 rows:
the 14 records of 1880 and 407 later records whose last at-risk interval
in the release begins in the year of the record.

## Source

Juozaitienė R, Seebens H, Latombe G, Essl F, Wit EC (2023). Analysing
ecological dynamics with relational event models: the case of biological
invasions. *Diversity and Distributions* 29, 1208–1225,
[doi:10.1111/ddi.13752](https://doi.org/10.1111/ddi.13752) . Data: Dryad
[doi:10.5061/dryad.x69p8czpv](https://doi.org/10.5061/dryad.x69p8czpv)
(CC0 1.0).

## Details

The release also holds every censored species-region-interval with
distance, trade, colonial, climate and land-use covariates (535,020
rows); download it from the source to fit the full model.
