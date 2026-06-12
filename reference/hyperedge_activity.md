# Activity counter for hyperedge subsets

For a focal candidate hyperedge \\(t, I, J)\\, `activity(t, I, J)`
counts the number of past events \\(t_m, I_m, J_m)\\ with \\t_m \< t\\
satisfying \\I \subseteq I_m\\ AND \\J \subseteq J_m\\.

## Usage

``` r
hyperedge_activity(hyperedge_log, I, J = character(0), t)
```

## Arguments

- hyperedge_log:

  A hyperedge log (see
  [`hyperedge_log()`](https://franciscorichter.github.io/amore/reference/hyperedge_log.md)).

- I:

  Character vector of sender names defining the focal subset.

- J:

  Character vector of receiver names defining the focal subset. Pass
  `character(0)` to ignore the receiver side (undirected events).

- t:

  Focal time. Only events strictly before `t` contribute.

## Value

A single non-negative integer.

## References

Lerner J, Boschi M, Wit EC (2025). Subset repetition.
