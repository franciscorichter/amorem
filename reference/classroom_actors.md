# Classroom actor attributes (McFarland 2001)

Per-actor covariates for the
[classroom_events](https://franciscorichter.github.io/amorem/reference/classroom_events.md)
event stream.

## Usage

``` r
classroom_actors
```

## Format

A data frame with 20 rows and 3 columns:

- id:

  Character actor id matching the `sender`/`receiver` columns of
  [classroom_events](https://franciscorichter.github.io/amorem/reference/classroom_events.md).

- sex:

  Factor `"F"` / `"M"` — biological sex.

- role:

  Factor with levels `"instructor"`, `"grade_11"`, `"grade_12"`.

## Source

McFarland (2001), via `networkDynamic`. See
[classroom_events](https://franciscorichter.github.io/amorem/reference/classroom_events.md).
