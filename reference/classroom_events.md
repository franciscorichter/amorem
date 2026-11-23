# Classroom interaction events (McFarland 2001)

Time-stamped directed interactions among 20 individuals in a single US
high-school class session, recorded on 16 October 1996 by Daniel
McFarland. The same data appear in the `networkDynamic` R package as
`McFarland_cls33_10_16_96`; this is a tidy event-table form.

## Usage

``` r
classroom_events
```

## Format

A data frame with 691 rows and 5 columns:

- time:

  Minutes since the start of the class period.

- sender:

  Character actor id matching
  [classroom_actors](https://franciscorichter.github.io/amorem/reference/classroom_actors.md)`$id`.

- receiver:

  Character actor id matching
  [classroom_actors](https://franciscorichter.github.io/amorem/reference/classroom_actors.md)`$id`.

- interaction_type:

  Factor with levels `"social"`, `"sanction"`, `"task"`.

- weight:

  Numeric weight assigned by the observer: 1 for direct communication
  focused on particular others (501 rows), 0.2 for indirect "broadcast"
  communication such as lecturing (190 rows).

## Source

McFarland, D. (2001). Student resistance: How the formal and informal
organization of classrooms facilitate everyday forms of student
defiance. *American Journal of Sociology* 107(3), 612–678.
[doi:10.1086/338779](https://doi.org/10.1086/338779) . Redistributed via
the `networkDynamic` R package (CRAN), dataset
`McFarland_cls33_10_16_96`,
<https://cran.r-project.org/package=networkDynamic>. Licence: no licence
is stated for the data themselves; the `networkDynamic` package, which
distributes them, is licensed GPL-3.

## See also

[classroom_actors](https://franciscorichter.github.io/amorem/reference/classroom_actors.md)
