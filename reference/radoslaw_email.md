# Manufacturing-company email events (Michalski et al. 2014)

Time-stamped directed emails among the 167 employees of a mid-sized
manufacturing company in Poland, January to September 2010. Each
recipient of an email (To, CC or BCC) is a separate row. The data are
the CC0 release of Nurek & Michalski (2020);
[radoslaw_hierarchy](https://franciscorichter.github.io/amorem/reference/radoslaw_hierarchy.md)
gives who reports to whom.

## Usage

``` r
radoslaw_email
```

## Format

A data frame with 82,927 rows and 4 columns:

- time:

  Days since the first email. `attr(., "unix_origin")` holds the Unix
  time of `time = 0`; the release records local (Europe/Warsaw) time.

- sender:

  Character employee id, as in
  [radoslaw_hierarchy](https://franciscorichter.github.io/amorem/reference/radoslaw_hierarchy.md).

- receiver:

  Character employee id.

- weight:

  Integer, `1` for every record.

## Source

Nurek M, Michalski R (2020). Manufacturing company email metadata and
corporate hierarchy. Harvard Dataverse,
[doi:10.7910/DVN/6Z3CGX](https://doi.org/10.7910/DVN/6Z3CGX) , licence
CC0 1.0. Cite: Nurek M, Michalski R (2020). Combining machine learning
and social network analysis to reveal the organizational structures.
*Applied Sciences* 10(5), 1699,
[doi:10.3390/app10051699](https://doi.org/10.3390/app10051699) ; and
Michalski R, Palus S, Kazienko P (2011). Matching organizational
structure and social network extracted from email communication.
*Lecture Notes in Business Information Processing* 87, 197–206.

## Details

51 rows are emails an employee sent to themself.
