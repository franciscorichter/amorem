# Package index

## Simulation helpers

- [`simulate_relational_events()`](https://franciscorichter.github.io/amorem/reference/simulate_relational_events.md)
  : Simulate relational event sequences
- [`simulate_actor_covariates()`](https://franciscorichter.github.io/amorem/reference/simulate_actor_covariates.md)
  : Simulate exogenous actor covariates
- [`simulate_hyperedge_events()`](https://franciscorichter.github.io/amorem/reference/simulate_hyperedge_events.md)
  : Simulate undirected hyperedge events (multi-actor meetings)
- [`simulate_directed_hyperedge_events()`](https://franciscorichter.github.io/amorem/reference/simulate_directed_hyperedge_events.md)
  : Simulate directed two-mode hyperedge events
- [`simulate_directed_hyperevents_tvnl()`](https://franciscorichter.github.io/amorem/reference/simulate_directed_hyperevents_tvnl.md)
  : Simulate directed hyper-events with time-varying and non-linear
  effects

## Preprocess module

- [`standardize_event_log()`](https://franciscorichter.github.io/amorem/reference/standardize_event_log.md)
  : Standardize a relational event log
- [`attach_static_covariates()`](https://franciscorichter.github.io/amorem/reference/attach_static_covariates.md)
  : Attach static covariates to an event log
- [`compute_endogenous_features()`](https://franciscorichter.github.io/amorem/reference/compute_endogenous_features.md)
  : Compute endogenous event-network statistics
- [`cpp_supported_stats`](https://franciscorichter.github.io/amorem/reference/cpp_supported_stats.md)
  : Endogenous statistics with a compiled fast path
- [`sample_non_events()`](https://franciscorichter.github.io/amorem/reference/sample_non_events.md)
  : Sample non-events for inference
- [`widen_case_control()`](https://franciscorichter.github.io/amorem/reference/widen_case_control.md)
  : Convert a long case-control event log to wide case-1-control format
- [`transform_recency()`](https://franciscorichter.github.io/amorem/reference/transform_recency.md)
  : Recency transform of inter-event time gaps

## Model fitting and comparison

- [`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
  : Fit a relational (hyper)event model on preprocessed case-control
  data
- [`nn_control()`](https://franciscorichter.github.io/amorem/reference/nn_control.md)
  : Control parameters for the neural-network backend of rem()
- [`compare_models()`](https://franciscorichter.github.io/amorem/reference/compare_models.md)
  : Compare candidate endogenous specifications by AIC
- [`compare_models_smooth()`](https://franciscorichter.github.io/amorem/reference/compare_models_smooth.md)
  : Compare candidate specifications with smooth (TV / NL / TVNL)
  effects
- [`compare_models_global()`](https://franciscorichter.github.io/amorem/reference/compare_models_global.md)
  : Compare REM specifications with global covariate effects

## Diagnostics

- [`martingale_residuals()`](https://franciscorichter.github.io/amorem/reference/martingale_residuals.md)
  : Martingale residuals from a case-control partial-likelihood fit
- [`gof_univariate()`](https://franciscorichter.github.io/amorem/reference/gof_univariate.md)
  : Goodness-of-fit test for a single FLE covariate
- [`gof_multivariate()`](https://franciscorichter.github.io/amorem/reference/gof_multivariate.md)
  : Multivariate GOF test for smooth or random-effect covariates
- [`gof_global()`](https://franciscorichter.github.io/amorem/reference/gof_global.md)
  : Omnibus GOF test via Cauchy combination
- [`gof_auxiliary()`](https://franciscorichter.github.io/amorem/reference/gof_auxiliary.md)
  : GOF test for an auxiliary (unmodelled) statistic

## Hyperedge data model

- [`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)
  [`is_hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)
  [`as_hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)
  [`as_dyadic_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)
  : Build / detect / convert hyperedge event logs
- [`hyperedge_sizes()`](https://franciscorichter.github.io/amorem/reference/hyperedge_sizes.md)
  : Cardinality columns for a hyperedge event log
- [`hyperedge_activity()`](https://franciscorichter.github.io/amorem/reference/hyperedge_activity.md)
  : Activity counter for hyperedge subsets
- [`hyperedge_subrep()`](https://franciscorichter.github.io/amorem/reference/hyperedge_subrep.md)
  : Subset repetition statistic for a hyperedge event log
- [`compute_hyperedge_features()`](https://franciscorichter.github.io/amorem/reference/compute_hyperedge_features.md)
  : Endogenous features for a hyperedge event log

## Data

- [`dist_matrix`](https://franciscorichter.github.io/amorem/reference/dist_matrix.md)
  : US state distance matrix
- [`classroom_events`](https://franciscorichter.github.io/amorem/reference/classroom_events.md)
  : Classroom interaction events (McFarland 2001)
- [`classroom_actors`](https://franciscorichter.github.io/amorem/reference/classroom_actors.md)
  : Classroom actor attributes (McFarland 2001)
- [`social_evolution_calls`](https://franciscorichter.github.io/amorem/reference/social_evolution_calls.md)
  : Phone calls in the Social Evolution study (Madan et al. 2011)
- [`social_evolution_actors`](https://franciscorichter.github.io/amorem/reference/social_evolution_actors.md)
  : Actor attributes for the Social Evolution study
- [`social_evolution_friendship`](https://franciscorichter.github.io/amorem/reference/social_evolution_friendship.md)
  : Friendship-survey events for the Social Evolution study
- [`radoslaw_email`](https://franciscorichter.github.io/amorem/reference/radoslaw_email.md)
  : Manufacturing-company email events (Michalski et al. 2014)
- [`college_msg`](https://franciscorichter.github.io/amorem/reference/college_msg.md)
  : CollegeMsg: private messages on a university online community
- [`email_eu_core`](https://franciscorichter.github.io/amorem/reference/email_eu_core.md)
  : Email-Eu-Core temporal (single-department subset)
