# Build catalogue profiles: Rscript data-raw/catalogue/build_profiles.R [--views-only] [id ...]
# --views-only recomputes only the views (network, timeline, close-up, pairs) of existing profiles.
# Reads raw data from data-raw/raw/ and writes aggregates only to
# vignettes/articles/data/catalogue/<id>.rds.
suppressPackageStartupMessages(devtools::load_all("~/System/Research/REM", quiet = TRUE))
source("~/System/Research/REM/data-raw/catalogue/profile.R")
source("~/System/Research/REM/data-raw/catalogue/readers.R")
source("~/System/Research/REM/data-raw/catalogue/view.R")
# Readable labels for the actors of the view figures (the profiles keep the ids)
relabel <- list(
  "govinfo-billstatus-118" = function(id) {
    m <- amorem::congress_members_118
    lab <- sub(" \\[.*", "", sub("^(Rep|Sen)\\. ", "", m$name))
    lab <- paste0(sub(",.*", "", lab), " (", m$party, "-", m$state, ")")
    out <- lab[match(id, m$bioguide_id)]; ifelse(is.na(out), id, out) })
view_of <- function(id, obj) {
  f <- relabel[[id]]
  if (!is.null(f)) {
    if (obj$kind == "hyper") { obj$events$I <- lapply(obj$events$I, f); if (!is.null(obj$events$J)) obj$events$J <- lapply(obj$events$J, f) }
    else obj$events[c("sender", "receiver")] <- lapply(obj$events[c("sender", "receiver")], f)
  }
  switch(obj$kind, dyadic = view_dyadic(obj), hyper = view_hyper(obj), NULL)
}
out <- path.expand("~/System/Research/REM/vignettes/articles/data/catalogue")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
ids <- commandArgs(TRUE)
views_only <- "--views-only" %in% ids; ids <- setdiff(ids, "--views-only")
if (!length(ids)) ids <- names(readers)
if (views_only) ids <- ids[file.exists(file.path(out, paste0(ids, ".rds")))]
for (id in ids) {
  t0 <- Sys.time()
  res <- tryCatch({
    obj <- readers[[id]]()
    p <- if (views_only) readRDS(file.path(out, paste0(id, ".rds"))) else profile(obj)
    p$view <- view_of(id, obj)
    p$id <- id
    saveRDS(p, file.path(out, paste0(id, ".rds")), compress = "xz")
    sprintf("%-32s ok  %8s events  %5.1fs  fit: %s", id, format(p$stats[[1]], big.mark = ","),
            as.numeric(difftime(Sys.time(), t0, units = "secs")),
            if (is.data.frame(p$fit)) paste(sprintf("%s=%.2f", p$fit$term, p$fit$estimate), collapse = " ")
            else if (is.character(p$fit)) p$fit else "none")
  }, error = function(e) sprintf("%-32s FAIL %s", id, conditionMessage(e)))
  cat(res, "\n")
}
