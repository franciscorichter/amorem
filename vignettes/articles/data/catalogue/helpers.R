# Helpers for the data-catalogue articles. Profiles are aggregates built by
# data-raw/catalogue/build_profiles.R; licences.csv is the licence register.

cat_dir <- "data/catalogue"
knitr::opts_chunk$set(dev.args = list(bg = "white"))   # figures stay legible on a dark page
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

# --- views: the events themselves ------------------------------------------------
pal_comm <- c("#178E8E", "#8E7CC3", "#6FA05A", "#4F8CC9", "#C8729A", "#C99A3B", "#9C5B8E", "#5BA7B5", "#9A9A3C", "#7A8FB8")
comm_col <- function(k) ifelse(!is.na(k) & k <= length(pal_comm), pal_comm[pmin(pmax(k, 1), length(pal_comm))], "#9AA0A6")
alpha <- function(col, a) { n <- max(length(col), length(a)); m <- grDevices::col2rgb(rep_len(col, n)) / 255
  grDevices::rgb(m[1, ], m[2, ], m[3, ], pmin(1, pmax(0, rep_len(a, n)))) }
ink <- "#26323A"; ink_soft <- "#5F6B73"

# time axis for the view figures: dates when the clock is known, else elapsed time
tax <- function(p) {
  u <- p$time_unit
  if (u == "days" && is.null(p$origin)) return(function(side, r) {
    d <- as.Date(r, origin = "1970-01-01"); at <- pretty(d, 8); sp <- diff(r)
    at <- at[as.numeric(at) >= r[1] + 0.03 * sp & as.numeric(at) <= r[2] - 0.05 * sp]
    axis(side, cex.axis = 0.72, at = as.numeric(at), tick = FALSE, line = -0.6, col.axis = ink_soft,
         labels = format(at, if (diff(as.numeric(d)) > 1500) "%Y" else if (diff(as.numeric(d)) > 40) "%b %Y" else "%d %b %Y")) })
  if (!is.null(p$origin) && u %in% c("seconds", "days")) return(function(side, r) {
    s <- if (u == "seconds") 1 else 86400; o <- as.numeric(p$origin); tz <- if (is.null(p$tz)) "UTC" else p$tz
    d <- as.POSIXct(o + r * s, origin = "1970-01-01", tz = tz)
    at <- pretty(d, 8); span <- diff(as.numeric(d))
    at <- at[as.numeric(at) >= as.numeric(d[1]) + 0.03 * span & as.numeric(at) <= as.numeric(d[2]) - 0.05 * span]
    axis(side, cex.axis = 0.72, at = (as.numeric(at) - o) / s, tick = FALSE, line = -0.6, col.axis = ink_soft,
         labels = format(at, if (span < 2 * 86400) "%H:%M" else if (span < 20 * 86400) "%d %b %H:%M" else if (span < 120 * 86400) "%d %b" else "%b %Y")) })
  sc <- function(span) if (u == "seconds" && span > 3 * 86400) list(86400, "day ", 1) else if (u == "seconds" && span > 3 * 3600)
    list(3600, " h", 0) else if (u == "seconds" && span > 180) list(60, " min", 0) else if (u == "days from start")
    list(1, "day ", 1) else if (u %in% c("years", "year")) list(1, "", 0) else list(1, paste0(" ", u), 0)
  function(side, r) {
    k <- sc(diff(r)); at <- pretty(r / k[[1]], 8); sp <- diff(r) / k[[1]]
    at <- at[at >= r[1] / k[[1]] + 0.03 * sp & at <= r[2] / k[[1]] - 0.05 * sp]
    lab <- if (k[[3]] == 1) paste0(k[[2]], at + 1) else paste0(at, k[[2]])
    axis(side, cex.axis = 0.72, at = at * k[[1]], labels = lab, tick = FALSE, line = -0.6, col.axis = ink_soft)
  }
}
.fmt_t <- function(p, t) {
  u <- p$time_unit
  if (u == "days" && is.null(p$origin)) return(format(as.Date(t, origin = "1970-01-01"), "%d %B %Y"))
  if (!is.null(p$origin) && u %in% c("seconds", "days"))
    return(format(as.POSIXct(as.numeric(p$origin) + t * (if (u == "seconds") 1 else 86400), origin = "1970-01-01",
                             tz = if (is.null(p$tz)) "UTC" else p$tz), "%a %d %B %Y %H:%M"))
  if (u == "seconds") return(sprintf("hour %.1f", t / 3600))
  if (u == "days from start") return(sprintf("day %.1f", t + 1))
  if (u %in% c("years", "year")) return(format(round(t)))
  paste(format(signif(t, 6)), u)
}
# length of a time bin in words
.fmt_dur <- function(p, d) {
  u <- p$time_unit
  if (u %in% c("years", "year")) return(if (d < 1.5) "year" else sprintf("%.0f years", d))
  s <- if (u == "seconds") d else if (u %in% c("days", "days from start")) d * 86400 else NA
  if (is.na(s)) return(paste(signif(d, 2), u))
  named <- c("second" = 1, "10 seconds" = 10, "minute" = 60, "5 minutes" = 300, "15 minutes" = 900, "hour" = 3600,
             "3 hours" = 10800, "6 hours" = 21600, "day" = 86400, "week" = 604800, "month" = 30.4375 * 86400,
             "year" = 365.25 * 86400, "5 years" = 5 * 365.25 * 86400, "10 years" = 10 * 365.25 * 86400)
  k <- which(abs(named / s - 1) < 0.02); if (length(k)) return(names(named)[k[1]])
  pl <- function(x, u) sprintf("%.0f %s%s", x, u, if (round(x) == 1) "" else "s")
  if (s < 90) pl(s, "second") else if (s < 5400) pl(s / 60, "minute") else if (s < 1.5 * 86400)
    pl(s / 3600, "hour") else if (s < 60 * 86400) pl(s / 86400, "day") else pl(s / (30.4 * 86400), "month")
}

# network: groups (colours) and the strongest ties
plot_network <- function(v) {
  net <- v$network; nd <- net$nodes; ed <- net$edges
  op <- par(mar = c(2.6, 0.3, 0.3, 0.3)); on.exit(par(op))
  plot(NA, xlim = c(-0.08, 1.08), ylim = c(-0.06, 1.06), axes = FALSE, xlab = "", ylab = "", asp = 1)
  ed <- ed[order(ed$n), ]
  i <- match(ed$sender, nd$id); j <- match(ed$receiver, nd$id)
  wq <- log1p(ed$n) / log1p(max(ed$n))
  same <- nd$community[i] == nd$community[j]
  ecol <- ifelse(same, alpha(comm_col(nd$community[i]), 0.35 + 0.55 * wq), alpha("#B4BBC0", 0.10 + 0.22 * wq))
  segments(nd$x[i], nd$y[i], nd$x[j], nd$y[j], lwd = ifelse(same, 0.4 + 3.4 * wq^1.5, 0.3 + 1.6 * wq^1.5), col = ecol)
  cex <- 0.7 + 2.6 * sqrt(nd$activity / max(nd$activity))
  o <- order(nd$activity)
  points(nd$x[o], nd$y[o], pch = 21, bg = comm_col(nd$community[o]), col = "white", cex = cex[o], lwd = 0.8)
  if (any(grepl("[A-Za-z]", nd$id))) {
    # every actor labelled, pushed away from the centre of its group
    gx <- ave(nd$x, nd$community); gy <- ave(nd$y, nd$community)
    single <- ave(nd$x, nd$community, FUN = length) == 1
    gx[single] <- mean(nd$x); gy[single] <- mean(nd$y)
    ang <- atan2(nd$y - gy, nd$x - gx); ang[nd$x == gx & nd$y == gy] <- pi / 2
    r <- 0.018 + 0.012 * cex / max(cex)
    adj_x <- ifelse(cos(ang) > 0.35, 0, ifelse(cos(ang) < -0.35, 1, 0.5))
    adj_y <- ifelse(sin(ang) > 0.35, 0, ifelse(sin(ang) < -0.35, 1, 0.5))
    lab <- .short(nd$id, 18); lc <- 0.42 + 0.14 * sqrt(nd$activity / max(nd$activity))
    w <- strwidth(lab, cex = lc); h <- strheight(lab, cex = lc) * 1.25
    lx <- nd$x + r * cos(ang) + (0.5 - adj_x) * w; ly <- nd$y + r * sin(ang) + (0.5 - adj_y) * h   # label centres
    for (it in 1:60) {   # push overlapping labels apart, mostly vertically
      moved <- FALSE
      for (a in seq_along(lx)) for (b in seq_along(lx)) if (a < b) {
        ox <- (w[a] + w[b]) / 2 - abs(lx[a] - lx[b]); oy <- (h[a] + h[b]) / 2 - abs(ly[a] - ly[b])
        if (ox > 0 && oy > 0) { d <- if (ly[a] >= ly[b]) 1 else -1; s <- min(oy, 0.01) / 2 + 0.001
          ly[a] <- ly[a] + d * s; ly[b] <- ly[b] - d * s; moved <- TRUE }
      }
      if (!moved) break
    }
    text(lx, ly, lab, cex = lc, col = ink, xpd = TRUE)
  }
  mtext("dot size: events of the actor  ·  line width: events between the pair  ·  colour: group (modularity); grey lines join different groups",
        side = 1, line = 1.2, cex = 0.58, col = ink_soft)
}

.short <- function(x, n = 22) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "."), x)
.lab_w <- function(ids) 0.6 + max(nchar(.short(ids))) * 0.40 + 1.2

# rows of actors: labels on the left with a group colour chip
.row_frame <- function(rows, xlim, note = NULL, extra = NULL) {
  ids <- c(rows$id, extra); R <- length(ids); lab <- .short(ids)
  par(mar = c(2.6, .lab_w(ids), if (is.null(note)) 0.3 else 1.1, 0.8))
  plot(NA, xlim = xlim, ylim = c(0.5, R + 0.5), axes = FALSE, xlab = "", ylab = "", xaxs = "i", yaxs = "i")
  u <- par("usr"); w <- diff(u[1:2]) * 0.008
  rect(u[1] - 2.2 * w, (R:1)[seq_len(nrow(rows))] - 0.42, u[1] - w, (R:1)[seq_len(nrow(rows))] + 0.42,
       col = comm_col(rows$community), border = NA, xpd = TRUE)
  axis(2, at = R:1, labels = lab, las = 1, tick = FALSE, cex.axis = 0.58, line = -0.2, col.axis = "#3A4650")
  if (!is.null(note)) mtext(note, side = 3, adj = 0, line = 0.1, cex = 0.6, col = ink_soft)
  setNames(R:1, ids)
}
# bars above the rows, with a scale
.top_strip <- function(x, h, xlim, title, lab_w, lwd = 1.4) {
  par(mar = c(0.2, lab_w, 1.5, 0.8))
  plot(x, h, type = "h", lwd = lwd, lend = 1, col = "#AEB5BA", axes = FALSE, xlab = "", ylab = "", xaxs = "i",
       xlim = xlim, ylim = c(0, max(h, 1)))
  axis(2, at = c(0, max(h, 1)), labels = format(c(0, max(h, 1)), big.mark = ","), las = 1, tick = FALSE,
       cex.axis = 0.58, line = -0.6, col.axis = ink_soft)
  mtext(title, side = 3, adj = 0, cex = 0.72, col = ink, line = 0.25)
}
.ends <- function(p, xl) {
  mtext(.fmt_t(p, xl[1]), side = 1, line = 1.3, adj = 0, cex = 0.55, col = ink_soft)
  mtext(.fmt_t(p, xl[2]), side = 1, line = 1.3, adj = 1, cex = 0.55, col = ink_soft)
}

# whole period: one row per actor, shade = events in the time bin
plot_timeline <- function(v, meta) {
  br <- v$breaks; xl <- range(br); mids <- (head(br, -1) + tail(br, -1)) / 2
  layout(matrix(1:2, 2), heights = c(1, 4))
  .top_strip(mids, v$bin_total, xl, sprintf("Events per %s (all %s events)", .fmt_dur(meta, diff(br[1:2])),
                                           format(v$n_events, big.mark = ",")), .lab_w(v$rows$id))
  y <- .row_frame(v$rows, xl, note = sprintf("the %d most active actors, coloured by network group; darker = more events in the %s",
                                             nrow(v$rows), .fmt_dur(meta, diff(br[1:2]))))
  h <- v$heat[v$heat$id %in% names(y), ]
  a <- 0.12 + 0.88 * log1p(h$n) / log1p(max(h$n))
  cc <- comm_col(v$rows$community[match(h$id, v$rows$id)])
  rect(br[h$bin], y[h$id] - 0.42, br[h$bin + 1], y[h$id] + 0.42, col = alpha(cc, a), border = NA)
  tax(meta)(1, xl); .ends(meta, xl)
}

# close-up: every event drawn as a line from sender (dot) to receiver (ring)
plot_zoom <- function(v, meta) {
  br <- v$zoom_breaks; xl <- range(br); mids <- (head(br, -1) + tail(br, -1)) / 2
  z <- v$zoom
  rows <- v$rows[v$rows$id %in% c(z$sender, z$receiver), ]
  layout(matrix(1:2, 2), heights = c(1, 4))
  tot <- tabulate(rep(z$bin, z$n), length(mids))
  .top_strip(mids, tot, xl, sprintf("The busiest stretch, event by event (%s events; bars: events per %s)",
                                    format(v$zoom_total, big.mark = ","), .fmt_dur(meta, diff(br[1:2]))), .lab_w(rows$id), lwd = 2)
  y <- .row_frame(rows, xl, note = if (v$directed) "one vertical line per event, from the sender (dot) to the receiver (ring)" else "one vertical line per contact between two actors")
  abline(h = y, col = "#EEF0F1", lwd = 0.8)
  if (nrow(z)) {
    x <- mids[z$bin]; ys <- y[z$sender]; yr <- y[z$receiver]
    cs <- comm_col(rows$community[match(z$sender, rows$id)])
    segments(x, ys, x, yr, col = alpha(cs, 0.6), lwd = 1.4)
    points(x, yr, pch = if (v$directed) 21 else 16, bg = "white", cex = 0.85, lwd = 1.2, col = cs)
    points(x, ys, pch = 16, cex = 0.9, col = cs)
    if (v$directed) {   # name the largest one-to-many send
      fan <- aggregate(list(k = z$n), list(bin = z$bin, sender = z$sender), sum); fan <- fan[which.max(fan$k), ]
      if (fan$k >= 3) {
        yy <- y[z$receiver[z$bin == fan$bin & z$sender == fan$sender]]
        text(mids[fan$bin], max(c(yy, y[fan$sender])) + 0.6, sprintf("one sender \u2192 %d receivers at once", fan$k),
             pos = if (mids[fan$bin] < mean(xl)) 4 else 2, cex = 0.6, col = ink, xpd = TRUE, offset = 0.3)
      }
    }
  }
  tax(meta)(1, xl); .ends(meta, xl)
}

# counting processes of the busiest pairs; a pair and its reverse share a colour
plot_counts <- function(v, meta) {
  pr <- v$pairs; k <- nrow(pr)
  und <- paste(pmin(pr$sender, pr$receiver), pmax(pr$sender, pr$receiver))
  hue <- pal_comm[match(und, unique(und))]
  rev <- duplicated(und)
  par(mar = c(2.8, 3.6, 1.6, 10))
  matplot(v$grid, v$counts, type = "n", axes = FALSE,
          xlab = "", ylab = "", xaxs = "i", ylim = c(0, max(v$counts)))
  for (k in order(rev)) lines(v$grid, v$counts[, k], type = "s", col = if (rev[k]) alpha(hue[k], 0.9) else hue[k],
                              lty = if (rev[k]) "22" else 1, lwd = if (rev[k]) 1.4 else 2.6)
  axis(2, las = 1, tick = FALSE, cex.axis = 0.7, line = -0.6, col.axis = ink_soft); tax(meta)(1, range(v$grid))
  mtext("events of the pair so far, N(t)", side = 3, adj = 0, line = 0.3, cex = 0.72, col = ink)
  .ends(meta, range(v$grid))
  arr <- if (v$directed) " → " else " – "
  lab <- .short(paste0(pr$sender, arr, pr$receiver), 30)
  lab <- paste0(lab, "  ", format(pr$n, big.mark = ","))
  yl <- v$counts[nrow(v$counts), ]; ya <- yl
  o <- order(yl); gap <- diff(par("usr")[3:4]) * 0.065; yy <- yl[o]
  for (i in seq_along(yy)[-1]) yy[i] <- max(yy[i], yy[i - 1] + gap)
  ya[o] <- yy
  xr <- par("usr")[2]; dx <- diff(par("usr")[1:2]) * 0.015
  segments(xr, yl, xr + dx, ya, col = hue, xpd = TRUE, lwd = 0.8)
  text(xr + dx, ya, lab, pos = 4, xpd = TRUE, col = hue, cex = 0.62, offset = 0.2)
  if (any(rev)) mtext("thin dashed line: the reverse direction of a pair (same colour)", side = 1, line = 1.3, cex = 0.55, col = ink_soft)
}

plot_hyper_timeline <- function(v, meta) {
  br <- v$breaks; xl <- range(br); mids <- (head(br, -1) + tail(br, -1)) / 2
  layout(matrix(1:2, 2), heights = c(1, 4))
  .top_strip(mids, v$bin_total, xl, sprintf("Hyperevents per %s (all %s)", .fmt_dur(meta, diff(br[1:2])),
                                           format(v$n_events, big.mark = ",")), .lab_w(v$rows$id))
  y <- .row_frame(v$rows, xl, note = sprintf("the %d actors in most hyperevents, coloured by group; darker = in more hyperevents in the %s",
                                             nrow(v$rows), .fmt_dur(meta, diff(br[1:2]))))
  h <- v$raster[v$raster$id %in% names(y), ]
  a <- 0.12 + 0.88 * log1p(h$n) / log1p(max(h$n))
  rect(br[h$bin], y[h$id] - 0.42, br[h$bin + 1], y[h$id] + 0.42,
       col = alpha(comm_col(v$rows$community[match(h$id, v$rows$id)]), a), border = NA)
  tax(meta)(1, xl); .ends(meta, xl)
}

# consecutive hyperevents, one per column; members outside the rows go to a last row
plot_hyper_zoom <- function(v, meta) {
  z <- v$zoom; K <- length(z)
  used <- unique(unlist(lapply(z, function(e) c(e$I, e$J))))
  rows <- v$rows[v$rows$id %in% used, ]
  directed <- any(lengths(lapply(z, `[[`, "J")) > 0)
  other <- "others"
  layout(matrix(1:2, 2), heights = c(1, 4))
  sz <- vapply(z, `[[`, 0, "size")
  .top_strip(seq_len(K), sz, c(0.5, K + 0.5), sprintf("%d consecutive hyperevents and their size (members)", K),
             .lab_w(c(rows$id, other)), lwd = 3)
  big <- which(sz >= max(sz) / 2)
  text(big, sz[big], sz[big], pos = 3, cex = 0.5, col = ink_soft, xpd = TRUE, offset = 0.15)
  y <- .row_frame(rows, c(0.5, K + 0.5), extra = other,
                  note = if (directed) "one column per hyperevent: sender side (dot), receiver side (ring); rows coloured by group; numbers: receivers among others" else
                    "one column per hyperevent, joining its members; rows coloured by group; numbers: members among others")
  abline(h = y, col = "#EEF0F1", lwd = 0.8)
  for (k in seq_len(K)) {
    I <- z[[k]]$I; J <- z[[k]]$J
    nI_out <- (if (is.null(z[[k]]$n_I)) length(I) else z[[k]]$n_I) - length(I)
    n_out <- z[[k]]$size - length(unique(c(I, J))) - nI_out
    cc <- if (length(I)) comm_col(rows$community[match(I[1], rows$id)]) else "#4A5560"
    yy <- c(y[c(I, J)], if (nI_out > 0 || n_out > 0) y[other])
    if (length(yy) > 1) segments(k, min(yy), k, max(yy), col = alpha(cc, 0.55), lwd = 1.3)
    if (n_out > 0) { points(k, y[other], pch = 21, bg = "white", col = cc, cex = 0.85)
                     text(k, y[other] + 0.55, n_out, cex = 0.45, col = ink_soft, srt = 90, adj = c(0, 0.5)) }
    if (length(J)) points(rep(k, length(J)), y[J], pch = 21, bg = "white", cex = 0.85, lwd = 1.1, col = cc)
    if (nI_out > 0) points(k, y[other], pch = 16, cex = 0.9, col = cc)
    if (length(I)) points(rep(k, length(I)), y[I], pch = 16, cex = 0.9, col = cc)
  }
  mtext(sprintf("%s  →  %s", .fmt_t(meta, v$zoom_time[1]), .fmt_t(meta, v$zoom_time[2])),
        side = 1, line = 0.6, cex = 0.62, col = ink_soft)
}

cap_network <- function(p) { v <- p$view; n <- v$network
  sprintf("The %d actors of the busiest pairs, out of %s; events between two of them are %s of all events. Each actor's three strongest ties are drawn (%s of %s pairs that ever interacted): wider, darker lines carry more events, larger dots are more active actors, and colours are groups found by modularity (Louvain).",
          nrow(n$nodes), fmt_n(n$n_actors), fmt_p(n$share_events), fmt_n(n$n_backbone), fmt_n(n$n_ties)) }
cap_timeline <- function(p) { v <- p$view
  sprintf("Each row is one of the %d most active actors of the network, coloured by its group there; a cell is darker the more events (with anyone) the actor took part in during that stretch of time. The grey bars on top count all %s events.",
          nrow(v$rows), fmt_n(v$n_events)) }
cap_closeup <- function(p) { v <- p$view; zb <- v$zoom_breaks
  sprintf("The busiest stretch of the record, %s to %s, event by event: each vertical line is one event between two of the actors above%s.",
          .fmt_t(p, zb[1]), .fmt_t(p, zb[length(zb)]), if (v$directed) ", from the sender (dot) to the receiver (ring)" else "") }
cap_pairs <- function(p) { v <- p$view; pr <- v$pairs
  rec <- if (v$directed) sum(paste(pr$sender, pr$receiver) %in% paste(pr$receiver, pr$sender)) / 2 else 0
  paste0(sprintf("The counting process N(t) of the %d busiest pairs: the number of events of the pair up to time t. Together they make %s of all events. Steep stretches are bursts and flat ones silences.",
                 nrow(pr), fmt_p(sum(pr$n) / v$n_events)),
         if (rec >= 1) sprintf(" %s of these pairs %s the reverse of another, so replies run alongside the messages they answer.", fmt_n(rec * 2), "are") else "") }
cap_hyper_timeline <- function(p) { v <- p$view
  sprintf("Each row is one of the %d actors who take part in most of the %s hyperevents, coloured by group (modularity on co-membership); a cell is darker the more hyperevents the actor joined in that stretch of time. The grey bars on top count all hyperevents.",
          nrow(v$rows), fmt_n(v$n_events)) }
cap_hyper_closeup <- function(p) { v <- p$view
  sprintf("%d consecutive hyperevents, %s to %s, one per column: the bar on top is its size, and the line joins its members among the rows above%s. Members outside these %d rows are counted in the bar but not drawn.",
          length(v$zoom), .fmt_t(p, v$zoom_time[1]), .fmt_t(p, v$zoom_time[2]),
          if (any(lengths(lapply(v$zoom, `[[`, "J")) > 0)) " (dot: sender side, ring: receiver side)" else "", nrow(v$rows)) }

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
