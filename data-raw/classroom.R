# data-raw/classroom.R
# Build the tidy `classroom_events` and `classroom_actors` data objects from
# the raw TSVs shipped under inst/extdata/classroom/ (originally from the
# networkDynamic R package, dataset McFarland_cls33_10_16_96; source:
# McFarland 2001, AJS 107(3)).

raw_edges <- read.delim(
  "inst/extdata/classroom/cls33_10_16_96_edges.tsv",
  stringsAsFactors = FALSE
)
raw_vert <- read.delim(
  "inst/extdata/classroom/cls33_10_16_96_vertices.tsv",
  stringsAsFactors = FALSE
)

classroom_actors <- data.frame(
  id   = as.character(raw_vert$vertex_id),
  sex  = factor(raw_vert$sex, levels = c("F", "M")),
  role = factor(raw_vert$role,
                levels = c("instructor", "grade_11", "grade_12")),
  stringsAsFactors = FALSE
)

# The raw TSV has one row per directed interaction with start_minute and
# end_minute (effectively the timestamp; they coincide on most rows).
# `time` is taken as start_minute (minutes since the start of the
# class period); ties are broken by row order.
classroom_events <- data.frame(
  time             = raw_edges$start_minute,
  sender           = as.character(raw_edges$from_vertex_id),
  receiver         = as.character(raw_edges$to_vertex_id),
  interaction_type = factor(raw_edges$interaction_type,
                            levels = c("social", "sanction", "task")),
  weight           = raw_edges$weight,
  stringsAsFactors = FALSE
)
classroom_events <- classroom_events[order(classroom_events$time), ]
rownames(classroom_events) <- NULL

usethis::use_data(classroom_events, classroom_actors,
                  overwrite = TRUE, compress = "xz")
