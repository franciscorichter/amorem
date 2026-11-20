## Changes in behaviour

* **Tied times: statistics at time t use only events strictly before t**, in
  every path of `endogenous_features()` (compiled and pure-R, with and without
  a history mask) and for event and control rows alike. Without a mask the
  compiled engine read ties in row order, so A->B and B->A at t = 1 gave
  reciprocity `0 1`; they now give `0 0`, as they already did with a mask.

* `endogenous_features()` identifies the events of case-control data by the
  0/1 `event` column whenever it is present, also when `history_log` or
  `prior_log` is given; `history_log` marks event rows by
  (sender, receiver, time) only for logs without an `event` column. Passing
  `history_log = event_log` no longer turns the controls of case-control data
  into events. A factor `event` column is read by its labels.

* `sample_non_events(scope = "citation")` draws control receivers from every
  paper that has appeared in the log before the citing event, as a citing or a
  cited paper. Before, only papers that had already cited something were
  eligible, so papers that are only ever cited were never controls. The
  control sender is still the citing paper.

* `sample_non_events()` orders the log by time before sampling (ties keep
  their input order); stratum k is the k-th event in that order. Appearance,
  removal and concurrency rules followed row order before, so an unsorted log
  gave controls drawn from actors and dyads of later events.

* The no-control warning of `sample_non_events()` does not count events at
  the start of the log that come before the first event with a control, where
  the risk set is still being built; their strata are still listed in
  `attr(, "no_control")`. When no event has a control, all are counted.
  `classroom_events` with `scope = "appearance", risk = "remove"` gives no such
  warning; it counted events 2 and 3 before.

## Bug fixes

* The pure-R path of `endogenous_features()` (taken when any statistic outside
  `cpp_supported_stats()` is requested, e.g. `reciprocity_time_recent`) reads a
  whole timestamp before adding its events to the history. It added each event
  before its same-time controls were computed, so a control saw its own event
  and the two engines disagreed on tied logs.

* `endogenous_features(history_log = )` no longer counts a control as an event
  when it coincides with another stratum's event at the same time; such a
  control raised the outdegree and other statistics of later rows.

* `sample_non_events(scope = "appearance")` admits only actors that appeared
  at an earlier timestamp; it admitted actors first seen in an earlier row with
  the same time. Under `risk = "remove"` a dyad likewise leaves the pool after
  the timestamp of its first event.

* `endogenous_features()` and `sample_non_events()` stop with an error on `NA`
  times (also in `history_log` and `prior_log`). `endogenous_features()` hung
  on an `NA` time whenever a history mask was in use; the compiled loop now
  returns on non-finite times regardless.

* `sample_non_events()` draws a valid control uniformly from the enumerated
  valid pairs after `max_attempts` rejection draws miss, as the shifted branch
  already did. It stopped with "Unable to sample a valid non-event" on runs
  where a valid control existed but was rare.

* `sample_non_events(shift = "exponential")` accepts `Date` and `POSIXct`
  times and windows and returns times of the same class; it failed on them.
  A log with a single timestamp (default window) gives events without controls
  and a warning instead of an error. The shifted branch emits the same
  no-control warning as the ordinary branch.

* `sample_non_events()` stops on a non-integer `n_controls`; `1.5` was
  truncated to 1. The documentation states that controls are drawn with
  replacement, so a stratum with a small risk set can hold the same control
  more than once.

* `standardize_event_log()` reads a factor time column by its labels (it used
  the level codes, so `"10"` sorted before `"2"`) and stops on text times that
  are not numbers, such as unconverted date strings (they became `NA` and,
  with `drop_nas = TRUE`, every row was dropped).
