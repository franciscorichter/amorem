# Package index

## Simulation helpers

- [`simulate_relational_events()`](https://franciscorichter.github.io/amore/reference/simulate_relational_events.md)
  : Simulate relational event sequences
- [`simulate_actor_covariates()`](https://franciscorichter.github.io/amore/reference/simulate_actor_covariates.md)
  : Simulate exogenous actor covariates
- [`simulate_hyperedge_events()`](https://franciscorichter.github.io/amore/reference/simulate_hyperedge_events.md)
  : Simulate undirected hyperedge events (multi-actor meetings)
- [`simulate_directed_hyperedge_events()`](https://franciscorichter.github.io/amore/reference/simulate_directed_hyperedge_events.md)
  : Simulate directed two-mode hyperedge events

## Preprocess module

- [`standardize_event_log()`](https://franciscorichter.github.io/amore/reference/standardize_event_log.md)
  : Standardize a relational event log
- [`attach_static_covariates()`](https://franciscorichter.github.io/amore/reference/attach_static_covariates.md)
  : Attach static covariates to an event log
- [`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md)
  : Compute endogenous event-network statistics
- [`sample_non_events()`](https://franciscorichter.github.io/amore/reference/sample_non_events.md)
  : Sample non-events for inference

## Model comparison

- [`compare_models()`](https://franciscorichter.github.io/amore/reference/compare_models.md)
  : Compare candidate endogenous specifications by AIC
- [`compare_models_smooth()`](https://franciscorichter.github.io/amore/reference/compare_models_smooth.md)
  : Compare candidate specifications with smooth (TVE / NLE / TVNLE)
  effects

## Hyperedge data model

- [`hyperedge_log()`](https://franciscorichter.github.io/amore/reference/hyperedge_log.md)
  [`is_hyperedge_log()`](https://franciscorichter.github.io/amore/reference/hyperedge_log.md)
  [`as_hyperedge_log()`](https://franciscorichter.github.io/amore/reference/hyperedge_log.md)
  [`as_dyadic_log()`](https://franciscorichter.github.io/amore/reference/hyperedge_log.md)
  : Build / detect / convert hyperedge event logs
- [`hyperedge_sizes()`](https://franciscorichter.github.io/amore/reference/hyperedge_sizes.md)
  : Cardinality columns for a hyperedge event log
- [`hyperedge_activity()`](https://franciscorichter.github.io/amore/reference/hyperedge_activity.md)
  : Activity counter for hyperedge subsets
- [`hyperedge_subrep()`](https://franciscorichter.github.io/amore/reference/hyperedge_subrep.md)
  : Subset repetition statistic for a hyperedge event log
- [`compute_hyperedge_features()`](https://franciscorichter.github.io/amore/reference/compute_hyperedge_features.md)
  : Endogenous features for a hyperedge event log

## Data

- [`dist_matrix`](https://franciscorichter.github.io/amore/reference/dist_matrix.md)
  : US state distance matrix
- [`classroom_events`](https://franciscorichter.github.io/amore/reference/classroom_events.md)
  : Classroom interaction events (McFarland 2001)
- [`classroom_actors`](https://franciscorichter.github.io/amore/reference/classroom_actors.md)
  : Classroom actor attributes (McFarland 2001)
- [`social_evolution_calls`](https://franciscorichter.github.io/amore/reference/social_evolution_calls.md)
  : Phone calls in the Social Evolution study (Madan et al. 2011)
- [`social_evolution_actors`](https://franciscorichter.github.io/amore/reference/social_evolution_actors.md)
  : Actor attributes for the Social Evolution study
- [`social_evolution_friendship`](https://franciscorichter.github.io/amore/reference/social_evolution_friendship.md)
  : Friendship-survey events for the Social Evolution study
- [`radoslaw_email`](https://franciscorichter.github.io/amore/reference/radoslaw_email.md)
  : Manufacturing-company email events (Michalski et al. 2014)
