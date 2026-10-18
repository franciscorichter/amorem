# Alien mammals: risk table with covariates (Juozaitienė et al. 2023)

The first records of 112 alien mammal species in the regions of the
FirstRecords database, 1880–2005, as a risk table: one row per species,
region and time interval during which the pair was at risk, with the
covariates of Juozaitienė et al. (2023). A pair leaves the table after
its first record (`event = 1`).

## Usage

``` r
alien_mammals
```

## Format

A data frame with 24,584 rows and 13 columns:

- species, region:

  The pair.

- start, stop:

  Years delimiting the interval; a first record is dated at `stop`.

- event:

  1 when the interval ends with the first record, 0 otherwise.

- dist:

  Distance (km) from the region to the nearest region the species has
  already invaded by `stop`.

- num_inv:

  Weighted number of earlier invasions in the region.

- trade:

  Sum of annual trade flows (current US dollars) between the region and
  the regions the species has invaded; `NA` when not recorded.

- col:

  1 if the species is present in a region of the same colonial area.

- temp_dist:

  Smallest absolute temperature difference (degrees C) between the
  region and the regions already invaded.

- pasture, urban, cropland:

  Shares of land use in the region.

## Source

Juozaitienė R, Seebens H, Latombe G, Essl F, Wit EC (2023). Analysing
ecological dynamics with relational event models: the case of biological
invasions. *Diversity and Distributions* 29(10), 1208–1225,
[doi:10.1111/ddi.13752](https://doi.org/10.1111/ddi.13752) . Data: Dryad
[doi:10.5061/dryad.x69p8czpv](https://doi.org/10.5061/dryad.x69p8czpv)
(CC0 1.0).

## Details

Two attributes describe the risk set. `attr(x, "never_at_risk")` is a
data frame (`sender`, `receiver`) of the species–region pairs that never
appear in the table (native range, or established before 1880), to pass
to `sample_non_events(exclude_pairs = )`. `attr(x, "entry")` gives, for
each species, the year from which it is at risk.

## See also

[alien_invasions](https://franciscorichter.github.io/amorem/reference/alien_invasions.md)
for the first records of all taxa.
