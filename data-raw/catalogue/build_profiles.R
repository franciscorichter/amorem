# Build catalogue profiles: Rscript data-raw/catalogue/build_profiles.R [--views-only] [id ...]
# --views-only recomputes only the views (network, timeline, close-up, pairs) and animation frames of
# existing profiles; --frames-only only the animation frames (datasets in anim_config).
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
# Datasets animated in the catalogue: window width in the dataset's time unit, and span
anim_config <- list(
  "sp-highschool-2013" = list(width = 600, span = "day", n_nodes = 400), "sp-primaryschool" = list(width = 600, span = "day", n_nodes = 400),
  "sp-hospital-lyon" = list(width = 900, span = "day", n_nodes = 400), "sp-sfhh-conference" = list(width = 600, span = "day"),
  "sp-ht2009" = list(width = 900, span = "day"), "radoslaw-email-dataverse" = list(width = 3 * 3600, span = "week"),
  "snap-email-eu-core-temporal" = list(width = 14 * 86400, span = "all"), "snap-collegemsg" = list(width = 4 * 86400, span = "all"),
  "copenhagen-networks-study" = list(width = 12 * 3600, span = "all"),
  "international-football-results" = list(width = 4 * 365.25, span = "all"), "ucdp" = list(width = 2, span = "all"),
  "africa-mfa-visits" = list(width = 182.625, span = "all"), "us-leader-visits" = list(width = 2 * 365.25, span = "all"),
  "alien-species-first-records-rem" = list(width = 5, span = "all"),
  "govinfo-billstatus-118" = list(width = 14, span = "all", group_of = function(id) {
    p <- sub(".*\\(([A-Z]+)-.*", "\\1", id); match(p, c("D", "R", "I"), nomatch = 3) }),
  "enron-perry-wolfe" = list(width = 30.4375 * 86400, span = "all"))
frames_of <- function(id, obj) {
  cf <- anim_config[[id]]; if (is.null(cf)) return(NULL)
  f <- relabel[[id]]
  if (!is.null(f)) {
    if (obj$kind == "hyper") { obj$events$I <- lapply(obj$events$I, f); if (!is.null(obj$events$J)) obj$events$J <- lapply(obj$events$J, f) }
    else obj$events[c("sender", "receiver")] <- lapply(obj$events[c("sender", "receiver")], f)
  }
  view_frames(obj, cf$width, cf$span, n_nodes = if (is.null(cf$n_nodes)) 120 else cf$n_nodes, group_of = cf$group_of)
}
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
views_only <- any(c("--views-only", "--frames-only") %in% ids); frames_only <- "--frames-only" %in% ids
ids <- setdiff(ids, c("--views-only", "--frames-only"))
if (!length(ids)) ids <- names(readers)
if (views_only) ids <- ids[file.exists(file.path(out, paste0(ids, ".rds")))]
for (id in ids) {
  t0 <- Sys.time()
  res <- tryCatch({
    obj <- readers[[id]]()
    p <- if (views_only) readRDS(file.path(out, paste0(id, ".rds"))) else profile(obj)
    if (!frames_only) p$view <- view_of(id, obj)
    p$anim <- frames_of(id, obj)
    p$id <- id
    saveRDS(p, file.path(out, paste0(id, ".rds")), compress = "xz")
    sprintf("%-32s ok  %8s events  %5.1fs  fit: %s", id, format(p$stats[[1]], big.mark = ","),
            as.numeric(difftime(Sys.time(), t0, units = "secs")),
            if (is.data.frame(p$fit)) paste(sprintf("%s=%.2f", p$fit$term, p$fit$estimate), collapse = " ")
            else if (is.character(p$fit)) p$fit else "none")
  }, error = function(e) sprintf("%-32s FAIL %s", id, conditionMessage(e)))
  cat(res, "\n")
}
