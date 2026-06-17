# Subset repetition statistic for a hyperedge event log

For a focal hyperedge \\(t, I, J)\\ and orders \\(\rho, \ell)\\,
computes the **average activity** over every sender subset of `I` of
size `rho` and every receiver subset of `J` of size `l`, per Boschi,
Lerner & Wit (2025) Equation 4: \$\$ \mathrm{subrep}^{\rho,\ell}(t,I,J)
= \frac{1}{\binom{\|I\|}{\rho}\binom{\|J\|}{\ell}} \sum\_{I' \subseteq
I,\\ \|I'\|=\rho} \sum\_{J' \subseteq J,\\ \|J'\|=\ell}
\mathrm{activity}(t, I', J'). \$\$

## Usage

``` r
hyperedge_subrep(
  hyperedge_log,
  I,
  J = character(0),
  t,
  rho = length(I),
  l = length(J)
)
```

## Arguments

- hyperedge_log:

  A hyperedge log (see
  [`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)).

- I:

  Character vector of senders for the focal event.

- J:

  Character vector of receivers (or `character(0)` for undirected).

- t:

  Focal time.

- rho:

  Order on the sender side: subset cardinality. Must be between 1 and
  `length(I)`. Defaults to `length(I)` (full subset).

- l:

  Order on the receiver side: subset cardinality. Must be between 0 and
  `length(J)`. Defaults to `length(J)` (full subset); pass 0 to ignore
  receivers (undirected).

## Value

A single non-negative numeric.

## Details

For dyadic events with \\\|I\| = \|J\| = 1\\, `subrep(rho = 1, l = 1)`
reduces to the dyad event count (already exposed as `reciprocity_count`
and related stats in
[`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md)).
The function exists because for true hyperedge data the average over
subsets of intermediate size captures partial-subset repetition that no
dyadic statistic can represent.

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and Time-
Homogeneity: Relational Hyper Event Models with Time-Varying Non-Linear
Effects*. arXiv:2509.05289. Lerner J, et al. (2025). The eventnet
computation framework.

## Examples

``` r
hl <- hyperedge_log(
  I    = list(c("a","b"), c("a","c"), c("b","c")),
  J    = list(c("X"),     c("X","Y"), c("Y")),
  time = c(1, 2, 3))
# Activity for the (a, X) sub-pair before t = 4:
hyperedge_activity(hl, I = "a", J = "X", t = 4)
#> [1] 2
# First-order subrep on event (a, b) -> X at t = 4:
hyperedge_subrep(hl, I = c("a","b"), J = "X", t = 4, rho = 1, l = 1)
#> [1] 1.5
```
