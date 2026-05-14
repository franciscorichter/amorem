# Simulate relational event sequences

Generate a simple relational event log for a sender set and receiver set
using a softmax allocation rule over dyadic intensities. The process
follows the Gillespie algorithm, where the time between events is drawn
from an exponential distribution with rate equal to the sum of all
dyadic intensities.

## Usage

``` r
simulate_relational_events(
  n_events,
  senders,
  receivers,
  baseline_rate = 1,
  start_time = 0,
  horizon = Inf,
  contribution_logits = NULL,
  sender_covariates = NULL,
  sender_effects = NULL,
  receiver_covariates = NULL,
  receiver_effects = NULL,
  allow_loops = FALSE,
  n_controls = 0,
  endogenous_stats = NULL,
  endogenous_effects = NULL,
  global_covariates = NULL,
  global_effects = NULL,
  method = c("gillespie", "tau_leap"),
  tau = NULL,
  half_life = NULL,
  risk = c("standard", "remove")
)
```

## Arguments

- n_events:

  Number of events to generate.

- senders:

  Character vector listing the sender set \\\mathcal{S}\\.

- receivers:

  Character vector listing the receiver set \\\mathcal{R}\\.

- baseline_rate:

  Positive scalar. A constant baseline hazard multiplier applied to all
  dyads. Defaults to 1.

- start_time:

  Initial time stamp.

- horizon:

  Optional maximum horizon; simulation stops once the cumulative time
  would exceed this value.

- contribution_logits:

  Optional `length(senders) x length(receivers)` matrix of dyad-level
  contributions to the log-rate (i.e. the dyad-specific part of the
  linear predictor, distinct from the baseline hazard). Defaults to
  zeros.

- sender_covariates:

  Optional numeric data.frame/matrix with one row per sender.

- sender_effects:

  Optional numeric vector of coefficients for `sender_covariates`.
  Required when sender covariates are supplied.

- receiver_covariates:

  Optional numeric data.frame/matrix with one row per receiver.

- receiver_effects:

  Optional numeric vector of coefficients for `receiver_covariates`.
  Required when receiver covariates are supplied.

- allow_loops:

  Logical; whether sender and receiver can coincide.

- n_controls:

  Integer; number of non-events (controls) to sample uniformly at random
  for each realized event. If `n_controls > 0`, the function returns a
  case-control data frame suitable for conditional logistic regression /
  GAM modeling. Defaults to 0.

- endogenous_stats:

  Optional character vector of endogenous mechanisms to include in the
  rate. Each entry updates a state matrix after every event so the
  intensity of the next event depends on the realized history. Supported
  values:

  - `"reciprocity_count"` — number of past reverse-dyad events.

  - `"reciprocity_binary"` — 1 if the reverse dyad has fired at least
    once, 0 otherwise.

  - `"reciprocity_exp_decay"` — sum of past reverse-dyad events with
    exponential half-life decay (requires `half_life`).

  - `"recency"` — elapsed time on the same ordered dyad \\t -
    t\_{\text{last}}(s,r)\\, defaulting to \\t - \text{start\\time}\\
    for dyads that have never fired.

  - `"sender_outdegree"` — total number of events previously sent by
    \\s\\ (constant across receivers).

  - `"receiver_indegree"` — total number of events previously received
    by \\r\\ (constant across senders).

  - `"transitivity_count"` / `"transitivity_binary"` — number of
    intermediaries \\k\\ (or indicator that at least one exists) for
    which both \\(s,k)\\ and \\(k,r)\\ have fired.

  - `"cyclic_count"` / `"cyclic_binary"` — number of intermediaries
    \\k\\ (or indicator) for which both \\(r,k)\\ and \\(k,s)\\ have
    fired (cyclic two-path closing \\s \to r\\).

  - `"sending_balance_count"` / `"sending_balance_binary"` — number of
    shared targets \\k\\ (or indicator) where both \\(s,k)\\ and
    \\(r,k)\\ have fired.

  - `"receiving_balance_count"` / `"receiving_balance_binary"` — number
    of shared sources \\k\\ (or indicator) where both \\(k,s)\\ and
    \\(k,r)\\ have fired.

  Defaults to `NULL` for a memoryless process.

- endogenous_effects:

  Numeric vector of linear coefficients for `endogenous_stats`. May be
  named (names must match `endogenous_stats`) or unnamed (positionally
  matched). Required when `endogenous_stats` is supplied.

- global_covariates:

  Optional data.frame describing piecewise-constant global covariates:
  variables whose value at time \\t\\ is the same for every dyad (e.g.
  weekday/weekend, weather, policy regime). Must contain a numeric
  `time_start` column giving the start of each interval; rows are
  assumed sorted in time and the first `time_start` must be at or before
  `start_time`. Each additional numeric column is treated as a global
  covariate. Defaults to `NULL` (no global effects).

- global_effects:

  Numeric vector of linear coefficients for the global covariates. May
  be named (names must match the covariate columns in
  `global_covariates`) or unnamed (positionally matched). Required when
  `global_covariates` is supplied.

- method:

  Simulation algorithm. Either `"gillespie"` (the default, exact
  event-driven algorithm: draw inter-event waiting times one at a time)
  or `"tau_leap"` (approximate, time-driven algorithm: advance the clock
  in fixed `tau` increments and Poisson-sample event counts per dyad
  within each step).

- tau:

  Positive scalar; the step size for `method = "tau_leap"`. Required
  when method is `"tau_leap"` and ignored otherwise. Smaller values give
  better approximation but more iterations; as \\\tau \to 0\\ the
  tau-leap result converges in distribution to the exact Gillespie
  result.

- half_life:

  Positive scalar; the half-life \\T\\ (in time units) used by the
  `"reciprocity_exp_decay"` stat. A past reverse-dyad event at time
  \\t_k\\ contributes \\\exp(-(t - t_k)\\\log 2/T)\\ to the stat value
  at time \\t\\. Required when `"reciprocity_exp_decay"` is in
  `endogenous_stats`.

- risk:

  Risk-set rule. `"standard"` (the default) keeps every dyad eligible at
  every step. `"remove"` removes a dyad from the risk set as soon as it
  fires, which mimics one-shot processes such as species invasions or
  first-citation events.

## Value

If `n_controls = 0`, a data.frame with columns `sender`, `receiver` and
`time`. If `n_controls > 0`, it returns a long-format data.frame with
additional columns `stratum` (grouping an event with its controls) and
`event` (1 for the realized event, 0 for controls). When
`endogenous_stats` is supplied, one extra column per stat is appended
carrying the value each row's dyad had at its event time (immediately
before the event fired), so downstream conditional logistic / GAM
estimators can recover the effects. When `global_covariates` is
supplied, one column per covariate is appended carrying the value of
that covariate at each row's event time.

## Details

When `global_covariates` is supplied, the simulator uses a
boundary-aware Gillespie scheme: the total event rate is rescaled by
\\\exp(\sum_k \beta_k\\x_k(t))\\; whenever a sampled waiting time would
cross an interval boundary, the clock is advanced to the boundary
without recording an event, and the next waiting time is redrawn under
the new global multiplier. Global covariates do not change the per-dyad
selection probabilities (the multiplier cancels), only the waiting-time
distribution. When combined with `endogenous_stats`, the per-dyad rates
are recomputed at every step from the current endogenous state and then
rescaled by the global multiplier.

The `"tau_leap"` algorithm advances the clock by a user-chosen step
\\\tau\\ and draws, for every dyad, a
\\\mathrm{Poisson}(\lambda\_{sr}(t)\\\tau)\\ number of events using the
rates at the *start* of the step. Multiple events can fire in the same
step; they are placed at uniform times within \\\[t, t+\tau)\\ and
reported in time order, but they share the start-of-step endogenous
state and global multiplier. Endogenous state is updated once at the end
of the step using all events in that step. The tau-leap algorithm trades
exactness for predictable, vectorised work per step; it is most useful
for high-rate regimes or for problems where the per-event recomputation
in the Gillespie path is the bottleneck. Choose \\\tau\\ small enough
that (i) \\\lambda \tau \ll 1\\ on every active dyad and (ii) \\\tau\\
is smaller than the shortest interval in `global_covariates`
(within-step boundary crossings are not resolved; the start-of-step
global multiplier is used for the entire step).

## Examples

``` r
set.seed(1)
senders <- receivers <- LETTERS[1:3]
sender_cov <- data.frame(activity = c(0.5, -0.2, 1.1))
receiver_cov <- data.frame(popularity = c(0.1, 0.3, -0.4))
# Standard event simulation
events <- simulate_relational_events(
  n_events = 5,
  senders = senders,
  receivers = receivers,
  sender_covariates = sender_cov,
  sender_effects = 1,
  receiver_covariates = receiver_cov,
  receiver_effects = 2
)
events
#>   sender receiver       time
#> 1      C        B 0.05297251
#> 2      B        A 0.06319316
#> 3      B        A 0.20346636
#> 4      C        B 0.23405456
#> 5      C        B 0.37673663

# Case-control generation for partial likelihood inference
cc_events <- simulate_relational_events(
  n_events = 5,
  senders = senders,
  receivers = receivers,
  sender_covariates = sender_cov,
  sender_effects = 1,
  n_controls = 2
)
head(cc_events)
#>   stratum event sender receiver       time
#> 1       1     1      C        A 0.03418054
#> 2       1     0      B        C 0.03418054
#> 3       1     0      A        B 0.03418054
#> 4       2     1      B        C 0.07395278
#> 5       2     0      C        A 0.07395278
#> 6       2     0      A        B 0.07395278
```
