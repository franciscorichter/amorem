# Figure toolkit shared by the case-study articles: networks, hypergraphs,
# chord diagrams, ordered adjacency heatmaps, coefficient and smooth-effect
# plots. Base graphics throughout; igraph only computes layouts and groups.

pal <- c("#178E8E", "#8E7CC3", "#6FA05A", "#4F8CC9", "#C8729A", "#C99A3B",
         "#9C5B8E", "#5BA7B5", "#9A9A3C", "#7A8FB8")
ink <- "#26323A"; ink_soft <- "#5F6B73"; rule <- "#E3E6E8"
knitr::opts_chunk$set(dev.args = list(bg = "white"))

alpha <- function(col, a) {
  n <- max(length(col), length(a)); m <- grDevices::col2rgb(rep_len(col, n)) / 255
  grDevices::rgb(m[1, ], m[2, ], m[3, ], pmin(1, pmax(0, rep_len(a, n))))
}
# colours for the levels of a grouping, largest group first, grey beyond the palette
group_colours <- function(g, colours = NULL) {
  lev <- names(sort(table(g), decreasing = TRUE))
  if (is.null(colours)) colours <- setNames(c(pal, rep("#A6ABB0", max(0, length(lev) - length(pal))))[seq_along(lev)], lev)
  colours
}
fmt <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ",")
pct <- function(x, d = 1) paste0(formatC(100 * x, format = "f", digits = d), "%")
title_left <- function(main, sub = NULL) {
  mtext(main, side = 3, adj = 0, line = if (is.null(sub)) 0.3 else 1.2, cex = 0.85, col = ink, font = 2)
  if (!is.null(sub)) mtext(sub, side = 3, adj = 0, line = 0.2, cex = 0.68, col = ink_soft)
}
legend_groups <- function(colours, where = "bottomleft", title = NULL, pch = 21, ...)
  legend(where, legend = names(colours), pt.bg = colours, col = "white", pch = pch, pt.cex = 1.4,
         bty = "n", cex = 0.7, text.col = ink, title = title, title.col = ink_soft, ...)

# --- layouts and groups -------------------------------------------------------------
# edges: data.frame(from, to, w); returns nodes with x, y in [0, 1] and a Louvain group
# Isolated nodes are dropped (drop_isolates) and the drawing is rotated so its
# long axis is horizontal; y then spans [0, aspect] with aspect <= 1.
layout_graph <- function(edges, ids = NULL, directed = FALSE, seed = 1, method = c("fr", "kk", "circle"),
                         drop_isolates = TRUE) {
  method <- match.arg(method)
  if (is.null(ids)) ids <- unique(c(edges$from, edges$to))
  e <- edges[edges$from %in% ids & edges$to %in% ids & edges$from != edges$to, ]
  if (drop_isolates) ids <- ids[ids %in% c(e$from, e$to)]
  g <- igraph::graph_from_data_frame(data.frame(from = e$from, to = e$to, weight = e$w),
                                     directed = FALSE, vertices = data.frame(name = ids))
  g <- igraph::simplify(g, edge.attr.comb = list(weight = "sum"))
  set.seed(seed)
  xy <- switch(method,
    fr = igraph::layout_with_fr(g, weights = log1p(igraph::E(g)$weight), niter = 2000),
    kk = igraph::layout_with_kk(g, weights = 1 / log1p(igraph::E(g)$weight)),
    circle = igraph::layout_in_circle(g))
  if (method != "circle" && nrow(xy) > 2) xy <- stats::prcomp(xy)$x[, 1:2]
  r <- max(diff(range(xy[, 1])), 1e-9)
  xy[, 1] <- (xy[, 1] - min(xy[, 1])) / r; xy[, 2] <- (xy[, 2] - min(xy[, 2])) / r
  xy[, 2] <- xy[, 2] + (max(0.55, max(xy[, 2])) - max(xy[, 2])) / 2   # centre short drawings in a 0.55-high band
  grp <- if (igraph::ecount(g)) igraph::membership(igraph::cluster_louvain(g, weights = igraph::E(g)$weight)) else rep(1, length(ids))
  data.frame(id = ids, x = xy[, 1], y = xy[, 2], group = as.integer(grp))
}

# --- networks ---------------------------------------------------------------------
# quadratic Bezier from (x0, y0) to (x1, y1), bent to the left by `bend` of its length
.bezier <- function(x0, y0, x1, y1, bend = 0.15, n = 24) {
  mx <- (x0 + x1) / 2 - bend * (y1 - y0); my <- (y0 + y1) / 2 + bend * (x1 - x0)
  s <- seq(0, 1, length.out = n)
  list(x = (1 - s)^2 * x0 + 2 * (1 - s) * s * mx + s^2 * x1,
       y = (1 - s)^2 * y0 + 2 * (1 - s) * s * my + s^2 * y1)
}
# nodes: id, x, y, size (any scale), col, label (NA = none); edges: from, to, w, col (optional)
draw_network <- function(nodes, edges, directed = FALSE, bend = if (directed) 0.12 else 0,
                         max_lwd = 4, node_scale = c(0.6, 3.2), label_cex = 0.6, arrow = directed,
                         xlim = c(-0.06, 1.06), ylim = NULL, add = FALSE) {
  if (is.null(ylim)) ylim <- c(-0.06, max(0.55, max(nodes$y)) + 0.06)
  if (!add) plot(NA, xlim = xlim, ylim = ylim, axes = FALSE, xlab = "", ylab = "", asp = 1)
  edges <- edges[order(edges$w), ]
  i <- match(edges$from, nodes$id); j <- match(edges$to, nodes$id)
  ok <- !is.na(i) & !is.na(j) & i != j; edges <- edges[ok, ]; i <- i[ok]; j <- j[ok]
  wq <- if (nrow(edges)) log1p(edges$w) / log1p(max(edges$w)) else numeric(0)
  ecol <- if (!is.null(edges$col)) alpha(edges$col, 0.25 + 0.6 * wq) else alpha("#8C969D", 0.15 + 0.5 * wq)
  cex <- node_scale[1] + diff(node_scale) * sqrt(nodes$size / max(nodes$size))
  r <- 0.009 * cex   # node radius in plot units, for arrow heads
  for (k in seq_along(i)) {
    b <- .bezier(nodes$x[i[k]], nodes$y[i[k]], nodes$x[j[k]], nodes$y[j[k]], bend)
    if (arrow) {   # stop the curve at the target's rim and add a small head
      d <- sqrt((b$x - nodes$x[j[k]])^2 + (b$y - nodes$y[j[k]])^2); keep <- d > r[j[k]]
      b$x <- b$x[keep]; b$y <- b$y[keep]
    }
    lines(b$x, b$y, col = ecol[k], lwd = 0.3 + max_lwd * wq[k]^1.4)
    if (arrow && length(b$x) > 2) {
      n <- length(b$x); ang <- atan2(b$y[n] - b$y[n - 1], b$x[n] - b$x[n - 1]); h <- 0.010 + 0.008 * wq[k]
      polygon(b$x[n] + h * c(0, -cos(ang - 0.45), -cos(ang + 0.45)), b$y[n] + h * c(0, -sin(ang - 0.45), -sin(ang + 0.45)),
              col = ecol[k], border = NA)
    }
  }
  o <- order(nodes$size)
  points(nodes$x[o], nodes$y[o], pch = 21, bg = nodes$col[o], col = "white", cex = cex[o], lwd = 0.8)
  if (!is.null(nodes$label)) {
    lab <- which(!is.na(nodes$label))
    if (length(lab)) .repel_labels(nodes$x[lab], nodes$y[lab], nodes$label[lab], r[lab], label_cex)
  }
  invisible(nodes)
}
# labels pushed away from the centre of the drawing, then apart from each other
.repel_labels <- function(x, y, lab, r, cex) {
  cx <- mean(x); cy <- mean(y); ang <- atan2(y - cy, x - cx)
  w <- strwidth(lab, cex = cex); h <- strheight(lab, cex = cex) * 1.3
  lx <- x + (r + 0.012 + w / 2) * cos(ang); ly <- y + (r + 0.012 + h / 2) * sin(ang)
  for (it in 1:80) {
    moved <- FALSE
    for (a in seq_along(lx)) for (b in seq_along(lx)) if (a < b) {
      ox <- (w[a] + w[b]) / 2 - abs(lx[a] - lx[b]); oy <- (h[a] + h[b]) / 2 - abs(ly[a] - ly[b])
      if (ox > 0 && oy > 0) { d <- if (ly[a] >= ly[b]) 1 else -1; s <- min(oy, 0.012) / 2 + 0.001
        ly[a] <- ly[a] + d * s; ly[b] <- ly[b] - d * s; moved <- TRUE }
    }
    if (!moved) break
  }
  segments(x + r * cos(ang), y + r * sin(ang), lx - w / 2 * cos(ang), ly - h / 2 * sin(ang), col = alpha(ink_soft, 0.35), lwd = 0.5)
  text(lx, ly, lab, cex = cex, col = ink, xpd = TRUE)
}

# --- hypergraphs ------------------------------------------------------------------
# Draws hyperevents as a bipartite picture: each hyperevent is a small square,
# joined to its sender side (thick line) and receiver side (thin lines).
# hl: rows of a hyperedge_log (I, J lists); member_col: named colour per actor
draw_hypergraph <- function(hl, member_col, member_label = NULL, seed = 1, event_col = "#4A5560",
                            node_scale = c(0.5, 2.4), label_cex = 0.55) {
  ev <- paste0("e", seq_len(nrow(hl)))
  eI <- do.call(rbind, lapply(seq_len(nrow(hl)), function(k) data.frame(from = hl$I[[k]], to = ev[k], side = "I")))
  eJ <- do.call(rbind, lapply(seq_len(nrow(hl)), function(k) if (length(hl$J[[k]])) data.frame(from = hl$J[[k]], to = ev[k], side = "J")))
  e <- rbind(eI, eJ); e$w <- 1
  actors <- unique(c(eI$from, eJ$from))
  lay <- layout_graph(e, ids = c(actors, ev), seed = seed)
  xy <- setNames(seq_len(nrow(lay)), lay$id)
  plot(NA, xlim = c(-0.05, 1.05), ylim = c(-0.05, max(lay$y) + 0.05), axes = FALSE, xlab = "", ylab = "", asp = 1)
  segments(lay$x[xy[e$from]], lay$y[xy[e$from]], lay$x[xy[e$to]], lay$y[xy[e$to]],
           col = ifelse(e$side == "I", alpha(member_col[e$from], 0.75), alpha("#9AA3AA", 0.35)),
           lwd = ifelse(e$side == "I", 1.6, 0.6))
  deg <- table(e$from); a <- lay[lay$id %in% actors, ]
  cex <- node_scale[1] + diff(node_scale) * sqrt(as.numeric(deg[a$id]) / max(deg))
  points(a$x, a$y, pch = 21, bg = member_col[a$id], col = "white", cex = cex, lwd = 0.7)
  s <- lay[lay$id %in% ev, ]
  points(s$x, s$y, pch = 22, bg = "white", col = event_col, cex = 0.55 + 0.25 * sqrt(lengths(hl$J) / max(1, lengths(hl$J)))[match(s$id, ev)], lwd = 1)
  if (!is.null(member_label)) {
    k <- which(a$id %in% names(member_label))
    if (length(k)) .repel_labels(a$x[k], a$y[k], member_label[a$id[k]], 0.009 * cex[k], label_cex)
  }
  invisible(lay)
}

# --- chord diagram ----------------------------------------------------------------
# mat[i, j] = flow from group i to group j; ribbons leave i's arc and land on j's
chord <- function(mat, colours, gap = 0.03, label_cex = 0.7, min_share = 0) {
  g <- rownames(mat); n <- length(g); tot <- rowSums(mat) + colSums(mat)
  plot(NA, xlim = c(-1.3, 1.3), ylim = c(-1.3, 1.3), axes = FALSE, xlab = "", ylab = "", asp = 1)
  span <- 2 * pi - n * gap; w <- span * tot / sum(tot)
  start <- cumsum(c(0, head(w + gap, -1))) + pi / 2
  arc <- function(a0, a1, r = 1, k = 40) { s <- seq(a0, a1, length.out = k); cbind(r * cos(s), r * sin(s)) }
  out_pos <- start; in_pos <- start + w * rowSums(mat) / tot   # outgoing first, incoming after
  scale <- w / tot
  for (i in seq_len(n)) for (j in seq_len(n)) {
    v <- mat[i, j]; if (v <= 0 || v / sum(mat) < min_share) next
    a0 <- out_pos[i]; a1 <- a0 + v * scale[i]; out_pos[i] <- a1
    b0 <- in_pos[j]; b1 <- b0 + v * scale[j]; in_pos[j] <- b1
    p1 <- arc(a0, a1, 0.96); p2 <- arc(b0, b1, 0.96)
    q1 <- .bezier(p1[nrow(p1), 1], p1[nrow(p1), 2], p2[1, 1], p2[1, 2], 0, 30)
    q2 <- .bezier(p2[nrow(p2), 1], p2[nrow(p2), 2], p1[1, 1], p1[1, 2], 0, 30)
    # pull the ribbon through the centre
    pull <- function(q) { s <- seq(0, 1, length.out = length(q$x)); f <- 1 - 0.85 * sin(pi * s); list(x = q$x * f, y = q$y * f) }
    q1 <- pull(q1); q2 <- pull(q2)
    polygon(c(p1[, 1], q1$x, p2[, 1], q2$x), c(p1[, 2], q1$y, p2[, 2], q2$y),
            col = alpha(colours[g[i]], 0.45), border = alpha(colours[g[i]], 0.7), lwd = 0.4)
  }
  for (i in seq_len(n)) {
    p <- arc(start[i], start[i] + w[i], 1); q <- arc(start[i] + w[i], start[i], 1.06)
    polygon(c(p[, 1], q[, 1]), c(p[, 2], q[, 2]), col = colours[g[i]], border = NA)
    m <- start[i] + w[i] / 2
    text(1.17 * cos(m), 1.17 * sin(m), g[i], cex = label_cex, col = ink,
         adj = c(ifelse(cos(m) < -0.2, 1, ifelse(cos(m) > 0.2, 0, 0.5)), 0.5), xpd = TRUE)
  }
}

# --- ordered adjacency heatmap ----------------------------------------------------
heat_adjacency <- function(mat, groups = NULL, colours = NULL, col_hi = "#178E8E", label_cex = 0.45, log = TRUE) {
  n <- nrow(mat); v <- if (log) log1p(mat) else mat
  op <- par(mar = c(1, 6, 1, 1)); on.exit(par(op))
  ramp <- grDevices::colorRampPalette(c("#FFFFFF", alpha(col_hi, 0.35), col_hi, "#0B4F4F"))(64)
  image(seq_len(n), seq_len(n), t(v[n:1, ]), col = ramp, axes = FALSE, xlab = "", ylab = "", useRaster = TRUE)
  if (!is.null(groups)) {
    cut <- which(head(groups, -1) != tail(groups, -1)) + 0.5
    abline(v = cut, h = n + 1 - cut, col = ink_soft, lwd = 0.6)
    if (!is.null(colours)) rect(-0.02 * n, n:1 - 0.5, 0.005 * n, n:1 + 0.5, col = colours[as.character(groups)], border = NA, xpd = TRUE)
  }
  if (n <= 80) axis(2, at = n:1, labels = rownames(mat), las = 1, tick = FALSE, cex.axis = label_cex, line = -0.4)
}

# --- model output -----------------------------------------------------------------
# est, se: named vectors; draws estimate and 95% interval per term
forest <- function(est, se, labels = names(est), col = pal[1], xlab = "effect on the log-rate", ref = 0) {
  k <- length(est); y <- k:1
  lo <- est - 1.96 * se; hi <- est + 1.96 * se
  op <- par(mar = c(3.4, max(nchar(labels)) * 0.42 + 1, 1.2, 1)); on.exit(par(op))
  plot(est, y, xlim = range(c(lo, hi, ref)), ylim = c(0.5, k + 0.5), axes = FALSE, xlab = "", ylab = "", type = "n")
  abline(v = ref, col = rule, lwd = 1.2)
  segments(lo, y, hi, y, col = col, lwd = 2.2)
  points(est, y, pch = 21, bg = "white", col = col, cex = 1.3, lwd = 1.6)
  axis(1, tick = FALSE, cex.axis = 0.75, col.axis = ink_soft, line = -0.5)
  axis(2, at = y, labels = labels, las = 1, tick = FALSE, cex.axis = 0.75, col.axis = ink, line = -0.6)
  mtext(xlab, side = 1, line = 2, cex = 0.75, col = ink_soft)
}
# the curve and standard error of smooth term `select` of an mgcv fit
smooth_data <- function(gamfit, select) {
  grDevices::pdf(NULL); on.exit(grDevices::dev.off())
  pd <- plot(gamfit, select = select, se = TRUE, rug = FALSE)[[select]]
  data.frame(x = pd$x, fit = as.numeric(pd$fit), se = as.numeric(pd$se) / 2)   # plot.gam se is 2 s.e.
}
draw_smooth <- function(d, col = pal[1], xlab = "", ylab = "effect on the log-rate", add = FALSE, ylim = NULL, rug = NULL) {
  lo <- d$fit - 1.96 * d$se; hi <- d$fit + 1.96 * d$se
  if (!add) {
    plot(d$x, d$fit, type = "n", ylim = if (is.null(ylim)) range(lo, hi, 0) else ylim, axes = FALSE, xlab = "", ylab = "")
    abline(h = 0, col = rule, lwd = 1.2)
    axis(1, tick = FALSE, cex.axis = 0.75, col.axis = ink_soft, line = -0.5)
    axis(2, las = 1, tick = FALSE, cex.axis = 0.75, col.axis = ink_soft, line = -0.5)
    mtext(xlab, side = 1, line = 2, cex = 0.75, col = ink_soft); mtext(ylab, side = 2, line = 2.3, cex = 0.75, col = ink_soft)
  }
  polygon(c(d$x, rev(d$x)), c(lo, rev(hi)), col = alpha(col, 0.18), border = NA)
  lines(d$x, d$fit, col = col, lwd = 2.2)
  if (!is.null(rug)) rug(rug, col = alpha(ink_soft, 0.25), ticksize = 0.02)
}
