# Animated figures for the articles: frames drawn with base graphics, encoded
# to MP4 with ffmpeg and embedded as a <video> with controls. Only the video and
# one poster frame are kept in the site.

.anim_alpha <- function(col, a) {
  n <- max(length(col), length(a)); m <- grDevices::col2rgb(rep_len(col, n)) / 255
  grDevices::rgb(m[1, ], m[2, ], m[3, ], pmin(1, pmax(0, rep_len(a, n))))
}

# draw_frame(k) draws frame k; n frames; fps frames per second.
anim_video <- function(draw_frame, n, width = 960, height = 720, res = 120, fps = 4,
                       poster = n, alt = "animation") {
  dir <- tempfile("frames"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE))
  for (k in seq_len(n)) {
    grDevices::png(file.path(dir, sprintf("f%04d.png", k)), width, height, res = res, bg = "white")
    draw_frame(k); grDevices::dev.off()
  }
  out <- knitr::fig_path(".mp4"); dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  status <- system2("ffmpeg", c("-y", "-loglevel", "error", "-framerate", fps, "-i", shQuote(file.path(dir, "f%04d.png")),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "30", "-movflags", "+faststart",
                                "-vf", shQuote("pad=ceil(iw/2)*2:ceil(ih/2)*2"), shQuote(out)))
  if (!identical(status, 0L)) stop("ffmpeg failed")
  pst <- sub("\\.mp4$", "-poster.png", out)
  file.copy(file.path(dir, sprintf("f%04d.png", poster)), pst, overwrite = TRUE)
  rel <- function(f) sub(".*/(?=[^/]+_files/)", "", f, perl = TRUE)   # path from the page to its figure folder
  knitr::asis_output(sprintf(paste0('<video src="%s" controls loop muted playsinline preload="metadata" poster="%s" ',
    'style="width:100%%;max-width:%dpx;display:block;margin:0 auto" aria-label="%s"></video>\n'),
    rel(out), rel(pst), width, gsub('"', "'", alt)))
}

# One frame of an evolving network on a fixed layout.
# nodes: id, x, y, col; cur: a, b, n (pairs active in this window; col optional);
# trail: list of data.frames (a, b) from earlier windows, most recent first;
# strip: counts per window, k: current window; label: the window's time.
anim_frame <- function(nodes, cur, trail = list(), strip = NULL, k = NULL, label = "", title = "", sub = "",
                       same_group = NULL, directed = FALSE, ink = "#26323A", ink_soft = "#5F6B73") {
  op <- graphics::par(mar = c(if (is.null(strip)) 1 else 3.6, 0.5, 3, 0.5)); on.exit(graphics::par(op))
  plot(NA, xlim = c(-0.04, 1.04), ylim = c(-0.04, max(0.55, max(nodes$y)) + 0.04), axes = FALSE, xlab = "", ylab = "", asp = 1)
  for (s in rev(seq_along(trail))) {
    p <- trail[[s]]; if (!nrow(p)) next
    i <- match(p$a, nodes$id); j <- match(p$b, nodes$id); ok <- !is.na(i) & !is.na(j)
    segments(nodes$x[i[ok]], nodes$y[i[ok]], nodes$x[j[ok]], nodes$y[j[ok]], col = .anim_alpha("#9AA3AA", 0.32 / s), lwd = 0.7)
  }
  active <- character(0)
  if (nrow(cur)) {
    i <- match(cur$a, nodes$id); j <- match(cur$b, nodes$id); ok <- !is.na(i) & !is.na(j)
    i <- i[ok]; j <- j[ok]; n <- cur$n[ok]
    col <- if (!is.null(cur$col)) cur$col[ok] else ifelse(nodes$col[i] == nodes$col[j], nodes$col[i], "#5F6B73")
    o <- order(n)
    segments(nodes$x[i[o]], nodes$y[i[o]], nodes$x[j[o]], nodes$y[j[o]], col = .anim_alpha(col[o], 0.8),
             lwd = 0.8 + 2.2 * pmin(n[o], 8) / 8)
    active <- unique(c(nodes$id[i], nodes$id[j]))
  }
  on <- nodes$id %in% active
  points(nodes$x[!on], nodes$y[!on], pch = 21, bg = .anim_alpha(nodes$col[!on], 0.22), col = "white", cex = 0.85, lwd = 0.5)
  points(nodes$x[on], nodes$y[on], pch = 21, bg = nodes$col[on], col = "white", cex = 1.3, lwd = 0.7)
  if (!is.null(nodes$label)) {
    lab <- which(!is.na(nodes$label))
    text(nodes$x[lab], nodes$y[lab], nodes$label[lab], cex = 0.62, col = ink, pos = 3, offset = 0.5, xpd = TRUE)
  }
  mtext(title, side = 3, adj = 0, line = 1.6, cex = 0.9, col = ink, font = 2)
  mtext(sub, side = 3, adj = 0, line = 0.5, cex = 0.66, col = ink_soft)
  mtext(label, side = 3, adj = 1, line = 1.6, cex = 1.05, col = ink, font = 2)
  if (!is.null(strip)) {   # where this window sits in the whole record
    u <- graphics::par("usr"); h <- 0.075 * diff(u[3:4]); y0 <- u[3] - 0.105 * diff(u[3:4]); m <- length(strip)
    x <- seq(u[1], u[2], length.out = m + 1)
    rect(x[-(m + 1)], y0, x[-1], y0 + h * strip / max(strip, 1), col = ifelse(seq_len(m) == k, ink, "#C9CED2"),
         border = NA, xpd = TRUE)
    text(u[1], y0 - 0.025 * diff(u[3:4]), "events per window, whole period", adj = c(0, 1), cex = 0.55, col = ink_soft, xpd = TRUE)
  }
}

# Animation straight from an event list (for the case studies).
# a, b: the two actors of each event; time: numeric; breaks: window edges;
# labels: one per window; node_col: named colours per actor (default: groups
# found on the whole span); edge_col: optional colour per event (e.g. by type).
anim_events <- function(a, b, time, breaks, labels, node_col = NULL, edge_col = NULL, n_nodes = 120,
                        node_label = NULL, title = "", sub = "", seed = 1, fps = 4, poster = NULL,
                        alt = "Animation of the network over time", palette = NULL) {
  if (is.null(palette)) palette <- c("#178E8E", "#8E7CC3", "#6FA05A", "#4F8CC9", "#C8729A", "#C99A3B",
                                     "#9C5B8E", "#5BA7B5", "#9A9A3C", "#7A8FB8")
  a <- as.character(a); b <- as.character(b)
  keep <- !is.na(time) & time >= min(breaks) & time < max(breaks) & a != b
  a <- a[keep]; b <- b[keep]; time <- time[keep]; if (!is.null(edge_col)) edge_col <- edge_col[keep]
  lo <- pmin(a, b); hi <- pmax(a, b)
  act <- sort(table(c(lo, hi)), decreasing = TRUE); top <- names(act)[seq_len(min(n_nodes, length(act)))]
  inn <- lo %in% top & hi %in% top
  top <- top[top %in% c(lo[inn], hi[inn])]   # drop actors with no tie among the others shown
  key <- paste(lo, hi, sep = "\r"); w <- table(key[inn])
  ends <- do.call(rbind, strsplit(names(w), "\r", fixed = TRUE))
  g <- igraph::graph_from_data_frame(data.frame(from = ends[, 1], to = ends[, 2], weight = as.numeric(w)),
                                     directed = FALSE, vertices = data.frame(name = top))
  set.seed(seed); xy <- igraph::layout_with_fr(g, weights = log1p(igraph::E(g)$weight), niter = 2000)
  if (nrow(xy) > 2) xy <- stats::prcomp(xy)$x[, 1:2]
  if (nrow(xy) > 20) for (j in 1:2) {   # pull far outliers in, so they do not shrink the core
    q <- stats::quantile(xy[, j], c(0.02, 0.98)); pad <- 0.08 * diff(q)
    xy[, j] <- pmin(pmax(xy[, j], q[1] - pad), q[2] + pad)
  }
  r <- max(diff(range(xy[, 1])), 1e-9); xy[, 1] <- (xy[, 1] - min(xy[, 1])) / r; xy[, 2] <- (xy[, 2] - min(xy[, 2])) / r
  col <- if (!is.null(node_col)) { cc <- node_col[top]; cc[is.na(cc)] <- "#9AA0A6"; cc } else {
    cm <- igraph::membership(igraph::cluster_louvain(g, weights = igraph::E(g)$weight))
    k <- match(cm, as.integer(names(sort(table(cm), decreasing = TRUE))))
    ifelse(k <= length(palette), palette[pmin(k, length(palette))], "#A6ABB0") }
  nodes <- data.frame(id = top, x = xy[, 1], y = xy[, 2], col = unname(col))
  if (!is.null(node_label)) nodes$label <- ifelse(top %in% names(node_label), node_label[top], NA)
  f <- findInterval(time, breaks); n <- length(breaks) - 1
  fr <- data.frame(f = f[inn], a = lo[inn], b = hi[inn], col = if (is.null(edge_col)) NA_character_ else edge_col[inn])
  agg <- function(d) {
    if (!nrow(d)) return(data.frame(a = character(0), b = character(0), n = integer(0)))
    k <- paste(d$a, d$b, sep = "\r"); t <- table(k); e <- do.call(rbind, strsplit(names(t), "\r", fixed = TRUE))
    out <- data.frame(a = e[, 1], b = e[, 2], n = as.integer(t))
    if (!all(is.na(d$col))) out$col <- d$col[match(names(t), k)]
    out
  }
  strip <- tabulate(f, n)
  anim_video(function(k) {
    anim_frame(nodes, agg(fr[fr$f == k, ]), lapply(1:3, function(s) fr[fr$f == k - s, c("a", "b")]),
               strip = strip, k = k, label = labels[k], title = title, sub = sub)
  }, n = n, fps = fps, poster = if (is.null(poster)) which.max(strip) else poster, alt = alt)
}
