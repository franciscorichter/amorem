# amorem 1.3.0

## Changes in behaviour

* **`rem()` fits have class `"amorem_rem"`** instead of `"rem"`. The packages
  **relevent** and **redeem** register S3 methods on class `"rem"`, so loading
  either of them re-pointed `print()`, `summary()`, `coef()`, `plot()`,
  `predict()` and `logLik()` for amorem fits. Code that tests
  `inherits(fit, "rem")` must test `inherits(fit, "amorem_rem")`.

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

* `rem(method = "gam")` warns when long input with more than one control per
  stratum is widened, since the gam design keeps the first control of each
  stratum, and points to `method = "clogit"`, which uses every control. It
  only said that it widened the data.

* `rem()` stops when `re(x)` has no `x_ev` / `x_nv` columns. With a single
  column `x` the term gives the event and its control the same level and is
  zero; the documented fallback to that column is removed.

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

## New features

* `gof_univariate()`, `gof_multivariate()`, `gof_global()` and
  `gof_auxiliary()` take `n_samples` (default 1). Each test is computed on
  one case-control sample, so its verdict depends on the seed: on
  `classroom_events` the univariate transitivity test rejects at 5% in 9 of
  20 seeds. With `n_samples = S > 1` the test runs on S control samples
  (seeds `seed`, `seed + 1`, ..., or independent draws when `seed` is
  `NULL`) and the S p-values are combined with the Cauchy combination
  (Liu & Xie 2020), which is valid under arbitrary dependence among them.
  The result carries the combined `p_value`, the per-sample `p_values` and
  `n_samples`; the other fields come from the first sample. `n_samples = 1`
  returns the same result as before for the same seed.

## Bug fixes

* `print()` and `plot()` of `gof_rem()` results report a bootstrap p-value
  of 0 as a bound, `p < 1/n_sim` (for example `p < 0.001`); they printed
  `p = 0.000`.

* `sample_non_events()` warns when events get no control because their risk
  set holds no valid alternative (every other dyad excluded, removed or
  concurrent). Such events contribute nothing to the partial likelihood and
  were dropped without notice. Their strata are listed in
  `attr(, "no_control")`, also with `shift = "exponential"`, where it equals
  `attr(, "shift")$uninformative`. Events before any actor has appeared under
  `scope = "appearance"` have no controls by construction and give no warning.

* `sample_non_events(risk = "remove")` warns when a dyad fires more than once
  in the event log, which contradicts the one-event-per-dyad assumption of
  `"remove"`.

* The documentation of `risk = "standard"` says that dyads that have already
  fired stay at risk; it described them as "unrealized". The documentation of
  `rem(method = "nn")` names the optional **torch** engine.

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

* `rem()`, `widen_case_control()` and `nn_uncertainty()` read the event
  indicator by value: numeric or integer 0/1, logical, and character or
  factor `"0"`/`"1"` or `"FALSE"`/`"TRUE"`. Any other value is an error. A
  factor column was read by its level codes (1 and 2), so `method = "nn"`
  trained on reversed labels, `method = "clogit"` without a `stratum` column
  built wrong strata, and `widen_case_control()` stopped with an error.

* `rem(method = "clogit")` and `rem(method = "nn")` store the event-indicator
  column (`fit$case`) and the `stratum` argument, and `nn_uncertainty()` uses
  them. It took the first variable of the formula as the event indicator, so
  `rem(~ x + y, case = "event")` was bootstrapped with `x` as the indicator.

* `compare_models_global()` evaluates a global covariate at time `t` with the
  value of the last grid time at or before `t`. A time at or after the last
  grid time took the second-to-last value. A time before the first grid time
  takes the first value, as before; the documentation says so.

* `rem()` uses `offset()` terms; they were dropped without notice. For
  `method = "clogit"` the offset expression is evaluated on the rows of
  `data` and the fit equals `survival::clogit()` with the same offset. For
  `method = "gam"`, `offset(o)` names a column resolved like a linear term
  (an event-minus-control difference: `o`, else `d_o`, else `o_ev - o_nv`).
  `method = "nn"` stops when the formula has an offset.

* `rem(method = "clogit")` reports in `fit$n` the rows the fit used and
  records them in `fit$rows`, with a warning when rows with missing values
  are left out, as `method = "gam"` does. `fit$n` counted every row of
  `data`.

* `predict()` on a `rem(method = "gam")` fit takes wide data in the form
  `rem()` accepts and builds the internal design columns from it. It needed
  the internal column names in `newdata`.

* A `rem(method = "nn")` fit with `nn_control(engine = "torch")` and a `seed`
  gives the same result on the first fit of a session as on later ones:
  torch is loaded before the seed is set, since loading it draws from the
  random-number generator. `nn_uncertainty()` does the same before seeding
  its resampling.

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

* `gof_multivariate()`, `gof_global()`, `gof_auxiliary()`, `nn_control()`
  and `nn_uncertainty()` have runnable examples. The `rem()` and `gof_rem()`
  examples run only when mgcv is installed.

* The `rem()` return value lists `rows`, `case`, `stratum` and the
  `predict()` method.

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

# amorem 1.2.0

## Bug fixes

* `rem(method = "gam")` warns when rows with missing covariate values are left
  out of the fit, and records which rows it used (`fit$rows`, with `fit$n`
  counting only those). `gof_rem()` keeps the same rows when given the full
  data; it stopped with "non-conformable arguments" before.

* `sample_non_events(scope = "citation")` always draws the citing paper and
  the cited papers from separate pools. Under the `mode = "one"` default of
  1.1.0 it pooled them, so most controls had a sender other than the citing
  paper.

* `rem(method = "nn")` and `nn_uncertainty()` no longer change the caller's
  random-number state when given a seed (CRAN policy); fitted results are
  unchanged.

* Partial-dependence curves of `plot()` on neural fits and of
  `nn_uncertainty()` span the 1st to 99th percentile of each feature instead
  of the mean ± 2 standard deviations, which reached below the data for
  skewed, non-negative statistics.

* Concordance of neural fits splits a tied top score evenly between the tied
  candidates; it gave the whole stratum to the event.

* `simulate_relational_events(method = "tau_leap")` stops with a message when
  a single step would draw more than ten million events, which happens when
  an effect grows without bound; it could exhaust memory.

## New features

* `gof_rem()` tests a model fitted with `rem(method = "gam")` with cumulative
  martingale residuals (Boschi & Wit 2025): over event time
  (`test = "time"`), over the quantiles of a covariate
  (`test = "functional_form"`, which detects a wrong shape of the effect), or
  over the quantiles weighted by the term's basis
  (`test = "functional_form_score"`). It works on linear and smooth terms of
  the fitted model, and its null distribution is a multiplier bootstrap that
  subtracts the drift from estimating the coefficients. It has `print()` and
  `plot()` methods (`plot()` takes `main` and a `legend` position). The existing `gof_univariate()`, `gof_multivariate()`,
  `gof_global()` and `gof_auxiliary()` are unchanged.

* `rem()` fits store the name of their `time` column.

## Datasets

* New `alien_mammals`: the risk table of the first records of alien mammals
  with the covariates of Juozaitienė et al. (2023) (distance to the nearest
  invaded region, trade, temperature difference, colonial ties, land use),
  and the never-at-risk pairs and species entry years as attributes; used in
  the species-invasion section of the software paper.

* New event logs, all under licences that allow redistribution:
  `copenhagen_calls`, `copenhagen_sms` and `copenhagen_actors` (Copenhagen
  Networks Study, MIT); `us_leader_visits` (leader-to-leader visits to and from
  the United States, 1945-2019, CC0); `football_results` (men's international
  football matches since 1872, CC0); `ucdp_dyads` (UCDP armed-conflict dyads,
  1946-2025, CC BY 4.0); `alien_invasions` (first records of alien species by
  region, 1880-2005, CC0).

* New hyperevent log: `congress_bills_118`, one sponsor and the cosponsors of
  each bill of the 118th US Congress, with `congress_members_118` (public
  domain).

* New global covariates: `oni` (Oceanic Nino Index since 1950), `daily_weather`
  (NOAA daily temperature and precipitation for the cities of the bundled email
  and messaging logs) and `public_holidays`.

* `radoslaw_email` is rebuilt from the authors' CC0 release (Nurek & Michalski
  2020, doi:10.7910/DVN/6Z3CGX). It keeps the original employee ids, which
  match the new `radoslaw_hierarchy` (who reports to whom), and its
  timestamps are read as Warsaw local time. The previous copy, from Network
  Repository, read them as UTC, so it ignored daylight saving time: events
  sent during Polish summer time are now one hour earlier relative to the
  first event, and `unix_origin` is one hour earlier. The number of events
  and each employee's activity are unchanged.

* The pkgdown site has a data catalogue: licences, download code and
  structural profiles of 78 relational-event datasets and covariates, including
  the many whose licences do not allow amorem to redistribute them.

# amorem 1.1.0

## Bug fixes

* **Endogenous statistics on case-control data no longer count the sampled
  controls as events.** `endogenous_features()` on the output of
  `sample_non_events()` (a 0/1 `event` column with control rows) now builds
  the network history from the `event == 1` rows only; the controls read it
  but never enter it. Before, every row updated the history, so each
  statistic also counted hypothetical dyads. This was the default path inside
  `compare_models()`, `compare_models_smooth()`, `gof()`,
  `martingale_residuals()` and the vignettes. On six simulated datasets with
  a reciprocity effect of 0.3, the estimate moved from 0.20 to 0.31 on
  average. Results of those functions change and should be re-run. Pass
  `history_log = event_log` to treat every row as an event.

* **`rem()` evaluates `tv()` and `tvnl()` terms at each row's own time.**
  When `data` has `time_ev` / `time_nv` instead of a single time column (the
  wide form of `sample_non_events(shift = "exponential")`), `tv(x)`
  contributes `beta(t) x_ev - beta(t*) x_nv` and `tvnl()` uses both times.
  Before, the event time was used for both rows. Models with a single time
  column give the same formula and fit as before.

* **`compare_models_global()` now uses the paper's time-shifted design.** It
  drew one shift per control row, never shifted the event, never checked the
  observation window (control times could precede the data), evaluated the
  controls' dyadic statistics at the event time, and let sampled controls
  enter the network history. On simulated data with a global effect of 1 it
  returned estimates of -1.74, 2.63 and -2.12 over three datasets. It now
  draws its sample with `sample_non_events(shift = "exponential")`, computes
  dyadic statistics against the real history at each row's own time,
  evaluates `tv` / `tvnl` terms at each row's own time, and drops events with
  no control; the same three datasets give 0.85, 1.02 and 1.01. The shift
  mean is now `shift_scale` times the average event time (it was times the
  average inter-arrival time), and a `window` argument is passed through.
  Results of earlier `compare_models_global()` fits change and should be
  re-run.

* `widen_case_control()` and the `clogit` / `nn` backends of `rem()` use the
  `stratum` column written by `sample_non_events()` when `stratum = NULL`,
  instead of rebuilding strata as `cumsum(case == 1)`. The rebuilt strata
  assumed each case was followed by its controls, which stops holding once
  `endogenous_features()` re-sorts rows by time with ties, or with shifted
  controls, and then paired cases with the wrong controls. Data without a
  `stratum` column (eventnet output) is handled as before.

* **`sample_non_events()` risk-set edge cases (#102).**
  - `exclude_pairs` and, under `risk = "remove"`, same-time events are now part
    of the check for whether any valid control exists, so a stratum whose every
    alternative is excluded gets no controls instead of stopping with "Unable
    to sample a valid non-event after `max_attempts` attempts".
  - `scope = "appearance"` no longer falls back to all actors when no actor
    has appeared yet: the first event gets no controls, and controls are only
    ever drawn from actors seen in prior events, as documented. Results change
    for the first stratum(s) of `scope = "appearance"` fits.
  - Factor `sender` / `receiver` columns are coerced to character, so the
    output columns are character whatever the input type.
  - The documentation of `mode` states which risk set each mode gives: `"two"`
    never draws a receiver-only actor as a control sender (or vice versa), so
    networks with one node set should use `mode = "one"`.
  - The unreachable empty-pool fallbacks in the pair sampler were removed.

## Changes in behaviour

* `sample_non_events()` now defaults to `mode = "one"`, the risk set of
  networks whose senders and receivers are one node set, and the default of
  `compare_models()`, `compare_models_smooth()`, `compare_models_global()`,
  `gof()` and `martingale_residuals()`. Calls that relied on the old default
  `mode = "two"` (bipartite networks) must now pass it.

## New features

* **New dataset `enso_nino34`:** the tree-ring reconstruction of the
  November–January Niño3.4 sea-surface temperature anomaly by Li et al.
  (2013), one value per year from 1301 to 2005 (NOAA NCEI study 14632), as a
  global covariate on a yearly clock. The raw NOAA file ships in
  `inst/extdata/enso_nino34/`, and `data-raw/enso_nino34.R` rebuilds the
  object.

* `vignette("species-invasion")` now simulates five centuries of invasions
  (1500–2005) driven by distance, a neighbour pressure and ENSO. It shows
  that ordinary case-control sampling gives an ENSO difference of zero in
  every stratum, and recovers all three effects with time-shifted sampling
  and `rem()`, reporting standard errors.

* **Time-shifted case-control sampling for global covariates (#101).**
  `sample_non_events(shift = "exponential")` implements Section 4 of Lembo,
  Juozaitienė, Vinciotti & Wit (2025, JRSS-C): one exponential shift per dyad,
  each control drawn uniformly from the dyads whose back-shifted time lies in
  the observation `window` and stored at that time, so covariates that depend
  only on time no longer cancel within strata. `shift_scale` sets the mean
  shift as a multiple of the average event time, as in the paper. Risk-set
  rules (`exclude_pairs`, `risk = "remove"`, `scope = "appearance"`) are
  evaluated at the control's own time; events with no other dyad in their
  shifted risk set get no control and are listed in
  `attr(, "shift")$uninformative`. The attribute also holds the shift mean,
  the window and the per-dyad shifts.

* `endogenous_features(history_log = )` and `prior_log` now work for every
  statistic, including `reciprocity_exp_decay`, `reciprocity_time_recent` and
  `reciprocity_time_first`, which the compiled engine does not cover.

* **Per-term basis settings in `rem()` formulas (#91).** Smooth terms take the
  basis arguments of `mgcv::s()` / `mgcv::te()` after the covariate, so terms
  in one model can use different basis dimensions and types:
  `tv(x, k = 20, bs = "cr") + nl(y, k = 5, bs = "ps")`. `tvnl()` takes one
  value per margin (`tvnl(x, k = c(5, 8))`). A new global `bs` argument joins
  the global `k` as the default for terms that set neither; existing formulas
  give the same model as before.

* `sample_non_events(exclude_concurrent = )` controls whether dyads with an
  event at the focal event's own time can be controls. The default keeps the
  existing behaviour: excluded under `risk = "remove"`, at risk under
  `risk = "standard"` (the Breslow convention).

# amorem 1.0.1

## Bug fixes

* **`compare_models()` did not stratify on the matched sets under **survival**
  before 3.7-3.** The Cox formula was built with a namespace-qualified
  `survival::strata(stratum)`, and `terms(specials = )` does not match a
  qualified call, so the matched-set identifier was silently fitted as an
  ordinary factor covariate in an unstratified model. Coefficients and the
  `delta_AIC` column were unaffected; the absolute `log_lik` was shifted by
  `-n_events * log(n_strata)` and the degrees of freedom inflated by
  `n_strata - 1`, so reported `AIC` values were wrong. The same applied to the
  `frailty()` terms on the random-effects path, which is why the `coxme`
  two-axis fit did not complete. All four call sites now use bare specials,
  which every **survival** version matches, and regression tests assert that
  `AIC == -2 * log_lik + 2 * df` and that no stratum dummies enter as
  covariates. Anyone who published absolute log-likelihood or AIC values from
  `compare_models(n_controls > 1)` should re-run them.

# amorem 1.0.0

First CRAN release, under the name **amorem**. The package was renamed from the
working name `amore`, which collided (case-insensitively) with the archived CRAN
package `AMORE`. This release consolidates the 0.9.0 development line into the
first stable, installable version: the unified `rem()` front-end (the `clogit`,
`gam`, and `nn` backends, including the additive-spline architecture), the
Gillespie / tau-leap simulation engine, the endogenous-statistics catalogue, and
the martingale-residual goodness-of-fit family. Relative to 0.9.0 the package was renamed to **amorem** and the exported feature
functions dropped their `compute_` prefix --- `compute_endogenous_features()` and
`compute_hyperedge_features()` became `endogenous_features()` and
`hyperedge_features()`; the rest of the API is unchanged.

## New features

* **torch training engine for `rem(method = "nn")`.** `nn_control(engine =
  "torch")` trains the same model and conditional-logistic loss as the built-in
  pure-R engine using **torch** (libtorch autograd + Adam), markedly faster
  and, with `batch_strata`, scaling to large event logs (optionally on GPU).
  The fitted object is interchangeable with the R engine. `torch` is a
  *Suggests* dependency; the torch engine requires equal-sized strata.
* **`nn_uncertainty()`** quantifies uncertainty for a neural fit by a stratum
  bootstrap, returning partial-dependence uncertainty bands and a concordance
  confidence interval (with `print()` and `plot()` methods) — the inferential
  counterpart the point-prediction `nn` backend otherwise lacks.

# amorem 0.9.0

New neural backend and a small number of API refinements; the version
intended for the first CRAN release.

* **STREAM-style additive splines:** `nn_control(architecture =
  "additive_spline", batch_strata = )` fits per-covariate B-spline effects by
  (mini-batch) stochastic gradient on the exact case-control partial
  likelihood — the construction of Filippi-Mazzola & Wit (2024, JRSS-C,
  [doi:10.1093/jrsssc/qlae023](https://doi.org/10.1093/jrsssc/qlae023)) — giving interpretable additive smooth
  curves on the same objective as `clogit`, with mini-batching for large
  event logs.
* **New `rem(method = "nn")` backend:** a multilayer perceptron scores every
  candidate in a case-control stratum and is trained on the
  conditional-logistic partial likelihood (softmax over each risk set) — a
  nonlinear, prediction-oriented counterpart of `clogit`. Pure-R implementation
  (no extra dependencies), configured via `nn_control()`; `summary()` reports
  in-sample (and, with a validation split, held-out) concordance and
  `plot(type = "pdp")` shows per-feature partial-dependence curves.
* **API:** the degenerate-logistic backend is now `method = "gam"` (was
  `"degenerate"`); the smooth-term wrappers are `tv()` / `nl()` / `tvnl()`
  (was `tve()` / `nle()` / `tvnle()`); `re()` is unchanged.
* `rem()`'s `case` argument now defaults to `NULL` and is taken from the
  formula's left-hand side (e.g. `event ~ x`) for the `clogit`/`nn` backends.
* `widen_case_control()` auto-detects the 0/1 indicator column (`event` or
  `IS_OBSERVED`) when `case` is not given.
* `widen_case_control()` now carries the sender/receiver identifiers of the
  case and its matched control into the output (`sender_ev`/`receiver_ev`/
  `sender_nv`/`receiver_nv`); the new `keep_ids` argument controls this
  (default `TRUE`). The dyads behind each pair are no longer lost, and `re()`
  grouping terms can reach the actor levels (#92).
* `rem(method = "gam")` now detects long-format case-control input (a
  `event`/`IS_OBSERVED` indicator with control rows) and widens it with
  `widen_case_control()` before fitting, emitting a message — instead of
  silently misreading raw per-row values as event-minus-control differences
  (#93).
* `compute_endogenous_features()` gains a `prior_log` argument for
  warm-starting the network state from events that precede the study window:
  its rows update the running state but never appear in the output, separating
  warm-starting from the non-event masking role of `history_log` (#94).
* `cpp_supported_stats()` is now exported.

# amorem 0.1.0

First release.

* `rem()` unified fitter for preprocessed case-control data, with a
  `gam` (case-1-control logistic via `mgcv::gam()`) and a `clogit` backend.
* Smooth-term formula wrappers for the `gam` backend (time-varying, non-linear,
  time-varying-non-linear) and an `re()` grouping random effect; `re()`
  reproduces the Intro-to-REM tutorial parameterization, and `rem()` exposes a
  `gam_method` argument.
* Simulation via `simulate_relational_events()` (Gillespie and tau-leap),
  the endogenous-statistic feature engine, non-event sampling, and the
  martingale-residual goodness-of-fit family.
