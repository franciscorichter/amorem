# Fit a relational (hyper)event model on preprocessed case-control data

`rem()` is the unified front-end for fitting relational event models
from **already preprocessed** case-control data (e.g. produced by
`eventnet`), where the endogenous/exogenous covariates have already been
computed. It is intended to supersede
[`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md),
[`compare_models_smooth()`](https://franciscorichter.github.io/amorem/reference/compare_models_smooth.md)
and
[`compare_models_global()`](https://franciscorichter.github.io/amorem/reference/compare_models_global.md),
which couple feature computation and fitting.

## Usage

``` r
rem(
  formula,
  data,
  method = c("gam", "clogit", "nn"),
  case = NULL,
  stratum = NULL,
  time = NULL,
  k = NULL,
  bs = NULL,
  gam_method = NULL,
  nn = nn_control(),
  ...
)
```

## Arguments

- formula:

  A formula; see *Formula syntax*.

- data:

  A data.frame of preprocessed case-control data (wide for the `gam`
  method; long with a case indicator and stratum for `clogit`). For
  `method = "gam"`, long case-control input (a `event`/`IS_OBSERVED`
  indicator with control rows) is detected and widened automatically via
  [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md),
  with a message. The `gam` design pairs each case with one control, so
  widening keeps the first control of each stratum; when a stratum has
  several controls `rem()` warns, and `method = "clogit"` uses them all.

- method:

  Estimation backend; see *Description*.

- case:

  Optional name of the 0/1 event-indicator column for the `clogit` and
  `nn` backends. If `NULL` (default), the indicator is taken from the
  formula's left-hand side (e.g. `event ~ x`). Ignored by the `gam`
  method.

- stratum:

  Name of the column grouping each case with its controls, for `clogit`
  and `nn`. When `NULL`, a column named `stratum` (as written by
  [`sample_non_events()`](https://franciscorichter.github.io/amorem/reference/sample_non_events.md))
  is used if present; otherwise the strata are derived as
  `cumsum(case == 1)`.

- time:

  Name of the time column, required for `tv` / `tvnl` terms. A single
  column `time` gives the event and its control the same time. When it
  is absent and `time_ev` / `time_nv` are present (the wide form of
  time-shifted sampling,
  [`sample_non_events()`](https://franciscorichter.github.io/amorem/reference/sample_non_events.md)
  with `shift = "exponential"`), each row is evaluated at its own time:
  `tv(x)` contributes \\\beta(t)x\_{ev} - \beta(t^\*)x\_{nv}\\ and needs
  `x_ev` / `x_nv`.

- k:

  Optional basis dimension passed to every `s()` / `te()` smooth that
  does not set its own `k` (see *Formula syntax*).

- bs:

  Optional basis type (e.g. `"tp"`, `"cr"`, `"ps"`) passed to every
  `s()` / `te()` smooth that does not set its own `bs`.

- gam_method:

  Smoothness-selection method for the `gam` backend, passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). Defaults to
  `NULL`, which uses mgcv's own default (`"GCV.Cp"`) and reproduces the
  Intro-to-REM tutorial parameterization. Set to `"REML"` for the REML
  fit used in some papers.

- nn:

  An
  [`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md)
  object with the architecture and training hyper-parameters for
  `method = "nn"`. Ignored by the other backends.

- ...:

  Reserved for future use.

## Value

An object of class `"amorem_rem"`: a list with the fitted model
(`$fit`), the `method`, the original `formula`, the parsed `terms`, the
number of rows used by the fit `n` and, for `gam` and `clogit`, the
logical vector `rows` marking which rows of `data` (after widening, for
`gam`) the fit used. `clogit` and `nn` fits also store the resolved
event-indicator column `case` and the `stratum` argument. Has
[`summary()`](https://rdrr.io/r/base/summary.html),
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`plot()`](https://rdrr.io/r/graphics/plot.default.html),
[`logLik()`](https://rdrr.io/r/stats/logLik.html) and
[`predict()`](https://rdrr.io/r/stats/predict.html) methods. For `gam`
fits, `predict(fit, newdata)` takes wide data in the form `rem()`
accepts (the columns named in *Column resolution*) and returns the
linear predictor of each row, event minus control; further arguments go
to
[`mgcv::predict.gam()`](https://rdrr.io/pkg/mgcv/man/predict.gam.html).
For `clogit` and `nn` fits,
[`predict()`](https://rdrr.io/r/stats/predict.html) passes its arguments
to the fitted model's own method.

## Details

Two estimation backends are provided:

- `"gam"`:

  Degenerate logistic regression on a case-1-control design (Boschi,
  Lerner & Wit 2025): the response is a constant 1 and the linear
  predictor is built from event-minus-control differences. Supports
  smooth time-varying (`tv`), non-linear (`nl`) and time-varying
  non-linear (`tvnl`) effects via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html).

- `"clogit"`:

  Conditional logistic regression on a case-k-control design via
  [`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html)
  (linear terms only). The case/control strata are taken from `stratum`,
  or derived as `cumsum(case == 1)` when `stratum` is `NULL` (assuming
  each case is immediately followed by its controls, the eventnet
  blocked layout).

- `"nn"`:

  Flexible conditional-logistic models on the same case-k-control design
  as `clogit`, trained by (mini-batch) gradient descent on the exact
  risk-set softmax partial likelihood. Two architectures via
  [`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md):
  a multilayer perceptron scoring the full covariate vector jointly
  (interaction-capable), or an `additive_spline` predictor —
  per-covariate B-spline expansions fitted by stochastic gradient, the
  STREAM construction of Filippi-Mazzola & Wit (2024, JRSS-C). No
  coefficient table; [`summary()`](https://rdrr.io/r/base/summary.html)
  reports in-sample (and, with a validation split, held-out) concordance
  and `plot(type = "pdp")` shows per-feature curves. Trained by the
  built-in R engine, or by torch with `nn_control(engine = "torch")`.

## Formula syntax

The right-hand side lists covariates. A bare name is a **linear**
effect; wrap a name to request a smooth effect (`gam` method only):

- `tv(x)` — time-varying linear effect: `s(time, by = d_x)`.

- `nl(x)` — non-linear effect: `s(cbind(x_ev, x_nv), by = c(1, -1))`.

- `tvnl(x)` — time-varying non-linear effect (tensor product).

- `re(x)` — random effect of a grouping factor `x` (e.g. the sender),
  built from the matched `x_ev` / `x_nv` levels as
  `s(cbind(x_ev, x_nv), by = cbind(1, -1), bs = "re")`, contributing
  `f(event_level) - f(control_level)` (following the REM tutorial's
  species-invasiveness term). Needs both `x_ev` and `x_nv` (as written
  by
  [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md));
  a single column `x` is an error, since it gives the event and its
  control the same level and the term would be zero. Identified only
  when the event and control differ on `x`.

Smooth terms take the basis settings of
[`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html) /
[`mgcv::te()`](https://rdrr.io/pkg/mgcv/man/te.html) as named arguments
after the covariate, so each term can use its own basis dimension and
type: `tv(x, k = 20, bs = "cr") + nl(y, k = 5, bs = "ps")`. Any `s()` /
`te()` argument other than `by` is accepted (e.g. `m`, `fx`, `sp`,
`xt`); for `tvnl` a vector `k` or `bs` gives one value per margin, time
first (`tvnl(x, k = c(5, 8))`). Argument values are evaluated in the
formula's environment. A term without its own `k` / `bs` uses the global
`k` / `bs` arguments of `rem()`, and mgcv's defaults when those are
`NULL`. `re()` takes no further arguments (its basis is fixed to
`bs = "re"`).

For the `gam` method the left-hand side is ignored (the response is the
constant case indicator); for `clogit` the left-hand side names the 0/1
event indicator column (e.g. `event ~ x`), unless `case` is given
explicitly. The event indicator may be numeric or integer 0/1, logical,
or a character or factor column with values `"0"`/`"1"` or
`"FALSE"`/`"TRUE"`; it is read by value, and any other value is an
error.

[`offset()`](https://rdrr.io/r/stats/offset.html) terms enter the linear
predictor with coefficient 1. For `clogit` the expression is evaluated
on the rows of `data`, as in
[`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html).
For `gam` it must name a column, `offset(o)`, which is resolved like a
linear term (an event-minus-control difference: column `o`, else `d_o`,
else `o_ev - o_nv`). The `nn` method does not take offsets.

## Column resolution

For a covariate `x`, the event/control difference is taken from column
`x`, else `d_x`, else `x_ev - x_nv`. Non-linear terms use
`transform_x_ev` / `transform_x_nv` when present (the eventnet
spline-transformed covariate), otherwise `x_ev` / `x_nv`. `tvnl` uses
`transformed_time` when present. Undirected logs (senders only, no
receiver/`TARGET` column) are supported.

## Name clashes with other relational-event packages

The name `rem()` is used by three CRAN packages: this one, relevent (on
CRAN since 2010) and redeem (2026). Attaching more than one of them
masks the others, and R will say so at load time.

Fits from `amorem` have class `"amorem_rem"`, which the other two
packages do not use, so their S3 methods for class `"rem"` never apply
to them. When more than one of these packages is attached, call
`amorem::rem()` explicitly.

## See also

[`compare_models_smooth()`](https://franciscorichter.github.io/amorem/reference/compare_models_smooth.md)
(superseded),
[`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
(whose `wide = TRUE` output is a valid input here),
[`simulate_directed_hyperevents_tvnl()`](https://franciscorichter.github.io/amorem/reference/simulate_directed_hyperevents_tvnl.md).

## Examples

``` r
if (requireNamespace("mgcv", quietly = TRUE)) {
  set.seed(1)
  w <- simulate_relational_events(
    n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
    n_controls = 1, endogenous_stats = "reciprocity_count",
    endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
  fit <- rem(~ reciprocity_count, data = w, method = "gam")
  coef(fit)
  summary(predict(fit, w))
}
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#> -2.7131  0.9044  5.4262 20.4808 40.0180 74.1577 
```
