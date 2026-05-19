# CollegeMsg: private messages on a university online community

Directed time-stamped instant messages between students of the
University of California, Irvine over 193 days in 2004. Each row is one
message. Sourced from the SNAP repository.

## Usage

``` r
college_msg
```

## Format

A data frame with 59,835 rows and 3 columns:

- time:

  Days since the first message. `attr(., "unix_origin")` holds the Unix
  epoch of `time = 0`.

- sender:

  Character user id.

- receiver:

  Character user id.

## Source

Panzarasa, P., Opsahl, T., Carley, K. (2009). Patterns and dynamics of
users' behavior and interaction: Network analysis of an online
community. *Journal of the American Society for Information Science and
Technology* 60(5), 911–932. Distributed via SNAP:
<https://snap.stanford.edu/data/CollegeMsg.html>.
