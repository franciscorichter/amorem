# Simulate directed two-mode hyperedge events

Generates a sequence of *directed* hyperevents from a sender set \\I_m
\subseteq V^I\\ to a receiver set \\J_m \subseteq V^J\\, with both
\\I_m\\ and \\J_m\\ non-empty. This is the directed two-mode counterpart
to
[`simulate_hyperedge_events()`](https://franciscorichter.github.io/amorem/reference/simulate_hyperedge_events.md)
and matches the data model used in Boschi, Lerner & Wit (2025) Section 5
for citation networks (authors citing papers).

## Usage

``` r
simulate_directed_hyperedge_events(
  n_events,
  senders,
  receivers,
  min_size_I = 1L,
  max_size_I = 1L,
  min_size_J = 1L,
  max_size_J = 1L,
  baseline_rate = 1,
  endogenous_stats = character(0),
  endogenous_effects = numeric(0),
  start_time = 0
)
```

## Arguments

- n_events:

  Number of events to simulate.

- senders:

  Character vector of sender names \\V^I\\.

- receivers:

  Character vector of receiver names \\V^J\\. Must be non-empty.

- min_size_I, max_size_I:

  Sender-side cardinality bounds.

- min_size_J, max_size_J:

  Receiver-side cardinality bounds.

- baseline_rate:

  Multiplicative baseline (\\\lambda_0\\).

- endogenous_stats:

  Character vector of supported stat names: `"size_I"` (sender-side size
  penalty), `"size_J"` (receiver-side), `"activity"` (number of past
  events covering the full focal `(I, J)`), `"subrep_<rho>_<l>"`
  (directed subset repetition, paper eq. 4).

- endogenous_effects:

  Numeric vector of coefficients, same length and order as
  `endogenous_stats`.

- start_time:

  Simulation start time.

## Value

A directed hyperedge log (`amorem_hyperedge_log` data frame with `I`,
`J`, `time` columns; `J` non-empty on every row).

## Details

At each step the simulator enumerates every candidate hyperedge \\(I,
J)\\ with \\\|I\| \in \[\mathrm{min\\size\\I}, \mathrm{max\\size\\I}\]\\
and \\\|J\| \in \[\mathrm{min\\size\\J}, \mathrm{max\\size\\J}\]\\,
computes the rate \$\$ \lambda(t, I, J) \\=\\ \mathrm{baseline\\rate}
\\\cdot\\ \exp\\\left(\sum_k \beta_k \\ x_k(t, I, J)\right), \$\$ and
draws one event proportional to its rate. The waiting time is
exponential with rate equal to the total intensity.

Candidate-space size is exponential in \\\|V^I\|\\ and \\\|V^J\|\\, so
practical use is limited to small actor / item universes.

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
Time-Homogeneity: Relational Hyper Event Models with Time-Varying
Non-Linear Effects*. arXiv:2509.05289, Section 5.

## Examples

``` r
if (FALSE) { # \dontrun{
hl <- simulate_directed_hyperedge_events(
  n_events  = 40,
  senders   = paste0("a", 1:4),
  receivers = paste0("p", 1:4),
  max_size_I = 2, max_size_J = 2,
  baseline_rate = 0.3,
  endogenous_stats   = c("subrep_1_1", "size_I"),
  endogenous_effects = c(subrep_1_1 = 0.8, size_I = -0.4))
} # }
```
