# UCDP dyadic conflict data, 1946–2025

One row per year in which a pair of actors (governments, rebel groups)
was in armed conflict with at least 25 battle-related deaths, from the
UCDP Dyadic Dataset version 26.1.

## Usage

``` r
ucdp_dyads
```

## Format

A data frame with 3,518 rows: `year`, `sender` (side A), `receiver`
(side B), `dyad_id`, `conflict_id`, `location`, `intensity_level` (1 =
25 to 999 deaths, 2 = 1,000 or more), `type_of_conflict` (1
extrasystemic, 2 interstate, 3 intrastate, 4 internationalised
intrastate).

## Source

Uppsala Conflict Data Program, <https://ucdp.uu.se/downloads/>, licence
CC BY 4.0. Cite: Harbom L, Melander E, Wallensteen P (2008). Dyadic
dimensions of armed conflict, 1946–2007. *Journal of Peace Research*
45(5), 697–710,
[doi:10.1177/0022343308094331](https://doi.org/10.1177/0022343308094331)
; and Davies S, Pettersson T, Öberg M (2025). Organized violence
1989–2024. *Journal of Peace Research*.
