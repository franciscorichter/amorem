# Simulate directed hyper-events with time-varying and non-linear effects

A teaching-oriented simulator for **directed relational hyper-events**
in which the sender set and the receiver set are disjoint, driven by
exogenous group covariates with a **time-varying** effect on the sender
side and a **non-linear** effect on the receiver side. It is the
packaged, parameterised form of the workshop running example
(`sunbelt-workshop-materials/running_example.R`) and produces a
ready-to-fit case-control dataset for GAM-based estimation of smooth
(TVE / NLE) effects.

## Usage

``` r
simulate_directed_hyperevents_tvnl(
  sender_attr,
  receiver_attr,
  time_varying_effect = function(t) sin(2 * t),
  nonlinear_effect = function(x) -4 + 2 * exp(-((x - 3)^2)/(2 * 2^2)),
  horizon = 2,
  dt = 0.01,
  n_controls = 1L,
  max_group_size_sender = length(sender_attr),
  max_group_size_receiver = length(receiver_attr)
)
```

## Arguments

- sender_attr:

  Named numeric vector of sender actor attributes (names are the sender
  ids).

- receiver_attr:

  Named numeric vector of receiver actor attributes.

- time_varying_effect:

  Function of one argument giving the time-varying coefficient
  \\\alpha(t)\\ multiplying the sender-group covariate. Defaults to
  `function(t) sin(2 * t)`.

- nonlinear_effect:

  Function of one argument giving the non-linear effect \\f(x)\\ of the
  receiver-group covariate. Defaults to a Gaussian bump.

- horizon:

  Positive numeric; the simulation end time (start is 0).

- dt:

  Positive numeric; the time-grid step used by the thinning scheme (must
  be smaller than `horizon`).

- n_controls:

  Non-negative integer; number of non-event pairs sampled per event.
  Defaults to 1 (a case-1-control design).

- max_group_size_sender, max_group_size_receiver:

  Integers; the largest subset size considered when enumerating sender /
  receiver groups. Default to the full actor sets (all non-empty
  subsets). Use 1 for ordinary dyadic events.

## Value

A long-format data.frame, one row per (event or control), with columns
`event_id` (links a case to its controls), `event_time`, `event` (1 =
realised event, 0 = sampled non-event), `sender_group`, `receiver_group`
(group labels), and `cov_sender`, `cov_receiver` (group covariates). The
true data-generating effect functions are attached as `attr(x, "truth")`
(a list with `time_varying_effect`, `nonlinear_effect`, and `horizon`)
for comparison against fitted smooths.

## Details

Each sender (resp. receiver) *group* is a non-empty subset of the sender
(resp. receiver) actors – a hyperedge endpoint. A group's covariate is
the mean of its members' actor attributes. For an ordered group pair
\\(g_s, g_r)\\ the instantaneous rate at time \\t\\ is
\$\$\lambda\_{g_s, g_r}(t) = \exp\bigl(\alpha(t)\\ x\_{g_s} +
f(x\_{g_r})\bigr),\$\$ where \\\alpha(t)\\ is the time-varying sender
effect (`time_varying_effect`), \\f(\cdot)\\ is the non-linear receiver
effect (`nonlinear_effect`), and \\x\\ denotes a group covariate. Events
are drawn on a fixed time grid of width `dt` by a thinning scheme:
within each step the next inter-event time is sampled from an
exponential with the total rate evaluated at the step midpoint, and the
firing pair is chosen with probability proportional to its rate. For
every realised event, `n_controls` non-event pairs are sampled uniformly
from the remaining group pairs, yielding a case-`n_controls`-control
design.

Setting `max_group_size_sender = 1` and `max_group_size_receiver = 1`
reduces the groups to single actors, i.e. ordinary directed dyadic
events.

## Examples

``` r
set.seed(1234)
sa <- setNames(rnorm(4, 5, 1.5), paste0("S", 1:4))
ra <- setNames(rnorm(4, 3, 2.0), paste0("R", 1:4))
d  <- simulate_directed_hyperevents_tvnl(sa, ra, horizon = 2, n_controls = 1)
head(d)
#>   event_id event_time event sender_group receiver_group cov_sender cov_receiver
#> 1        1 0.07060644     1      {S3,S4}        {R1,R4}   4.054058     2.882493
#> 2        1 0.07060644     0   {S2,S3,S4}  {R1,R2,R3,R4}   4.508086     2.906904
#> 3        2 0.08909327     1   {S1,S2,S3}        {R2,R3}   5.077402     2.931316
#> 4        2 0.08909327     0      {S1,S3}        {R1,R2}   4.908032     3.935181
#> 5        3 0.10357580     1      {S1,S3}     {R2,R3,R4}   4.908032     2.589789
#> 6        3 0.10357580     0   {S1,S2,S3}        {R2,R4}   5.077402     2.959424
table(d$event)
#> 
#>    0    1 
#> 2124 2124 
```
