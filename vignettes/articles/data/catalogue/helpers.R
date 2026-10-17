# Helpers for the data-catalogue articles. Profiles are aggregates built by
# data-raw/catalogue/build_profiles.R; licences.csv is the licence register.

cat_dir <- "data/catalogue"
licences <- utils::read.csv(file.path(cat_dir, "licences.csv"), stringsAsFactors = FALSE)
load_profile <- function(id) readRDS(file.path(cat_dir, paste0(id, ".rds")))
fmt_n <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ",")
fmt_p <- function(x) paste0(formatC(100 * x, format = "f", digits = 1), "%")

col_main <- "#1d4e89"; col_soft <- "#9ecae1"; col_ref <- "#b2182b"

verdict_text <- c(
  bundle = "may be redistributed with attribution",
  "gpl-only" = "GPL-3: redistributable only inside a GPL-compatible package",
  sharealike = "share-alike: redistributable only under the same licence",
  noncommercial = "non-commercial: not redistributable in amorem (MIT); obtain from the source",
  "no-licence" = "no licence stated: not redistributed; obtain from the source",
  "per-dataset" = "licence differs by dataset in the collection")

verdict_short <- c(bundle = "can bundle", "gpl-only" = "GPL only", sharealike = "share-alike",
                   noncommercial = "obtain from source", "no-licence" = "obtain from source",
                   "per-dataset" = "per dataset")

# Status of a dataset in amorem: the objects it ships as, or what its licence allows
amorem_status <- function(l, short = TRUE) {
  objs <- trimws(sub("\\(.*", "", l$in_amorem))
  if (is.na(objs) || !nzchar(objs)) return(if (short) verdict_short[[l$verdict]] else verdict_text[[l$verdict]])
  objs <- paste(sprintf("`%s`", trimws(strsplit(objs, ",")[[1]])), collapse = ", ")
  if (l$verdict == "bundle") return(paste("bundled as", objs))
  paste0("bundled as ", objs, " since an earlier release; licence under review")
}

# Time axis in readable units
.time_axis <- function(p, t) {
  u <- p$time_unit
  if (u == "days" && is.null(p$origin))   # readers store days as days since 1970-01-01
    return(list(x = as.Date(t, origin = "1970-01-01"), lab = "date"))
  if (!is.null(p$origin) && u %in% c("seconds", "days")) {
    sec <- if (u == "seconds") 1 else 86400
    return(list(x = as.POSIXct(p$origin + t * sec), lab = "date"))
  }
  span <- diff(range(t))
  if (u == "seconds" && span > 3 * 86400) return(list(x = t / 86400, lab = "days from start"))
  if (u == "seconds" && span > 3 * 3600) return(list(x = t / 3600, lab = "hours from start"))
  list(x = t, lab = u)
}

.lab <- function(x) {
  ifelse(x >= 1e5 | x < 1e-3, formatC(x, format = "e", digits = 0),
         formatC(x, format = "fg", big.mark = ","))
}
.titles <- function(xlab, ylab) {
  graphics::title(xlab = xlab, line = 2.4)
  graphics::title(ylab = ylab, line = 3.9)
}

plot_dyadic <- function(p) {
  op <- graphics::par(mfrow = c(1, 4), mar = c(4, 5.4, 2.6, 0.8), mgp = c(2.4, 0.7, 0), cex = 0.8)
  on.exit(graphics::par(op))
  ta <- .time_axis(p, p$rate$t)
  graphics::plot(ta$x, p$rate$n, type = "h", col = col_main, lwd = 2, xlab = "", ylab = "", ylim = c(0, max(p$rate$n)),
                 main = "activity over time", las = 1, bty = "l")
  .titles(ta$lab, "events per bin")
  .loglog(p$iet_ccdf, sprintf("pair gap (%s)", p$time_unit), "P(gap > x)", "repeat-contact gaps")
  .loglog(p$degree_ccdf, "distinct partners", "P(partners > x)", "partners per actor")
  if (!is.null(p$cycle)) {
    graphics::barplot(p$cycle$hour / sum(p$cycle$hour), names.arg = 0:23, col = col_soft,
                      border = NA, las = 1, main = "daily cycle", cex.names = 0.7)
    .titles(sprintf("hour of day (%s)", p$tz), "share of events")
  } else {
    .loglog(p$activity_ccdf, "events per actor", "P(events > x)", "actor activity")
  }
}

.loglog <- function(d, xlab, ylab, main) {
  d <- d[d$p > 0, ]
  if (!nrow(d)) { graphics::plot.new(); graphics::title(main); return(invisible()) }
  graphics::plot(d$x, d$p, log = "xy", pch = 16, cex = 0.6, col = col_main, xlab = "",
                 ylab = "", main = main, las = 1, bty = "l", xaxt = "n", yaxt = "n")
  xt <- 10^seq(floor(log10(min(d$x))), ceiling(log10(max(d$x))))
  yt <- 10^seq(floor(log10(min(d$p))), 0)
  graphics::axis(1, at = xt, labels = .lab(xt))
  graphics::axis(2, at = yt, labels = .lab(yt), las = 1)
  .titles(xlab, ylab)
}

# One sentence-block of findings computed from the profile.
describe_dyadic <- function(p) {
  s <- p$stats
  span <- if (p$time_unit == "seconds") sprintf("%s days", fmt_n(s[["span"]] / 86400, 1))
          else sprintf("%s %s", fmt_n(s[["span"]], 1), p$time_unit)
  txt <- sprintf(paste0("**%s** %s among **%s** actors over %s (%s distinct %s). ",
                        "%s of events repeat an earlier %s; if every event chose a %s at random the share would be %s. "),
                 fmt_n(s[["events"]]), if (p$directed) "directed events" else "undirected contacts",
                 fmt_n(s[["actors"]]), span, fmt_n(s[["dyads"]]), if (p$directed) "ordered pairs" else "pairs",
                 fmt_p(s[["repetition"]]), if (p$directed) "ordered pair" else "pair",
                 if (p$directed) "pair" else "pair", fmt_p(s[["repetition_random"]]))
  if (p$directed && !is.na(s[["reciprocity"]]))
    txt <- paste0(txt, sprintf("%s of events answer an earlier event in the opposite direction. ", fmt_p(s[["reciprocity"]])))
  txt <- paste0(txt, sprintf(paste0("The burstiness coefficient of the gaps between successive events of the same pair is %s ",
                                    "(0 for a Poisson process, positive when events cluster in bursts); ",
                                    "the most active tenth of the actors take part in %s of events (Gini %s)."),
                             formatC(s[["burstiness"]], format = "f", digits = 2), fmt_p(s[["top10_share"]]),
                             formatC(s[["gini_activity"]], format = "f", digits = 2)))
  if (s[["tied_time_share"]] > 0.2)
    txt <- paste0(txt, sprintf(" %s of events share their time stamp with an earlier one.", fmt_p(s[["tied_time_share"]])))
  txt
}

fit_table <- function(p) {
  if (!is.data.frame(p$fit)) return(invisible(NULL))
  f <- p$fit
  data.frame(term = c(sender_outdegree = "log(1 + sender's past events)",
                      receiver_indegree = "log(1 + receiver's past events received)",
                      reciprocity_count = "log(1 + past events receiver -> sender)")[f$term],
             estimate = round(f$estimate, 2), se = round(f$se, 2), row.names = NULL)
}

source_block <- function(id) {
  l <- licences[licences$id == id, ]
  sprintf("*Source:* <%s> · *Licence:* %s · *Status in amorem:* %s.",
          l$licence_url, l$licence, amorem_status(l, short = FALSE))
}

# --- hyperevents ---------------------------------------------------------------
plot_hyper <- function(p) {
  op <- graphics::par(mfrow = c(1, 3), mar = c(4, 5.4, 2.6, 0.8), mgp = c(2.4, 0.7, 0), cex = 0.8)
  on.exit(graphics::par(op))
  ta <- .time_axis(p, p$rate$t)
  graphics::plot(ta$x, p$rate$n, type = "h", col = col_main, lwd = 2, xlab = "", ylab = "", ylim = c(0, max(p$rate$n)),
                 main = "activity over time", las = 1, bty = "l")
  .titles(ta$lab, "events per bin")
  si <- p$size_I; si$size <- as.numeric(as.character(si$size))
  if (nrow(si) == 1) {
    graphics::plot.new(); graphics::title(if (p$directed) "sender-set size" else "set size")
    graphics::text(0.5, 0.5, sprintf("every event has %s\n%s", si$size, if (si$size == 1) "member" else "members"), cex = 1.1)
  } else {
    graphics::plot(si$size, si$Freq / sum(si$Freq), log = "xy", pch = 16, cex = 0.7, col = col_main,
                   xlab = "", ylab = "", main = if (p$directed) "sender-set size" else "set size",
                   las = 1, bty = "l")
    .titles("actors in the set", "share of events")
  }
  if (p$directed) {
    sj <- p$size_J; sj$size <- as.numeric(as.character(sj$size)); sj <- sj[sj$size > 0, ]
    graphics::plot(sj$size, sj$Freq / sum(sj$Freq), log = "xy", pch = 16, cex = 0.7, col = col_ref,
                   xlab = "", ylab = "", main = "receiver-set size", las = 1, bty = "l")
    .titles("actors in the set", "share of events")
  } else {
    .loglog(p$iet_ccdf, sprintf("gap between events (%s)", p$time_unit), "P(gap > x)", "inter-event times")
  }
}

describe_hyper <- function(p) {
  s <- p$stats
  sprintf(paste0("**%s** hyperevents involving **%s** distinct actors%s. ",
                 "%s have on average %s members (largest %s)%s. ",
                 "%s of events repeat an earlier event with exactly the same %s."),
          fmt_n(s[["events"]]), fmt_n(s[["actors"]]),
          if (p$directed) " (senders and receivers together)" else "",
          if (p$directed) "Sender sets" else "Sets", formatC(s[["mean_I"]], format = "f", digits = 2), fmt_n(s[["max_I"]]),
          if (p$directed) sprintf(", receiver sets %s (largest %s)", formatC(s[["mean_J"]], format = "f", digits = 2), fmt_n(s[["max_J"]])) else "",
          fmt_p(s[["exact_repetition"]]), if (p$directed) "sender and receiver sets" else "set")
}

# --- series --------------------------------------------------------------------
plot_series <- function(p) {
  d <- p$series
  num <- names(d)[vapply(d, is.numeric, logical(1)) & names(d) != "time"]
  grp <- names(d)[!vapply(d, is.numeric, logical(1))][1]
  tx <- if (p$time_unit == "days") as.Date(d$time, origin = "1970-01-01") else d$time
  xl <- if (p$time_unit == "days") "date" else p$time_unit
  if (!length(num)) {   # entries without values (e.g. holidays): counts per group
    op <- graphics::par(mar = c(4, 8, 2.6, 0.8), cex = 0.8); on.exit(graphics::par(op))
    graphics::barplot(table(d[[grp]]), horiz = TRUE, las = 1, col = col_soft, border = NA, main = "entries per group")
    return(invisible())
  }
  g <- if (!is.na(grp)) factor(d[[grp]]) else NULL
  if (!is.null(g) && nlevels(g) <= 6) {
    # one panel per group; the first two variables together when they share a unit suffix
    v <- num[1]; v2 <- if (length(num) > 1 && sub(".*_", "", num[2]) == sub(".*_", "", num[1])) num[2] else NA
    op <- graphics::par(mfrow = c(1, nlevels(g)), mar = c(4, 5.4, 2.6, 0.8), mgp = c(2.4, 0.7, 0), cex = 0.8)
    on.exit(graphics::par(op))
    yr <- range(d[[v]], if (!is.na(v2)) d[[v2]], na.rm = TRUE)
    for (k in levels(g)) {
      ix <- g == k; o <- order(d$time[ix])
      graphics::plot(tx[ix][o], d[[v]][ix][o], type = "l", col = col_ref, ylim = yr, xlab = "", ylab = "",
                     main = substr(k, 1, 28), las = 1, bty = "l")
      if (!is.na(v2)) {
        graphics::lines(tx[ix][o], d[[v2]][ix][o], col = col_main)
        if (k == levels(g)[1]) graphics::legend("bottomleft", c(v, v2), col = c(col_ref, col_main), lwd = 1.5, bty = "n", cex = 0.75)
      }
      .titles(xl, if (is.na(v2)) v else paste(v, "/", v2))
    }
    return(invisible())
  }
  num <- head(num, 3)
  op <- graphics::par(mfrow = c(1, length(num)), mar = c(4, 5.4, 2.6, 0.8), mgp = c(2.4, 0.7, 0), cex = 0.8)
  on.exit(graphics::par(op))
  for (v in num) {
    if (is.null(g)) {
      o <- order(d$time)
      graphics::plot(tx[o], d[[v]][o], type = "l", col = col_main, xlab = "", ylab = "", main = v, las = 1, bty = "l")
    } else {   # many groups (e.g. countries): every value as a faint point
      graphics::plot(tx, d[[v]], pch = 16, cex = 0.3, col = grDevices::adjustcolor(col_main, 0.25),
                     xlab = "", ylab = "", main = v, las = 1, bty = "l")
    }
    .titles(xl, v)
  }
}

describe_series <- function(p) {
  sm <- p$summary
  sm <- sm[is.finite(sm$mean), ]
  if (!nrow(sm)) return(sprintf("**%s** entries.", fmt_n(p$stats[["points"]])))
  paste0(sprintf("**%s** observations. ", fmt_n(p$stats[["points"]])),
         paste(sprintf("`%s`: mean %s, sd %s, range %s to %s, %s missing", sm$variable,
                       formatC(sm$mean, format = "fg", digits = 3), formatC(sm$sd, format = "fg", digits = 3),
                       formatC(sm$min, format = "fg", digits = 3), formatC(sm$max, format = "fg", digits = 3),
                       fmt_p(sm$missing)), collapse = "; "), ".")
}

# --- page assembly -------------------------------------------------------------
# Fits whose pattern is built into the data rather than estimated from behaviour.
structural_fit <- c(
  "snap-cit-hepth" = "a paper makes all its citations at once, so the sender's past activity is 0 at its own events",
  "snap-cit-hepph" = "a paper makes all its citations at once, so the sender's past activity is 0 at its own events",
  "kddcup2003-hepth" = "a paper makes all its citations at once, so the sender's past activity is 0 at its own events",
  "nber-patent-citations" = "a patent makes all its citations at once; the first events have no history",
  "snap-act-mooc" = "users act on course items, so reciprocity is impossible",
  "gharchive-sample" = "users act on repositories, so reciprocity is impossible",
  "alien-species-first-records-rem" = "species reach regions, so reciprocity is impossible and each pair fires once",
  "alien-first-records-v4" = "species reach regions, so reciprocity is impossible and each pair fires once",
  "covid-bucharest-transmission" = "each person is infected once, so the receiver's past events are 0 at every event",
  "ucdp" = "a conflict dyad-year repeats every year the conflict is active")

render_group <- function(ids, envir = parent.frame()) {
  ids <- ids[file.exists(file.path(cat_dir, paste0(ids, ".rds")))]
  for (id in ids) {
    kind <- load_profile(id)$kind
    tmpl <- paste(readLines(file.path(cat_dir, sprintf("section-%s.tmpl", kind))), collapse = "\n")
    sec <- gsub("{{id}}", id, tmpl, fixed = TRUE)
    sec <- gsub("{{title}}", licences$title[licences$id == id], sec, fixed = TRUE)
    cat(knitr::knit_child(text = sec, quiet = TRUE, envir = envir), sep = "\n")
  }
}

summary_table <- function(ids) {
  ids <- ids[file.exists(file.path(cat_dir, paste0(ids, ".rds")))]
  rows <- lapply(ids, function(id) {
    p <- load_profile(id); s <- p$stats; l <- licences[licences$id == id, ]
    data.frame(dataset = sprintf("[%s](#%s)", l$title, gsub("[^a-z0-9]+", "-", tolower(l$title))),
               events = fmt_n(s[[1]]), actors = if (!is.null(s["actors"]) && !is.na(s["actors"])) fmt_n(s[["actors"]]) else "",
               licence = l$licence, amorem = amorem_status(l))
  })
  knitr::kable(do.call(rbind, rows), row.names = FALSE)
}
