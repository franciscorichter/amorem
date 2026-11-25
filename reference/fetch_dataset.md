# Download an event log that amorem does not redistribute

Seven of the data sets used in the package articles and in the amorem
paper come from sources that state no licence for the data, so the
package does not ship them. `fetch_dataset()` downloads the file from
its original source, checks its MD5 sum, builds the same tidy table that
earlier versions bundled, caches it and returns it.

## Usage

``` r
fetch_dataset(
  name,
  cache_dir = tools::R_user_dir("amorem", "cache"),
  refresh = FALSE,
  quiet = TRUE
)
```

## Arguments

- name:

  One of `"classroom_events"`, `"classroom_actors"`,
  `"social_evolution_calls"`, `"social_evolution_actors"`,
  `"social_evolution_friendship"`, `"college_msg"`, `"email_eu_core"`.

- cache_dir:

  Folder for the downloaded file and the built table. The default,
  `tools::R_user_dir("amorem", "cache")`, keeps them between sessions;
  pass [`tempdir()`](https://rdrr.io/r/base/tempfile.html) to keep
  nothing.

- refresh:

  If `TRUE`, download and build again even when a cached copy exists.

- quiet:

  If `TRUE`, download without progress messages.

## Value

A data frame, the same object as the data set of that name in amorem
1.2.0.

## Data sets

- `classroom_events`, `classroom_actors`:

  691 directed interactions among 20 people in one US high-school class
  period on 16 October 1996 (McFarland 2001), and the actors' sex and
  role. Columns of the events: `time` (minutes since the start of the
  period), `sender`, `receiver`, `interaction_type` (factor: social,
  sanction, task) and `weight` (1 for communication directed at
  particular others, 501 rows; 0.2 for broadcast communication such as
  lecturing, 190 rows). Rows are in time order, ties by sender and then
  receiver. Columns of the actors: `id`, `sex` (F, M), `role`
  (instructor, grade_11, grade_12). Source: McFarland, D. (2001).
  Student resistance: How the formal and informal organization of
  classrooms facilitate everyday forms of student defiance. *American
  Journal of Sociology* 107(3), 612–678,
  [doi:10.1086/338779](https://doi.org/10.1086/338779) ; downloaded from
  the networkDynamic repository
  (<https://github.com/statnet/networkDynamic>, object
  `McFarland_cls33_10_16_96`). No licence is stated for the data.

- `social_evolution_calls`, `social_evolution_actors`,
  `social_evolution_friendship`:

  439 phone calls among 84 undergraduates of an MIT residence hall, 6
  September to 18 October 2008, with the actors' attributes (`id`,
  `present`, `floor`, `gradeType`) and 766 friendship survey events
  (`replace` is 1 when a tie is added, 0 when it is removed). `time` is
  in days since the first call; `attr(., "unix_origin")` holds the Unix
  time of `time = 0`. Source: Madan, A., Cebrian, M., Moturu, S.,
  Farrahi, K., Pentland, A. (2012). Sensing the "health state" of a
  community. *IEEE Pervasive Computing* 11(4), 36–45,
  [doi:10.1109/MPRV.2011.79](https://doi.org/10.1109/MPRV.2011.79) ;
  downloaded from the goldfish repository
  (<https://github.com/stocnet/goldfish>, object `Social_Evolution`). No
  licence is stated for the data, and the original MIT Reality Commons
  release asks users not to redistribute them and not to attempt to
  re-identify participants.

- `college_msg`:

  59,835 private messages between students of the University of
  California, Irvine over 193 days in 2004. `time` is in days since the
  first message; `attr(., "unix_origin")` holds its date-time. Source:
  Panzarasa, P., Opsahl, T., Carley, K. (2009). Patterns and dynamics of
  users' behavior and interaction: Network analysis of an online
  community. *Journal of the American Society for Information Science
  and Technology* 60(5), 911–932; downloaded from SNAP,
  <https://snap.stanford.edu/data/CollegeMsg.html>. No licence is
  stated; SNAP asks users to cite the source.

- `email_eu_core`:

  12,216 e-mails between the members of one department of a European
  research institution over 803 days, self-addressed e-mails removed.
  `time` is in days. Source: Paranjape, A., Benson, A. R., Leskovec, J.
  (2017). Motifs in temporal networks. *WSDM '17*, 601–610,
  [doi:10.1145/3018661.3018731](https://doi.org/10.1145/3018661.3018731)
  ; downloaded from SNAP, file `email-Eu-core-temporal-Dept3.txt.gz` of
  <https://snap.stanford.edu/data/email-Eu-core-temporal.html>. No
  licence is stated; SNAP asks users to cite the source.

## Examples

``` r
# \donttest{
# needs an internet connection the first time
ev <- tryCatch(fetch_dataset("classroom_events", cache_dir = tempdir()),
               error = function(e) NULL)
if (!is.null(ev)) head(ev)
#>    time sender receiver interaction_type weight
#> 1 0.125     14       12           social      1
#> 2 0.250     12       14           social      1
#> 3 0.375     18       12         sanction      1
#> 4 0.500     12       18         sanction      1
#> 5 0.625      1       12         sanction      1
#> 6 0.750     12        1         sanction      1
# }
```
