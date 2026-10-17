# Build catalogue profiles: Rscript data-raw/catalogue/build_profiles.R [id ...]
# Reads raw data from data-raw/raw/ and writes aggregates only to
# vignettes/articles/data/catalogue/<id>.rds.
suppressPackageStartupMessages(devtools::load_all("~/System/Research/REM", quiet = TRUE))
source("~/System/Research/REM/data-raw/catalogue/profile.R")
source("~/System/Research/REM/data-raw/catalogue/readers.R")
out <- path.expand("~/System/Research/REM/vignettes/articles/data/catalogue")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
ids <- commandArgs(TRUE)
if (!length(ids)) ids <- names(readers)
for (id in ids) {
  t0 <- Sys.time()
  res <- tryCatch({
    p <- profile(readers[[id]]())
    p$id <- id
    saveRDS(p, file.path(out, paste0(id, ".rds")), compress = "xz")
    sprintf("%-32s ok  %8s events  %5.1fs  fit: %s", id, format(p$stats[[1]], big.mark = ","),
            as.numeric(difftime(Sys.time(), t0, units = "secs")),
            if (is.data.frame(p$fit)) paste(sprintf("%s=%.2f", p$fit$term, p$fit$estimate), collapse = " ")
            else if (is.character(p$fit)) p$fit else "none")
  }, error = function(e) sprintf("%-32s FAIL %s", id, conditionMessage(e)))
  cat(res, "\n")
}
