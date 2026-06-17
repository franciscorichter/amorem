# Phone calls in the Social Evolution study (Madan et al. 2011)

Time-stamped directed phone calls among undergraduates in an MIT
residence hall over the 2008–2009 academic year. Sourced from the
`goldfish` R package (`Social_Evolution$calls`).

## Usage

``` r
social_evolution_calls
```

## Format

A data frame with 439 rows and 4 columns:

- time:

  Days since the first recorded call. `attr(., "unix_origin")` holds the
  Unix epoch of `time = 0`.

- sender:

  Character actor id matching
  [social_evolution_actors](https://franciscorichter.github.io/amorem/reference/social_evolution_actors.md)`$id`.

- receiver:

  Same domain as `sender`.

- increment:

  Integer increment recorded for the call (typically 1).

## Source

Madan, A., Cebrian, M., Moturu, S., Farrahi, K. (2011). Sensing the
"health state" of a community. *IEEE Pervasive Computing* 11(1), 36–45.
[doi:10.1109/MPRV.2011.79](https://doi.org/10.1109/MPRV.2011.79) .
Redistributed via the `goldfish` R package
(github.com/snlab-ch/goldfish), dataset `Social_Evolution`.

## See also

[social_evolution_actors](https://franciscorichter.github.io/amorem/reference/social_evolution_actors.md),
[social_evolution_friendship](https://franciscorichter.github.io/amorem/reference/social_evolution_friendship.md)
