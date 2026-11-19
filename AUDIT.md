# amorem 1.3.0 — pre-release audit (2026-11-19)

State reviewed: `main` at `4bfc31a`. `R CMD check --as-cran` (R 4.4.0, macOS): 0 errors, 0 warnings,
2 NOTEs (installed size 5.4 MB; time server unreachable). Reverse dependencies on CRAN: none.

Every finding below was reproduced by running the code shown. Items marked ✔ were re-run a
second time independently.

Verified correct: `rem(method = "clogit")` equals `survival::clogit` (coefficients and logLik);
gam with one control equals clogit; `compare_models()` equals clogit; martingale residuals equal
`survival`'s to 2e-9; `gof_rem()` has size 0.03–0.07 under the null and power 1.0 against
nonlinear and time-varying effects; the Gillespie and tau-leap simulators recover count,
binary, transitivity and outdegree effects within Monte Carlo error; the 64 C++ statistics match
the R implementation on logs without tied times; no sampler draws a loop, an excluded pair or the
event dyad itself; seeds restore the caller's RNG state.

## A. Wrong results with no error (fix before release)

1. ✔ **Pure-R feature path: a control sees its own event.** `R/preprocess.R:872–1003`. Requesting
   any R-only statistic (`reciprocity_exp_decay`, `reciprocity_time_recent`, `reciprocity_time_first`,
   `reciprocity_*_interrupted`) sends all requested statistics through a row-by-row loop that adds
   each event to the history before its same-time controls are computed. The C++ path reads a
   whole timestamp before writing.
   ```r
   cc <- data.frame(stratum=c(1,1,2,2,3,3), event=c(1,0,1,0,1,0),
     sender=c("A","B","C","B","B","A"), receiver=c("B","A","D","A","A","C"), time=c(1,1,2,2,3,3))
   endogenous_features(cc, "reciprocity")$reciprocity                               # 0 0 0 1 1 0
   endogenous_features(cc, c("reciprocity","reciprocity_time_recent"))$reciprocity  # 0 1 0 1 1 0
   ```
   With tied times and a history mask the two engines also differ on outdegree, reciprocity_count
   and the triadic statistics (63 of 300 rows for `sender_outdegree`).

2. ✔ **`history_log` / `prior_log` count same-time controls as events.** `R/preprocess.R:407–409`,
   `534–541`. Events are identified by matching (sender, receiver, time); under the default
   `risk = "standard"` a control may equal another stratum's event at the same time.
   ```r
   E <- data.frame(sender=c("A","C","A"), receiver=c("B","D","E"), time=c(1,1,2))
   cc <- sample_non_events(E, 3, seed = 17)        # stratum 2 draws control A->B at t = 1
   endogenous_features(cc, "sender_outdegree", history_log = E)  # row 9 (A->E, t=2): 2; true 1
   ```

3. ✔ **`scope = "appearance"` admits actors first seen at the same time.**
   `R/preprocess.R:1497–1499` updates the pool per row, not per timestamp.
   ```r
   toy <- data.frame(sender=c("A","C","E"), receiver=c("B","D","F"), time=c(1,1,2))
   sample_non_events(toy, 3, scope = "appearance", seed = 1)   # stratum 2 (t=1) gets A->B, B->A
   ```
   67 such controls in `classroom_events` with 5 controls per event.

4. **`sample_non_events()` assumes a time-sorted log.** `R/preprocess.R:1460–1504`. Appearance
   and `risk = "remove"` follow row order.
   ```r
   toy2 <- data.frame(sender=c("C","A","B"), receiver=c("D","B","A"), time=c(3,1,2))
   sample_non_events(toy2, 2, scope="appearance", risk="remove", seed=1)  # t=1 gets D->C
   ```

5. ✔ **A factor `event` column inverts cases and controls.** `R/rem.R:174, 218, 489`,
   `R/widen_case_control.R:69`, `R/rem_nn_uncertainty.R:49`: `as.integer(factor(c("0","1")))` is
   `1 2`. `method = "nn"` trains on reversed labels; clogit without a `stratum` column gets wrong
   strata; `widen_case_control()` errors.

6. ✔ **`nn_uncertainty()` rebuilds `case` from the formula.** `R/rem_nn_uncertainty.R:44, 47`;
   `rem()` does not store `case` / `stratum`. With `rem(~ x + y, case = "event")` the bootstrap
   uses `x` as the event indicator (concordance 0.18 against the fit's 0.86).

7. ✔ **`compare_models_global()` never uses the last grid value.** `R/compare_models_global.R:214`:
   `findInterval(..., all.inside = TRUE)` maps t ≥ last grid time to the second-to-last value. The
   package example's grid ends at `max(time)`. Fix: `pmax(findInterval(t, g$time[ord]), 1L)`.

8. **`rem()` drops `offset()` terms silently** (gam and clogit). `R/rem.R:142` reads only
   `term.labels`. Support them or stop when `attr(terms(f), "offset")` is set.

9. ✔ **Simulator: length-1 `sample()` gives invalid controls.** `R/simulate_events.R:1593` (Gillespie),
   `:1368` (tau-leap), `R/simulate_directed_hyperevents_tvnl.R:166`. With one candidate left,
   `sample(k, 1)` draws from `1:k`. Two actors, `n_controls = 1`: 85 of 200 controls are loops,
   37 equal their case. Use `x[sample.int(length(x), n)]`.

10. ✔ **Simulator: overflowing intensity drops the dyad.** `R/simulate_events.R:688, 1223, 1497`
    set non-finite weights to 0, so `exp(710)` becomes rate 0 (A->B fires 0 of 20 times; with 700,
    20 of 20). Underflow shrinks the control pool and raises "n_controls >= admissible dyads".
    Compute weights as `exp(log_w - max(log_w))`.

11. ✔ **Simulator: exp-decay statistics are chosen from undecayed state.**
    `R/simulate_events.R:1491–1512` against `:1565–1569`: rates come from the state at the previous
    event and decay is applied after the new time is drawn. `reciprocity_exp_decay` with effect 1.5,
    half-life 0.5 is recovered as 2.22–2.69 (SE ≈ 0.11) over 5 replicates. Recency and `*_time_*`
    statistics carry the same mismatch with negligible bias (0.201–0.203 for 0.2).

12. **`simulate_directed_hyperevents_tvnl()` can pass `horizon`** (`:146–153`, last step not capped;
    max time 1.0048 with `horizon = 1`). Its docs call the scheme "thinning"; it is a
    piecewise-constant midpoint rate.

13. **`standardize_event_log()` with factor or text times.** `R/preprocess.R:73–81`: a factor time
    becomes level codes (`"10"` sorts before `"2"`); text dates become NA and `drop_nas = TRUE` returns
    0 rows with only a coercion warning.

## B. Hangs, errors and reproducibility

14. ✔ **`NA` time hangs R** (also a CRAN risk). `src/compute_features_cpp.cpp:987–989`:
    `times[g_end] == times[g]` is never true for NaN. Reached whenever the history mask is on
    (controls present, `history_log` or `prior_log`).
    ```r
    ev <- data.frame(sender=c("A","B","C"), receiver=c("B","A","A"), time=c(1,2,NA))
    endogenous_features(ev, "reciprocity", history_log = ev)   # never returns
    ```
    `sample_non_events()` keeps NA-time rows, so it can produce such data.
15. **`max_attempts` aborts valid runs under `risk = "remove"`** (`R/preprocess.R:1473–1486`); the
    ordinary branch lacks the full-enumeration fallback the shift branch has. One species, 3000
    regions, `mode = "two"`: "Unable to sample a valid non-event after 1000 attempts".
16. **torch with `batch_strata` is not reproducible on the first fit of a session**
    (`R/rem_nn.R:331`): loading torch consumes RNG draws after `set.seed()`. Call
    `requireNamespace("torch")` before seeding.
17. **`shift = "exponential"`**: fails on `Date`/`POSIXct` times (`R/preprocess.R:1416`) and on a log
    with a single timestamp (default `window` has start = end); returns before the documented
    `no_control` warning.
18. **`re(x)` with a single column** (documented fallback) crashes inside mgcv
    (`chol.default ... 'a' must have dims > 0`); the term is identically zero.
19. **tau-leap records the cyclic, sending- and receiving-balance `*_time_*_ordered` statistics at
    step start** (`R/simulate_events.R:1281–1301`); transitivity's is recorded at event time.

## C. Documentation, data and CRAN polish

20. ✔ `alien_invasions` docs say 272 regions; the data has 259 (`R/data.R:339`). Same block: 407 rows
    have `start == stop` with `stop != 1880`, against the stated rule.
21. `classroom_events$weight` documented as integer (values 0.2, 1); `social_evolution_actors$gradeType`
    levels are "1"–"5", not names; `social_evolution_calls` spans 2008-09-06 to 2008-10-18, not the
    2008–09 year.
22. No licence stated for `classroom_*` (networkDynamic, GPL), `social_evolution_*` (goldfish),
    `college_msg`, `email_eu_core` (SNAP), in an MIT package whose cran-comments says every dataset's
    licence allows redistribution.
23. `gof_multivariate`, `gof_global`, `gof_auxiliary`, `nn_control`, `nn_uncertainty` have no examples;
    the `rem` and `gof_rem` examples use mgcv without a guard.
24. gam on long data with several controls keeps only the first control, and says only that it
    widens (`R/rem.R:245`).
25. `predict()` on gam fits needs internal column names in `newdata`; not listed under `@return`.
26. `transform_recency(half_life = T)` uses T as the e-folding scale (weight 0.368 at T, not 0.5).
27. Controls are drawn with replacement (duplicates in small risk sets), undocumented;
    `n_controls = 1.5` and `n_events = 2.7` are truncated silently; clogit fits report `n = nrow(data)`
    including NA rows and have no `$rows`.

## D. Questions on intended behaviour

- **`scope = "citation"`** draws control receivers only from papers that have already cited
  something, so papers that are only ever cited are never controls, and every event at the first
  timestamp gets no control (`R/preprocess.R:1279–1284`). Intended?
- **Tied times without a mask**: events at one timestamp see each other in row order (A->B and B->A
  at t = 1 give reciprocity `0 1`); with a mask they give `0 0`. Which is the definition?
- Under `risk = "remove"` the new no-control warning fires on ordinary data (events 2–3 of
  `classroom_events`, whose pool is still tiny). Keep it, or exempt the first timestamps?
