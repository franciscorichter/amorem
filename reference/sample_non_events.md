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
  mode = c("one", "two"),
  risk = c("standard", "remove"),
  exclude_pairs = NULL,
  exclude_concurrent = NULL,
  allow_loops = FALSE,
  seed = NULL,
  max_attempts = 1000,
  shift = c("none", "exponential"),
  shift_scale = 1,
  window = NULL
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
  events (so the first event, with no prior events, gets no controls);
  `"citation"` matches citation networks where senders are restricted to
  the papers that debut at the current time and receivers must have
  appeared earlier; it always draws senders and receivers from these two
  separate pools, whatever `mode` says.

- mode:

  `"one"` (default) draws both sender and receiver from the same
  candidate pool (single-mode): every actor seen in either role can be a
  control sender or receiver, as in networks whose senders and receivers
  are one node set (e.g. bike stations, e-mail users). `"two"` samples
  sender and receiver from separate pools (two-mode): an actor seen only
  as a receiver is never a control sender, and vice versa, as in
  bipartite networks (e.g. species invading regions).

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

- exclude_concurrent:

  Logical; keep dyads with an event at the focal event's own timestamp
  out of its control pool? Defaults to `TRUE` under `risk = "remove"`
  and `FALSE` under `risk = "standard"`, where a tied event is still at
  risk at that instant (the Breslow convention).

- allow_loops:

  Logical; can sampled non-events have identical sender and receiver?

- seed:

  Optional seed for reproducibility.

- max_attempts:

  Maximum resampling attempts per control before giving up (prevents
  infinite loops when candidate sets are small). With
  `shift = "exponential"` it is the number of rejection draws tried
  before the valid candidates are enumerated, so sampling never fails
  there.

- shift:

  `"none"` (default) gives every control its event's time, so a global
  covariate (a function of time only, e.g. weather or time of day) takes
  the same value within each stratum and cancels from the partial
  likelihood. `"exponential"` samples controls from a time-shifted copy
  of the event process (Lembo, Juozaitienė, Vinciotti & Wit 2025,
  Section 4), so controls carry their own times and global effects stay
  estimable; see *Time-shifted sampling*.

- shift_scale:

  Positive number \\\nu\\: the shifts have mean \\\nu\\ times the
  average event time, measured from the start of `window` (the paper
  uses \\\nu = 1\\). Larger shifts carry more information about global
  effects, but leave more events with no control. Used only with
  `shift = "exponential"`.

- window:

  Observation window `c(start, end)` for `shift = "exponential"`.
  Defaults to `c(min(time), max(time))`; pass the true window (the
  paper's \\\[0, T\]\\) when it is known.

## Value

A data.frame containing the original events (`event = 1`) and the
sampled controls (`event = 0`), grouped by `stratum` identifiers. With
`shift = "exponential"` it carries `attr(, "shift")`: a list with the
shift `mean`, the `window`, the per-dyad `shifts` (named
`"sender->receiver"`) and the `uninformative` strata that got no
control.

## Time-shifted sampling

With `shift = "exponential"`, every dyad of the risk set (all sender
\\\times\\ receiver pairs for `mode = "two"`, all ordered actor pairs
for `mode = "one"`) draws one shift \\h\_{sr} \sim \mathrm{Exp}\\,
reused for every event on that dyad. Event \\k\\ on dyad \\(s, r)\\
moves to \\t^e = t_k + h\_{sr}\\; its control is drawn uniformly from
the other dyads whose back-shifted time \\t^\* = t^e - h\_{s^\*r^\*}\\
lies in `window`, and is stored with `time` \\t^\*\\. The risk-set rules
are evaluated at \\t^\*\\: `exclude_pairs` always applies; under
`risk = "remove"` a dyad that has fired before \\t^\*\\ is not at risk;
under `scope = "appearance"` both actors must have appeared in an event
before \\t^\*\\. An event whose shifted risk set holds no other valid
dyad carries no information and gets no controls. `scope = "citation"`
is not supported, and `exclude_concurrent` is not used (control times
are continuous).

Covariates for a control must then be evaluated at its own time: compute
endogenous statistics with
`endogenous_features(cc, stats, history_log = event_log)`, which
evaluates each row against the events strictly before it, and evaluate
global covariates at each row's `time`.
[`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
then gives `time_ev` / `time_nv` and `<cov>_ev` / `<cov>_nv`, and a
global effect is fitted with `rem(~ nl(<cov>))`, the baseline with
`rem(~ nl(time))`.

## References

Lembo M, Juozaitienė R, Vinciotti V, Wit EC (2025). Relational event
models with global covariates: an application to bike sharing. *Journal
of the Royal Statistical Society, Series C*, 75, 583–600.
[doi:10.1093/jrsssc/qlaf058](https://doi.org/10.1093/jrsssc/qlaf058) .

## Examples

``` r
data(classroom_events)
cc <- sample_non_events(classroom_events, n_controls = 1, seed = 1)
head(cc)
#>   stratum event sender receiver  time interaction_type weight
#> 1       1     1     14       12 0.125           social      1
#> 2       1     0     12       15 0.125             <NA>     NA
#> 3       2     1     12       14 0.250           social      1
#> 4       2     0      1       10 0.250             <NA>     NA
#> 5       3     1     18       12 0.375         sanction      1
#> 6       3     0     19        3 0.375             <NA>     NA
```
