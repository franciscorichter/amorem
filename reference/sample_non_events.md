# Sample non-events for inference

Given an observed event log, generate nested case-control data by
sampling counterfactual sender–receiver pairs according to predefined
strategies.

## Usage

``` r
sample_non_events(
  event_log,
  n_controls = 1,
  scope = c("all", "appearance", "citation"),
  mode = c("two", "one"),
  risk = c("standard", "remove"),
  exclude_pairs = NULL,
  allow_loops = FALSE,
  seed = NULL,
  max_attempts = 1000
)
```

## Arguments

- event_log:

  Data frame with columns `sender`, `receiver`, and `time`.

- n_controls:

  Number of non-events (controls) to sample per realized event.

- scope:

  Candidate set definition. `"all"` uses every actor observed in the
  data; `"appearance"` restricts to actors that have appeared in prior
  events; `"citation"` matches citation networks where senders are
  restricted to the papers that debut at the current time and receivers
  must have appeared earlier.

- mode:

  `"one"` draws both sender and receiver from the same candidate pool
  (single-mode). `"two"` samples sender and receiver from separate pools
  (two-mode).

- risk:

  Strategy governing the risk set. `"standard"` (default) keeps all
  unrealized dyads available across strata, whereas `"remove"` deletes a
  dyad from the candidate pool after it has occurred (useful for
  processes such as species invasions where a pair cannot reoccur).
  Under `"remove"`, dyads firing at the focal event's own timestamp are
  also kept out of its control pool (concurrent events are not valid
  non-events at that instant).

- exclude_pairs:

  Optional two-column data.frame/matrix of `(sender, receiver)` pairs
  that are structurally ineligible as controls and must never be sampled
  (e.g. an alien species' native range, or any dyad forbidden in
  advance). Columns named `sender`/`receiver` are used if present,
  otherwise the first two columns.

- allow_loops:

  Logical; can sampled non-events have identical sender and receiver?

- seed:

  Optional seed for reproducibility.

- max_attempts:

  Maximum resampling attempts per control before giving up (prevents
  infinite loops when candidate sets are small).

## Value

A data.frame containing the original events (`event = 1`) and the
sampled controls (`event = 0`), grouped by `stratum` identifiers.

## Examples

``` r
data(classroom_events)
cc <- sample_non_events(classroom_events, n_controls = 1, seed = 1)
head(cc)
#>   stratum event sender receiver  time interaction_type weight
#> 1       1     1     14       12 0.125           social      1
#> 2       1     0      1        3 0.125             <NA>     NA
#> 3       2     1     12       14 0.250           social      1
#> 4       2     0     20       10 0.250             <NA>     NA
#> 5       3     1     18       12 0.375         sanction      1
#> 6       3     0      6       19 0.375             <NA>     NA
```
