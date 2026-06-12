# Cardinality columns for a hyperedge event log

Adds two integer columns to a hyperedge log: `size_I` (the number of
senders) and `size_J` (the number of receivers). Convenient shortcut for
filtering / case-control sampling matched on cardinality (see Boschi et
al. 2025, Section 3.3).

## Usage

``` r
hyperedge_sizes(hyperedge_log)
```

## Arguments

- hyperedge_log:

  A hyperedge log.

## Value

The hyperedge log with two added integer columns.
