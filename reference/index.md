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
- [`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md)
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
- [`nn_uncertainty()`](https://franciscorichter.github.io/amorem/reference/nn_uncertainty.md)
  : Bootstrap uncertainty for the neural rem() backend
- [`plot(`*`<nn_uncertainty>`*`)`](https://franciscorichter.github.io/amorem/reference/plot.nn_uncertainty.md)
  : Plot partial-dependence uncertainty bands
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
- [`gof_rem()`](https://franciscorichter.github.io/amorem/reference/gof_rem.md)
  : Goodness of fit for a fitted relational event model

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
- [`hyperedge_features()`](https://franciscorichter.github.io/amorem/reference/hyperedge_features.md)
  : Endogenous features for a hyperedge event log

## Data: event logs

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
- [`radoslaw_hierarchy`](https://franciscorichter.github.io/amorem/reference/radoslaw_hierarchy.md)
  : Reporting hierarchy of the manufacturing company (Nurek & Michalski
  2020)
- [`college_msg`](https://franciscorichter.github.io/amorem/reference/college_msg.md)
  : CollegeMsg: private messages on a university online community
- [`email_eu_core`](https://franciscorichter.github.io/amorem/reference/email_eu_core.md)
  : Email-Eu-Core temporal (single-department subset)
- [`copenhagen_calls`](https://franciscorichter.github.io/amorem/reference/copenhagen.md)
  [`copenhagen_sms`](https://franciscorichter.github.io/amorem/reference/copenhagen.md)
  [`copenhagen_actors`](https://franciscorichter.github.io/amorem/reference/copenhagen.md)
  : Copenhagen Networks Study: phone calls, text messages and gender
- [`us_leader_visits`](https://franciscorichter.github.io/amorem/reference/us_leader_visits.md)
  : US leader-to-leader visits, 1945–2019
- [`football_results`](https://franciscorichter.github.io/amorem/reference/football_results.md)
  : Men's international football results since 1872
- [`ucdp_dyads`](https://franciscorichter.github.io/amorem/reference/ucdp_dyads.md)
  : UCDP dyadic conflict data, 1946–2025
- [`alien_invasions`](https://franciscorichter.github.io/amorem/reference/alien_invasions.md)
  : Alien species first records, prepared for relational event models

## Data: hyperevents

- [`congress_bills_118`](https://franciscorichter.github.io/amorem/reference/congress_bills_118.md)
  : Bills of the 118th US Congress as hyperevents
- [`congress_members_118`](https://franciscorichter.github.io/amorem/reference/congress_members_118.md)
  : Members of the 118th US Congress

## Data: global covariates

- [`enso_nino34`](https://franciscorichter.github.io/amorem/reference/enso_nino34.md)
  : Reconstructed Niño3.4 ENSO index, 1301–2005 (Li et al. 2013)
- [`oni`](https://franciscorichter.github.io/amorem/reference/oni.md) :
  Oceanic Niño Index, 1950–present
- [`daily_weather`](https://franciscorichter.github.io/amorem/reference/daily_weather.md)
  : Daily weather at the places and periods of the bundled event logs
- [`public_holidays`](https://franciscorichter.github.io/amorem/reference/public_holidays.md)
  : Public holidays for the periods of the bundled event logs
- [`dist_matrix`](https://franciscorichter.github.io/amorem/reference/dist_matrix.md)
  : US state distance matrix
