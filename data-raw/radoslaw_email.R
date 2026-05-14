# data-raw/radoslaw_email.R
# Build the tidy `radoslaw_email` data object from the raw `.edges` file
# shipped under inst/extdata/radoslaw_email/ (source: Michalski, Palus,
# Kazienko 2014; obtained via Network Repository as `ia-radoslaw-email`).
#
# Raw format: one event per line, four whitespace-separated fields
#   <sender_id> <receiver_id> <weight> <unix_timestamp>
# Lines starting with `%` are header / comment.

lines <- readLines("inst/extdata/radoslaw_email/ia-radoslaw-email.edges")
lines <- lines[!grepl("^%", lines)]

fields <- strsplit(trimws(lines), "[[:space:]]+")
mat <- do.call(rbind, fields)
storage.mode(mat) <- "integer"  # all four fields are integers

radoslaw_email <- data.frame(
  time     = as.numeric(mat[, 4L]),  # Unix epoch seconds
  sender   = as.character(mat[, 1L]),
  receiver = as.character(mat[, 2L]),
  weight   = mat[, 3L],
  stringsAsFactors = FALSE
)
radoslaw_email <- radoslaw_email[order(radoslaw_email$time), ]
rownames(radoslaw_email) <- NULL

# Convert Unix epoch to days since the first event so the resulting `time`
# column is in the conventional REM time-unit (a small positive numeric).
# The original timestamps are preserved as an integer attribute.
attr(radoslaw_email, "unix_origin") <- min(radoslaw_email$time)
radoslaw_email$time <- (radoslaw_email$time - min(radoslaw_email$time)) / 86400

usethis::use_data(radoslaw_email, overwrite = TRUE, compress = "xz")
