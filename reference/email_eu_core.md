# Email-Eu-Core temporal (Department 3 subset)

Internal emails between members of a single department of a large
European research institution over ~803 days. The dataset has been
filtered to remove self-loops. Sourced from the SNAP repository as the
Department 3 slice of the email-Eu-core-temporal dataset.

## Usage

``` r
email_eu_core
```

## Format

A data frame with 12,216 rows and 3 columns:

- time:

  Days since the first email in the recording window.

- sender:

  Character employee id (anonymised).

- receiver:

  Character employee id (anonymised).

## Source

Paranjape, A., Benson, A.R., Leskovec, J. (2017). Motifs in temporal
networks. *WSDM '17*, 601–610.
[doi:10.1145/3018661.3018731](https://doi.org/10.1145/3018661.3018731) .
Distributed via SNAP:
<https://snap.stanford.edu/data/email-Eu-core-temporal.html>.
