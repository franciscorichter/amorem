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

# Time axis in readable units
.time_axis <- function(p, t) {
  u <- p$time_unit
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
  graphics::plot(ta$x, p$rate$n, type = "h", col = col_main, lwd = 2, xlab = "", ylab = "",
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
          l$licence_url, l$licence, verdict_text[[l$verdict]])
}
