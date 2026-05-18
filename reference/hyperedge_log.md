# Build / detect / convert hyperedge event logs

A *hyperedge log* generalises the dyadic `(sender, receiver, time)`
event log used elsewhere in `amore` to a `(I, J, time)` event log where
`I` and `J` are list-columns containing the set of senders and the set
of receivers participating in each hyperevent. This matches the data
model of Boschi, Lerner & Wit (2025): each event is a time-stamped
directed hyperedge \\(t_m, I_m, J_m)\\ from a sender set to a receiver
set.

## Usage

``` r
hyperedge_log(I, J, time)

is_hyperedge_log(x)

as_hyperedge_log(event_log)

as_dyadic_log(hyperedge_log)
```

## Arguments

- I:

  List-column: each element is a character vector of sender actor names
  participating in that event. Length-1 vectors are allowed (and become
  standard dyadic events when combined with a length-1 `J`).

- J:

  List-column: each element is a character vector of receiver actor
  names. Empty character vectors are allowed and signal an *undirected*
  hyperevent.

- time:

  Numeric vector of event times. Must be finite and non-decreasing after
  sorting.

- x:

  A data frame or list-of-columns to test or convert.

- event_log:

  A dyadic event log with `sender`, `receiver`, `time` columns.

- hyperedge_log:

  A hyperedge log produced by `hyperedge_log()` or `as_hyperedge_log()`.

## Value

A `data.frame` with columns `I`, `J`, `time`, additionally carrying
class `amore_hyperedge_log` to distinguish it from a dyadic log in
dispatch contexts. Sorted by `time` ascending.

## Details

The constructor `hyperedge_log()` accepts list-columns directly and
performs validation (character members, non-empty sets, finite times,
sorted by time). `as_hyperedge_log()` promotes a dyadic
`(sender, receiver, time)` data frame to the hyperedge form by wrapping
each `sender` and `receiver` in a length-1 character vector.
`as_dyadic_log()` is the inverse: it succeeds only when every row of the
hyperedge log has a length-1 sender set AND a length-1 receiver set.

For *undirected* hyperevents (e.g.\\ multi-actor meetings), pass an
empty receiver set: `J = list(character(0), character(0), ...)`. The
receiver list-column must still be present.

## References

Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
Time-Homogeneity: Relational Hyper Event Models with Time-Varying
Non-Linear Effects*. arXiv:2509.05289.

## Examples

``` r
# Two co-authored citation events:
hl <- hyperedge_log(
  I    = list(c("alice", "bob"), c("alice", "carol")),
  J    = list(c("paperA"), c("paperA", "paperB")),
  time = c(1.0, 2.5))
is_hyperedge_log(hl)
#> [1] TRUE

# Round-trip a dyadic log:
dy <- data.frame(sender = c("a", "b"),
                 receiver = c("b", "c"),
                 time = c(1, 2))
h <- as_hyperedge_log(dy)
as_dyadic_log(h)
#>   sender receiver time
#> 1      a        b    1
#> 2      b        c    2
```
