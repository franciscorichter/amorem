# Actor attributes for the Social Evolution study

Per-actor covariates for
[social_evolution_calls](https://franciscorichter.github.io/amore/reference/social_evolution_calls.md)
and
[social_evolution_friendship](https://franciscorichter.github.io/amore/reference/social_evolution_friendship.md).

## Usage

``` r
social_evolution_actors
```

## Format

A data frame with 84 rows and 4 columns:

- id:

  Character actor id (`"Actor 1"`, `"Actor 2"`, …).

- present:

  Logical — whether the actor was present at the start of the study
  window.

- floor:

  Integer dormitory floor.

- gradeType:

  Factor — student grade type (freshman, sophomore, junior, senior,
  graduate-tutor).

## Source

Madan et al. (2011), via `goldfish`. See
[social_evolution_calls](https://franciscorichter.github.io/amore/reference/social_evolution_calls.md).
