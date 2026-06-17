# Endogenous features for a hyperedge event log

Hyperedge analogue of
[`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md).
Accepts a hyperedge log (see
[`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md))
and computes hyperedge-native statistics, falling back to the dyadic
engine for stat names that belong to the standard dyadic endogenous
catalogue.

## Usage

``` r
compute_hyperedge_features(hyperedge_log, stats, half_life = NULL)
```

## Arguments

- hyperedge_log:

  A hyperedge log (see
  [`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)).

- stats:

  Character vector of statistic names. Mix of hyperedge- native names
  listed above and the dyadic catalogue names accepted by
  [`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md).

- half_life:

  Required when an exp-decay statistic is requested (only applies to
  delegated dyadic stats; hyperedge subrep does not use a half-life).

## Value

The hyperedge log with one added column per requested stat.

## Details

Recognised hyperedge stat names:

- `"subrep_<rho>_<l>"`:

  Directed subset repetition (paper eq. 4). `rho` = sender-side subset
  cardinality (1..\|I\|), `l` = receiver-side subset cardinality
  (0..\|J\|, 0 = ignore receivers). Examples: `"subrep_1_1"` (average
  activity over single-actor sub-pairs), `"subrep_2_1"` (over
  pair-of-senders × single-receiver subpairs).

- `"subrep_<rho>"`:

  Undirected subset repetition. Equivalent to `"subrep_<rho>_0"`; counts
  past events whose participant set is a superset of the chosen subset,
  with no receiver-side restriction.

- `"activity"`:

  Counts past events whose participant set covers the focal event's
  entire `(I, J)` pair. Equivalent to `"subrep_<|I|>_<|J|>"`.

For dyadic-shaped events (every row has `|I| = |J| = 1`) and a dyadic
stat name, this function delegates to
[`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md)
via
[`as_dyadic_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md).

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
Time-Homogeneity: Relational Hyper Event Models with Time-Varying
Non-Linear Effects*. arXiv:2509.05289.

## See also

[`hyperedge_subrep()`](https://franciscorichter.github.io/amorem/reference/hyperedge_subrep.md),
[`hyperedge_activity()`](https://franciscorichter.github.io/amorem/reference/hyperedge_activity.md),
[`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md).

## Examples

``` r
hl <- hyperedge_log(
  I    = list(c("a","b"), c("a","c"), c("b","c"), c("a","b","c")),
  J    = list(c("X"),     c("X","Y"), c("Y"),     c("X")),
  time = c(1, 2, 3, 4))
compute_hyperedge_features(hl,
  stats = c("subrep_1_1", "subrep_2_1", "activity"))
#>         I    J time subrep_1_1 subrep_2_1 activity
#> 1    a, b    X    1   0.000000  0.0000000        0
#> 2    a, c X, Y    2   0.250000  0.0000000        0
#> 3    b, c    Y    3   0.500000  0.0000000        0
#> 4 a, b, c    X    4   1.333333  0.6666667        0
```
