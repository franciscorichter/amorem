## Changes in behaviour

* `simulate_relational_events(method = "gillespie")` draws waiting times by
  thinning when a statistic changes between events (`*_exp_decay`, `recency`,
  `*_time_*`). It used to draw the waiting time from the rates at the previous
  event and choose the dyad from the undecayed state, so an
  `reciprocity_exp_decay` effect of 1.5 (half-life 0.5, 6 actors, 4000 events)
  was recovered as 2.22--2.69; it is now recovered as 1.37--1.61 (SE 0.12) over
  10 replicates. Logs simulated with these statistics differ from those of
  earlier versions under the same seed. Logs without them are unchanged.

* With a negative effect on `recency` or a `*_time_*` statistic the rates of
  `simulate_relational_events()` can decay toward zero; the simulation stops
  with a message once every rate is below `exp(-700)`, and returns the events
  produced so far. It used to keep generating events.

* `transform_recency(half_life = T)` gives weight 0.5 at a gap of `T`,
  `exp(-delta * log(2) / T)`, the half-life convention of the `*_exp_decay`
  statistics. It used `T` as the e-folding scale (weight 0.368 at `T`).
  `half_life = Inf` gives weight 1 (no decay); it was an error. The median
  rule is unchanged.

## Bug fixes

* `simulate_relational_events()` and `simulate_directed_hyperevents_tvnl()`
  draw valid controls when one candidate is left. `sample(x, n)` on a length-1
  pool drew from `1:x`, so with two actors and `n_controls = 1` controls were
  loops or equal to their case.

* `simulate_relational_events()`, `simulate_hyperedge_events()`,
  `simulate_directed_hyperedge_events()` and
  `simulate_directed_hyperevents_tvnl()` compute selection weights as
  `exp(log_w - max(log_w))` and keep the total rate on its scale for waiting
  times. A log-intensity above 709 overflowed and the dyad was set to rate 0;
  a very small one underflowed to 0 and the dyad left the control pool. A
  log-intensity of `NaN` or `+Inf` is an error. Under `method = "tau_leap"`,
  and in `simulate_directed_hyperevents_tvnl()`, rates too large to simulate
  stop with a message.

* `simulate_relational_events(method = "tau_leap")` records the
  `cyclic_*`, `sending_balance_*` and `receiving_balance_*`
  `*_time_*_ordered` statistics at each event's time, as it does for
  transitivity; they were recorded at the start of the step.

* `simulate_relational_events(risk = "remove", n_controls > 0)` stops with a
  message when fewer than `n_controls + 1` dyads remain in the risk set and
  returns the events produced so far; it stopped with an error.

* `simulate_relational_events(n_events = 0, n_controls > 0)` returns the
  columns in the order of a non-empty result (`stratum`, `event` first).

* `simulate_relational_events()` stops when `n_events` or `n_controls` is not
  a whole number, and `simulate_hyperedge_events()`,
  `simulate_directed_hyperedge_events()` and
  `simulate_directed_hyperevents_tvnl()` do the same for `n_events` and
  `n_controls`; non-integer values were truncated.

* `simulate_directed_hyperevents_tvnl()` cuts its last grid cell at `horizon`;
  events could fall past it (1.0048 with `horizon = 1`). Its documentation
  describes the piecewise-constant midpoint scheme it uses; it called it
  thinning.

* `simulate_hyperedge_events()` and `simulate_directed_hyperedge_events()`
  reject `subrep_0` and `subrep_0_<l>`, which `hyperedge_features()` rejects.

* `hyperedge_log()` rejects an actor listed twice in one event's `I` or `J`,
  and NA or empty actor names.

## Documentation

* `alien_invasions` has 259 regions (the help page said 272); `start` equals
  `stop` in 421 rows, 407 of them after 1880 (the page said only in 1880).
* `classroom_events$weight` is numeric, 1 for direct and 0.2 for broadcast
  communication; `social_evolution_actors$gradeType` has levels `"1"`--`"5"`;
  `social_evolution_calls` spans 6 September to 18 October 2008.
* The help pages of `classroom_*`, `social_evolution_*`, `college_msg` and
  `email_eu_core` state the licence situation of their sources: no licence is
  stated for any of these data; `networkDynamic` and `goldfish`, which
  distribute two of them, are GPL. The Social Evolution page records the MIT
  Reality Commons request not to redistribute the data.
