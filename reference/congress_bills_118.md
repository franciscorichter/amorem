# Bills of the 118th US Congress as hyperevents

Every House and Senate bill introduced in the 118th Congress (January
2023 to January 2025) as a directed hyperevent: the sponsor sends the
bill, the cosponsors receive it. An
[`hyperedge_log()`](https://franciscorichter.github.io/amorem/reference/hyperedge_log.md)
with the bill number and the introduction date;
[congress_members_118](https://franciscorichter.github.io/amorem/reference/congress_members_118.md)
gives party and state.

## Usage

``` r
congress_bills_118
```

## Format

An `amorem_hyperedge_log` with 16,213 rows: `I` (list of one sponsor
bioguide id), `J` (list of cosponsor bioguide ids, possibly empty),
`time` (days since 3 January 2023), `bill` (e.g. `"hr184"`), `date`
(introduced).

## Source

US Government Publishing Office, BILLSTATUS bulk data for the 118th
Congress, <https://www.govinfo.gov/bulkdata/BILLSTATUS>, accessed
2026-10-17. A work of the US Government, public domain (17 U.S.C. 105).
