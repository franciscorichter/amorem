# Endogenous mechanisms and time-varying global covariates

``` r

library(amorem)
```

Beyond static dyadic covariates, the rate at which relational events
fire typically depends on *what has already happened* (endogenous
mechanisms such as reciprocity) and on *when in time* the process is
observed (time-varying global factors such as weekday/weekend).
[`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
exposes both through the `endogenous_stats` / `endogenous_effects` and
`global_covariates` / `global_effects` argument families. This vignette
walks through a minimal example for each, then shows how they compose.

## Endogenous reciprocity

`reciprocity_count` is a built-in endogenous statistic: the value of the
statistic at candidate dyad `(s, r)` is the number of past events
`(r, s)`. A positive coefficient means an event raises the future rate
of its reverse dyad.

``` r

set.seed(2024)
actors <- as.character(1:10)
true_beta <- 0.6

cc <- simulate_relational_events(
  n_events = 1200,
  senders = actors,
  receivers = actors,
  baseline_rate = 1,
  allow_loops = FALSE,
  n_controls = 1,
  endogenous_stats = "reciprocity_count",
  endogenous_effects = true_beta
)
head(cc)
#>   stratum event sender receiver        time reciprocity_count
#> 1       1     1     10        3 0.007487612                 0
#> 2       1     0      1        6 0.007487612                 0
#> 3       2     1      2        5 0.011851596                 0
#> 4       2     0      9        2 0.011851596                 0
#> 5       3     1      8        3 0.026647847                 0
#> 6       3     0      3        4 0.026647847                 0
```

Recover the coefficient with a one-parameter conditional logit fit on
the within-stratum statistic difference:

``` r

library(mgcv)
cases    <- cc[cc$event == 1L, ]
controls <- cc[cc$event == 0L, ]
cases    <- cases[order(cases$stratum), ]
controls <- controls[order(controls$stratum), ]
fit_df <- data.frame(
  one     = 1,
  delta_r = cases$reciprocity_count - controls$reciprocity_count
)
fit <- gam(one ~ delta_r - 1, family = "binomial", data = fit_df)
unname(coef(fit)[1])
#> [1] 0.4563272
```

The estimate sits in the same ballpark as the simulated
`true_beta = 0.6`.

## Time-varying global covariates

`global_covariates` is a data.frame with a strictly increasing
`time_start` column and one numeric column per global covariate. Between
two breaks the covariate value is constant. Internally,
[`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
uses a boundary-aware Gillespie scheme that redraws the next waiting
time whenever the proposed event would jump into the next interval.

``` r

set.seed(2024)
gc <- data.frame(
  time_start = seq(0, 10, by = 1),
  weekday    = rep(c(0, 1), length.out = 11)
)
ev <- simulate_relational_events(
  n_events = 200,
  senders = letters[1:5],
  receivers = letters[1:5],
  baseline_rate = 0.3,
  horizon = 11,
  global_covariates = gc,
  global_effects = c(weekday = 3)
)

share_weekday <- mean(ev$weekday == 1)
share_weekday
#> [1] 0.93
```

With `exp(3) ~= 20` weekday-to-weekend rate ratio, the bulk of realised
events falls in `weekday == 1` intervals.

## Composing endogenous and global

The two features can be active at the same time. The per-step total
weight is recomputed from the current endogenous state and then rescaled
by the global multiplier. The output frame carries one column per
endogenous statistic and one column per global covariate.

``` r

set.seed(7)
actors <- letters[1:5]
gc <- data.frame(time_start = c(0, 2, 4, 6), weekday = c(1, 0, 1, 0))

ev <- simulate_relational_events(
  n_events = 60,
  senders = actors,
  receivers = actors,
  baseline_rate = 1,
  horizon = 7,
  endogenous_stats = "reciprocity_count",
  endogenous_effects = c(reciprocity_count = 0.4),
  global_covariates = gc,
  global_effects = c(weekday = 1.5)
)
head(ev)
#>   sender receiver         time reciprocity_count weekday
#> 1      d        e 0.0005393737                 0       1
#> 2      c        b 0.0068986251                 0       1
#> 3      e        a 0.0081210792                 0       1
#> 4      a        e 0.0137901110                 1       1
#> 5      a        e 0.0214270093                 1       1
#> 6      b        a 0.0234383656                 0       1
```

Both the `reciprocity_count` column (endogenous state at event time) and
the `weekday` column (global covariate at event time) appear in the
output, ready for downstream conditional-logit or partial-likelihood
inference.

## Caveat

The current endogenous-state implementation maintains a single
`(senders × receivers)` reciprocity matrix and requires `senders` and
`receivers` to be the same character vector in the same order (a
one-mode network). Passing different sender/receiver sets while using
`endogenous_stats` will throw a clear error. Bipartite/two-mode support
is on the roadmap.
