# Friendship-survey events for the Social Evolution study

Self-reported friendship ties recorded at survey waves throughout the
Social Evolution study.

## Usage

``` r
social_evolution_friendship
```

## Format

A data frame with 766 rows and 4 columns:

- time:

  Days since the first recorded call (same origin as
  [social_evolution_calls](https://franciscorichter.github.io/amorem/reference/social_evolution_calls.md)).
  `attr(., "unix_origin")` holds the Unix epoch of `time = 0`.

- sender:

  Character actor id (the survey respondent).

- receiver:

  Character actor id (the nominated friend).

- replace:

  Integer — `1` adds the tie, `0` removes it.

## Source

Madan et al. (2011), via `goldfish`.

## See also

[social_evolution_calls](https://franciscorichter.github.io/amorem/reference/social_evolution_calls.md),
[social_evolution_actors](https://franciscorichter.github.io/amorem/reference/social_evolution_actors.md)
