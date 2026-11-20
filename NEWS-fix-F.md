## Changes in behaviour

* `rem(method = "gam")` warns when long input with more than one control per
  stratum is widened, since the gam design keeps the first control of each
  stratum, and points to `method = "clogit"`, which uses every control. It
  only said that it widened the data.

* `rem()` stops when `re(x)` has no `x_ev` / `x_nv` columns. With a single
  column `x` the term gives the event and its control the same level and is
  zero; the documented fallback to that column is removed.

## Bug fixes

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

## Documentation

* `gof_multivariate()`, `gof_global()`, `gof_auxiliary()`, `nn_control()`
  and `nn_uncertainty()` have runnable examples. The `rem()` and `gof_rem()`
  examples run only when mgcv is installed.

* The `rem()` return value lists `rows`, `case`, `stratum` and the
  `predict()` method.
