# Simulated event log used in the examples

600 directed events among 20 actors (`a01` to `a20`), drawn by
[`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
with the Gillespie algorithm, a baseline rate of 1 per dyad, and effects
1.5 of `reciprocity_binary` and 0.8 of `transitivity_binary`.
`data-raw/simulated_events.R` in the source repository draws it.

## Usage

``` r
simulated_events
```

## Format

A data frame with 600 rows and 3 columns: `time`, `sender`, `receiver`.

## Source

Simulated; part of amorem (MIT licence).

## See also

[`fetch_dataset()`](https://franciscorichter.github.io/amorem/reference/fetch_dataset.md)
for the classroom, Social Evolution, CollegeMsg and Email-Eu-core logs,
which the package downloads instead of shipping.
