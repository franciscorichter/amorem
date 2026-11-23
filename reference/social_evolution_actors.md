# Actor attributes for the Social Evolution study

Per-actor covariates for
[social_evolution_calls](https://franciscorichter.github.io/amorem/reference/social_evolution_calls.md)
and
[social_evolution_friendship](https://franciscorichter.github.io/amorem/reference/social_evolution_friendship.md).

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

  Factor with levels `"1"` to `"5"`: the grade-type codes as distributed
  by `goldfish`, which does not label them.

## Source

Madan et al. (2012), via `goldfish`. Licence and terms as for
[social_evolution_calls](https://franciscorichter.github.io/amorem/reference/social_evolution_calls.md).
