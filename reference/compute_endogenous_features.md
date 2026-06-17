# Compute endogenous event-network statistics

Given a standardized relational event log, this helper derives
historical statistics for each event based on the evolving network. The
statistics follow the taxonomy of Juozaitienė and Wit (2025, JRSS-A) and
cover reciprocity, transitivity, cyclic closure, sending balance and
receiving balance. All definitions use the *continuous* convention
(effects persist even after a closure event).

## Usage

``` r
compute_endogenous_features(
  event_log,
  stats = c("sender_outdegree", "receiver_indegree", "reciprocity", "recency"),
  half_life = NULL,
  sort = TRUE,
  history_log = NULL,
  prior_log = NULL
)
```

## Arguments

- event_log:

  A data.frame containing at least `sender`, `receiver`, and `time`
  columns.

- stats:

  Character vector of statistics to compute. See **Details** for the
  full list of allowed values.

- half_life:

  Positive numeric; the half-life parameter \\T\\ for exponential-decay
  statistics (`*_exp_decay*`).

- sort:

  Logical; when `TRUE`, events are ordered by time prior to computing
  summaries (ties preserve input order).

- history_log:

  Optional data.frame giving the authoritative event history (columns
  `sender`, `receiver`, `time`). When supplied, only rows of `event_log`
  whose `(sender, receiver, time)` triple appears in `history_log`
  update the running network state; all other rows (e.g. sampled
  non-events / controls) have their statistics computed against that
  history but never enter it. This makes it possible to evaluate
  endogenous statistics for non-events without those non-events
  polluting the history. Defaults to `NULL` (every row is treated as an
  event). Currently supported only for statistics handled by the C++
  engine (see
  [`cpp_supported_stats()`](https://franciscorichter.github.io/amorem/reference/cpp_supported_stats.md)).

- prior_log:

  Optional data.frame of events that precede the study window (columns
  `sender`, `receiver`, `time`), used to **warm-start** the network
  state. Its rows always update the running state but never appear in
  the returned data.frame. This separates warm-starting from the
  non-event masking role of `history_log`: pass earlier history through
  `prior_log` and use `history_log` purely to mark which rows of
  `event_log` are real events. Defaults to `NULL`. Like `history_log`,
  it is currently supported only for statistics handled by the C++
  engine (see
  [`cpp_supported_stats()`](https://franciscorichter.github.io/amorem/reference/cpp_supported_stats.md)).

## Value

The event log with added columns, one per requested statistic
(`sender_receivers_set` is added as a list-column).

## Details

All statistics are evaluated immediately **before** the event is logged.
They are grouped into five families.

**Degree / baseline:**

- `sender_outdegree`:

  Number of events previously sent by the sender.

- `receiver_indegree`:

  Number of events previously received by the receiver.

- `recency`:

  Elapsed time since the last event on the same ordered pair; `NA` when
  the dyad is brand new.

**Reciprocity** — reverse-dyad (receiver \\\to\\ sender) history:

- `reciprocity` / `reciprocity_binary`:

  1 if the reverse dyad has ever been observed, 0 otherwise.

- `reciprocity_count`:

  Total count of past reverse-dyad events.

- `reciprocity_exp_decay`:

  Exponentially weighted sum of past reverse-dyad events (requires
  `half_life`).

- `reciprocity_time_recent`:

  Elapsed time since the most recent reverse-dyad event; `NA` if none.

- `reciprocity_time_first`:

  Elapsed time since the first reverse-dyad event; `NA` if none.

**Transitivity** — two-path \\s \to k \to r\\:

- `transitivity_binary`:

  1 if any intermediary \\k\\ exists with both \\(s,k)\\ and \\(k,r)\\
  before \\t\\.

- `transitivity_count`:

  Number of such intermediaries.

- `transitivity_binary_ordered`:

  Like binary but requiring \\(s,k)\\ to precede \\(k,r)\\.

- `transitivity_count_ordered`:

  Count with order restriction.

- `transitivity_exp_decay`:

  Exp-decay weighted sum over two-paths (requires `half_life`).

- `transitivity_exp_decay_ordered`:

  Exp-decay with order restriction.

- `transitivity_time_recent`:

  Time since the most recently completed two-path; `NA` if none.

- `transitivity_time_first`:

  Time since the earliest two-path; `NA` if none.

- `transitivity_time_recent_ordered`:

  Time since the most recent ordered two-path; `NA` if none.

- `transitivity_time_first_ordered`:

  Time since the earliest ordered two-path; `NA` if none.

**Cyclic closure** — two-path \\r \to k \to s\\, closed by \\s \to r\\:

- `cyclic_binary`:

  1 if any cyclic two-path exists.

- `cyclic_count`:

  Number of cyclic intermediaries.

- `cyclic_time_recent`:

  Time since the most recent cyclic two-path formation; `NA` if none.

- `cyclic_time_first`:

  Time since the first cyclic two-path formation; `NA` if none.

**Sending balance** — shared target: both \\s \to k\\ and \\r \to k\\
exist:

- `sending_balance_binary`:

  1 if any shared target exists.

- `sending_balance_count`:

  Number of shared targets.

- `sending_balance_time_recent`:

  Time since the most recent shared-target two-path formation; `NA` if
  none.

- `sending_balance_time_first`:

  Time since the first shared-target two-path formation; `NA` if none.

**Receiving balance** — shared source: both \\k \to s\\ and \\k \to r\\
exist:

- `receiving_balance_binary`:

  1 if any shared source exists.

- `receiving_balance_count`:

  Number of shared sources.

- `receiving_balance_time_recent`:

  Time since the most recent shared-source two-path formation; `NA` if
  none.

- `receiving_balance_time_first`:

  Time since the first shared-source two-path formation; `NA` if none.

The statistic `"sender_receivers_set"` is special: it adds a
**list-column** in which each element is the character vector of
receivers the row's sender has reached before that row (the building
block for set-valued endogenous covariates, e.g. an alien species'
previously invaded regions). It honours `history_log`, so it can be
computed for sampled non-events without those non-events polluting the
history.

## Examples

``` r
data(classroom_events)
feats <- compute_endogenous_features(classroom_events,
                                     stats = c("reciprocity", "recency"))
head(feats)
#>    time sender receiver interaction_type weight reciprocity recency
#> 1 0.125     14       12           social      1           0      NA
#> 2 0.250     12       14           social      1           1      NA
#> 3 0.375     18       12         sanction      1           0      NA
#> 4 0.500     12       18         sanction      1           1      NA
#> 5 0.625      1       12         sanction      1           0      NA
#> 6 0.750     12        1         sanction      1           1      NA
```
