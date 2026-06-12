# Manufacturing-company email events (Michalski et al. 2014)

Time-stamped directed emails among employees of a mid-sized
manufacturing company over a nine-month period. Sourced from Network
Repository as the `ia-radoslaw-email` dataset.

## Usage

``` r
radoslaw_email
```

## Format

A data frame with 82,927 rows and 4 columns:

- time:

  Days since the first email. `attr(., "unix_origin")` holds the Unix
  epoch of `time = 0`.

- sender:

  Character employee id.

- receiver:

  Character employee id.

- weight:

  Integer — `1` for every record in the original file.

## Source

Michalski, R., Palus, S., Kazienko, P. (2014). Seed selection for spread
of influence in social networks: Temporal vs. static approach. *New
Generation Computing* 32(3–4), 213–235.
[doi:10.1007/s00354-014-0402-9](https://doi.org/10.1007/s00354-014-0402-9)
. Distributed via <https://networkrepository.com/ia-radoslaw-email.php>.
