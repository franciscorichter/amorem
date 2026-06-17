# Simulate undirected hyperedge events (multi-actor meetings)

Generates a sequence of *undirected* hyperevents — meetings of varying
size drawn from the actor set `actors` — under a linear hyperedge model.
Mirrors the simulation setup of Boschi, Lerner & Wit (2025) Section 4:
each event is a subset of `actors` with size in `1..max_size`, fired
with rate \$\$ \lambda(t, I) \\=\\ \mathrm{baseline\\rate} \\\cdot\\
\exp\\\left(\sum_k \beta_k \\ x_k(t, I)\right), \$\$ where each \\x_k(t,
I)\\ is one of the hyperedge-native covariates supported by
[`compute_hyperedge_features()`](https://franciscorichter.github.io/amorem/reference/compute_hyperedge_features.md)
(`activity`, `subrep_<rho>` for undirected events) or `size` (the
event's cardinality \\\|I\|\\).

## Usage

``` r
simulate_hyperedge_events(
  n_events,
  actors,
  max_size,
  baseline_rate,
  endogenous_stats = character(0),
  endogenous_effects = numeric(0),
  start_time = 0,
  min_size = 1L
)
```

## Arguments

- n_events:

  Number of events to simulate.

- actors:

  Character vector of actor names.

- max_size:

  Maximum allowed meeting size (\\w\\ in the paper). Must be in
  `1..length(actors)`.

- baseline_rate:

  Multiplicative baseline (\\\lambda_0\\).

- endogenous_stats:

  Character vector of stat names accepted by
  [`compute_hyperedge_features()`](https://franciscorichter.github.io/amorem/reference/compute_hyperedge_features.md)
  (undirected variants — `activity`, `subrep_1`, `subrep_2`, ...) or the
  literal `"size"` (the event's cardinality).

- endogenous_effects:

  Numeric vector of coefficients, same length and order as
  `endogenous_stats`.

- start_time:

  Simulation start time.

- min_size:

  Minimum allowed meeting size. Defaults to 1.

## Value

A hyperedge log (see
[`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md))
with `n_events` rows.

## Details

At each step the simulator enumerates **every subset** of `actors` with
size in `1..max_size`. The per-event work is therefore
\\O\\\left(\sum\_{s=1}^{w} \binom{\|V\|}{s}\right)\\; practical for
small actor counts (e.g. \\\|V\| \le 20\\, `max_size <= 4`).

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
Time-Homogeneity: Relational Hyper Event Models with Time-Varying
Non-Linear Effects*. arXiv:2509.05289.

## Examples

``` r
if (FALSE) { # \dontrun{
# Five-actor meetings of size up to 3, with weak attractor on
# repeated triads and a size penalty:
hl <- simulate_hyperedge_events(
  n_events = 50,
  actors   = LETTERS[1:5],
  max_size = 3,
  baseline_rate = 0.2,
  endogenous_stats   = c("subrep_2", "size"),
  endogenous_effects = c(subrep_2 = 0.5, size = -0.3))
} # }
```
