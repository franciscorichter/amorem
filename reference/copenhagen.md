# Copenhagen Networks Study: phone calls, text messages and gender

Phone calls and text messages among students of the Technical University
of Denmark over four weeks, from the Copenhagen Networks Study
(Sapiezynski et al. 2019). `copenhagen_actors` records each
participant's gender.

## Usage

``` r
copenhagen_calls

copenhagen_sms

copenhagen_actors
```

## Format

`copenhagen_calls`: 3,600 rows, `time` (days since the start of the
study period), `sender` (caller), `receiver` (callee), `duration`
(seconds; `-1` for missed calls in the release). `copenhagen_sms`:
24,333 rows, `time`, `sender`, `receiver`. `copenhagen_actors`: 787
rows, `id`, `female` (1 = female).

An object of class `data.frame` with 3600 rows and 4 columns.

An object of class `data.frame` with 24333 rows and 3 columns.

An object of class `data.frame` with 787 rows and 2 columns.

## Source

Sapiezynski P, Stopczynski A, Lassen DD, Lehmann S (2019). Interaction
data from the Copenhagen Networks Study. *Scientific Data* 6, 315,
[doi:10.1038/s41597-019-0325-x](https://doi.org/10.1038/s41597-019-0325-x)
. Data: Figshare,
[doi:10.6084/m9.figshare.7267433](https://doi.org/10.6084/m9.figshare.7267433)
, MIT licence.
