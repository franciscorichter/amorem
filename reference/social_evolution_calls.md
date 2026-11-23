# Phone calls in the Social Evolution study (Madan et al. 2012)

Time-stamped directed phone calls among undergraduates in an MIT
residence hall from 6 September to 18 October 2008, the abbreviated
window of the Social Evolution study distributed by the `goldfish` R
package (`Social_Evolution$calls`).

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

Madan, A., Cebrian, M., Moturu, S., Farrahi, K., Pentland, A. (2012).
Sensing the "health state" of a community. *IEEE Pervasive Computing*
11(4), 36–45.
[doi:10.1109/MPRV.2011.79](https://doi.org/10.1109/MPRV.2011.79) .
Redistributed via the `goldfish` R package
(github.com/snlab-ch/goldfish), dataset `Social_Evolution`. Licence: no
licence is stated for the data; the `goldfish` package, which
distributes them, is licensed GPL (\>= 3). The original MIT Reality
Commons download
([http://realitycommons.media.mit.edu/socialevolution.html](http://realitycommons.media.mit.edu/socialevolution.md))
asks users not to distribute the data to others and not to attempt to
re-identify participants.

## See also

[social_evolution_actors](https://franciscorichter.github.io/amorem/reference/social_evolution_actors.md),
[social_evolution_friendship](https://franciscorichter.github.io/amorem/reference/social_evolution_friendship.md)
