# Views of a dataset for the catalogue figures: what the events look like, not
# only their statistics. Everything returned is an aggregate (pair counts,
# events binned in time, cumulative counts on a grid), never an event row.
suppressPackageStartupMessages(library(data.table))

.prep_dyadic <- function(obj) {
  e <- as.data.table(obj$events)[, .(sender = as.character(sender), receiver = as.character(receiver),
                                      time = as.numeric(time))]
  e <- e[!is.na(time) & sender != receiver]
  if (!obj$directed) e[, c("sender", "receiver") := .(pmin(sender, receiver), pmax(sender, receiver))]
  setorder(e, time)
  e
}

# Network of the most active actors, laid out and split into communities
.view_network <- function(e, directed, n_net, seed) {
  act <- sort(table(c(e$sender, e$receiver)), decreasing = TRUE)
  # nodes: the endpoints of the busiest pairs, taken in order until n_net actors
  pc <- e[, .(n = .N), by = .(a = pmin(sender, receiver), b = pmax(sender, receiver))][order(-n)]
  ends <- unique(as.vector(rbind(pc$a, pc$b)))
  top <- ends[seq_len(min(n_net, length(ends)))]
  w <- e[sender %in% top & receiver %in% top, .(n = .N), by = .(sender, receiver)]
  in_top <- sum(w$n)
  # backbone: each actor's three strongest ties (pairs merged over direction for the choice)
  w[, k := paste(pmin(sender, receiver), pmax(sender, receiver))]
  pk <- w[, .(n = sum(n), a = pmin(sender, receiver)[1], b = pmax(sender, receiver)[1]), by = k]
  keep <- unique(unlist(lapply(top, function(x) { r <- pk[a == x | b == x]; head(r[order(-n)]$k, 3) })))
  w <- w[k %in% keep][, k := NULL]
  g <- igraph::graph_from_data_frame(w, directed = directed, vertices = data.frame(name = top))
  gu <- if (directed) igraph::as_undirected(g, mode = "collapse", edge.attr.comb = list(n = "sum")) else g
  set.seed(seed)
  lay <- igraph::layout_with_fr(gu, weights = log1p(igraph::E(gu)$n))
  lay <- apply(lay, 2, function(v) (v - min(v)) / max(diff(range(v)), 1e-9))
  comm <- if (igraph::ecount(gu)) igraph::membership(igraph::cluster_louvain(gu, weights = igraph::E(gu)$n)) else rep(1, length(top))
  # communities numbered by size, largest first
  comm <- match(comm, as.integer(names(sort(table(comm), decreasing = TRUE))))
  list(nodes = data.frame(id = top, x = lay[, 1], y = lay[, 2], activity = as.integer(act[top]),
                          community = as.integer(comm)),
       edges = as.data.frame(w),
       n_actors = length(act), share_events = in_top / nrow(e), n_ties = nrow(pk), n_backbone = length(keep))
}

# Time bins of a natural width (minute, hour, day, week, ...) aligned to the clock,
# at most n_bins of them; falls back to equal bins when the unit has no clock.
.nice_breaks <- function(t0, t1, obj, n_bins) {
  u <- obj$time_unit
  sec <- switch(u, seconds = 1, days = 86400, "days from start" = 86400, years = 365.25 * 86400, NA)
  if (is.na(sec) || t1 <= t0) return(seq(t0, t1, length.out = n_bins + 1))
  widths <- c(1, 10, 60, 300, 900, 3600, 3 * 3600, 6 * 3600, 86400, 7 * 86400, 30.4375 * 86400, 365.25 * 86400,
              5 * 365.25 * 86400, 10 * 365.25 * 86400)
  w <- widths[which(widths >= (t1 - t0) * sec / n_bins)[1]]
  if (is.na(w)) return(seq(t0, t1, length.out = n_bins + 1))
  # clock offset of time 0, so that days start at local midnight
  off <- 0
  if (!is.null(obj$origin)) {
    o <- as.POSIXlt(obj$origin, tz = if (is.null(obj$tz)) "UTC" else obj$tz)
    off <- o$hour * 3600 + o$min * 60 + o$sec
  } else if (u == "days") off <- 0
  wu <- w / sec; offu <- off / sec
  start <- floor((t0 + offu) / wu) * wu - offu
  seq(start, t1 + wu, by = wu)
}

view_dyadic <- function(obj, n_net = 60, n_rows = 30, n_bins = 300, n_pairs = 6, n_grid = 400, seed = 1) {
  e <- .prep_dyadic(obj)
  net <- .view_network(e, obj$directed, n_net, seed)
  nd <- net$nodes
  rows <- head(nd[order(-nd$activity), ], n_rows)   # the most active of the network's actors
  rows <- rows[order(rows$community, -rows$activity), ]
  t0 <- min(e$time); t1 <- max(e$time)
  br <- .nice_breaks(t0, t1, obj, n_bins)
  tl <- e[sender %in% rows$id & receiver %in% rows$id]
  tl[, bin := findInterval(time, br, all.inside = TRUE)]
  timeline <- tl[, .(n = .N), by = .(bin, sender, receiver)]
  all_bins <- tabulate(findInterval(e$time, br, all.inside = TRUE), length(br) - 1)
  # heatmap: events of each row actor per time bin
  hm <- rbind(e[sender %in% rows$id, .(id = sender, time)], e[receiver %in% rows$id, .(id = receiver, time)])
  hm[, bin := findInterval(time, br, all.inside = TRUE)]
  hm <- hm[, .(n = .N), by = .(id, bin)]
  # zoom: the busiest window, as wide as possible while holding at most zoom_max events among the rows
  zoom_max <- 160; z0 <- t0; wdt <- t1 - t0
  if (nrow(tl) > zoom_max) {
    for (f in c(1/4, 1/10, 1/40, 1/100, 1/300, 1/1000, 1/3000, 1/10000, 1/30000)) {
      wdt <- (t1 - t0) * f
      cnt <- findInterval(tl$time + wdt, tl$time) - seq_len(nrow(tl)) + 1
      if (max(cnt) <= zoom_max || f == 1/30000) { z0 <- tl$time[which.max(cnt)]; break }
    }
  }
  zb <- seq(z0, z0 + wdt, length.out = 401)
  zt <- tl[time >= z0 & time <= z0 + wdt]
  zt[, bin := findInterval(time, zb, all.inside = TRUE)]
  zoom <- zt[, .(n = .N), by = .(bin, sender, receiver)]
  # counting processes N_ij(t) of the busiest pairs
  pc <- e[, .(n = .N), by = .(sender, receiver)][order(-n)]
  top_pairs <- head(pc, n_pairs)
  grid <- seq(t0, t1, length.out = n_grid)
  counts <- sapply(seq_len(nrow(top_pairs)), function(k) {
    tt <- e[sender == top_pairs$sender[k] & receiver == top_pairs$receiver[k], time]
    findInterval(grid, tt)
  })
  list(network = net,
       rows = rows[, c("id", "community", "activity")],
       timeline = as.data.frame(timeline), heat = as.data.frame(hm), breaks = br, bin_total = all_bins,
       zoom = as.data.frame(zoom), zoom_breaks = zb, zoom_total = nrow(zt),
       pairs = as.data.frame(top_pairs), grid = grid, counts = counts,
       n_events = nrow(e), n_pairs_total = nrow(pc), directed = obj$directed)
}

view_hyper <- function(obj, n_rows = 40, n_bins = 300, n_zoom = 60, seed = 1) {
  e <- obj$events; e <- e[order(e$time), ]
  members <- function(i) unique(c(e$I[[i]], if (!is.null(e$J)) e$J[[i]]))
  allm <- lapply(seq_len(nrow(e)), members)
  act <- sort(table(unlist(allm)), decreasing = TRUE)
  top <- names(act)[seq_len(min(n_rows, length(act)))]
  # co-membership network of the top actors, for ordering rows by community
  pairs <- rbindlist(lapply(allm, function(m) { m <- sort(intersect(m, top))
    if (length(m) < 2) return(NULL); cb <- utils::combn(m, 2); data.table(a = cb[1, ], b = cb[2, ]) }))
  comm <- rep(1L, length(top)); names(comm) <- top
  if (nrow(pairs)) {
    w <- pairs[, .(n = .N), by = .(a, b)]
    g <- igraph::graph_from_data_frame(w, directed = FALSE, vertices = data.frame(name = top))
    set.seed(seed); cm <- igraph::membership(igraph::cluster_louvain(g, weights = igraph::E(g)$n))
    comm[] <- match(cm, as.integer(names(sort(table(cm), decreasing = TRUE))))
  }
  rows <- data.frame(id = top, community = as.integer(comm), activity = as.integer(act[top]))
  rows <- rows[order(rows$community, -rows$activity), ]
  br <- .nice_breaks(min(e$time), max(e$time), obj, n_bins)
  bin <- findInterval(e$time, br, all.inside = TRUE)
  inc <- rbindlist(lapply(seq_len(nrow(e)), function(i) { m <- intersect(allm[[i]], top)
    if (!length(m)) NULL else data.table(bin = bin[i], id = m) }))
  raster <- inc[, .(n = .N), by = .(bin, id)]
  # zoom: n_zoom consecutive hyperevents around the busiest bin, drawn one by one
  mid <- which(bin == which.max(tabulate(bin, length(br) - 1)))[1]
  idx <- seq(max(1, mid - n_zoom %/% 2), min(nrow(e), max(1, mid - n_zoom %/% 2) + n_zoom - 1))
  zoom <- lapply(idx, function(i) list(I = intersect(e$I[[i]], top),
                                        J = if (!is.null(e$J)) intersect(e$J[[i]], top) else character(0),
                                        size = length(allm[[i]]), n_I = length(unique(e$I[[i]]))))
  list(rows = rows, raster = as.data.frame(raster), breaks = br, bin_total = tabulate(bin, length(br) - 1),
       zoom = zoom, zoom_time = range(e$time[idx]), n_events = nrow(e), n_actors = length(act))
}

# Frames for an animation of the evolving network: pair counts per time window
# among the most active actors of the chosen span, on a layout fixed for the
# whole span. span = "all", "day" or "week" (the busiest calendar day or week);
# width is the window length in the object's time unit.
view_frames <- function(obj, width, span = c("all", "day", "week"), n_nodes = 120, group_of = NULL, seed = 1) {
  span <- match.arg(span)
  e <- if (obj$kind == "hyper") {
    ev <- obj$events
    rbindlist(lapply(seq_len(nrow(ev)), function(k) {
      J <- if (!is.null(ev$J)) ev$J[[k]] else character(0); I <- ev$I[[k]]
      if (length(J)) CJ(sender = as.character(I), receiver = as.character(J))[, time := as.numeric(ev$time[k])]
      else if (length(I) > 1) { cb <- utils::combn(sort(as.character(I)), 2); data.table(sender = cb[1, ], receiver = cb[2, ], time = as.numeric(ev$time[k])) }
    }))
  } else as.data.table(obj$events)[, .(sender = as.character(sender), receiver = as.character(receiver), time = as.numeric(time))]
  e <- e[!is.na(time) & sender != receiver]
  e[, `:=`(a = pmin(sender, receiver), b = pmax(sender, receiver))]
  setorder(e, time)
  u <- obj$time_unit; sec <- switch(u, seconds = 1, days = 86400, years = 365.25 * 86400, NA)
  clock <- !is.null(obj$origin) || (u == "days")
  tz <- if (is.null(obj$tz)) "UTC" else obj$tz
  to_time <- function(t) if (!is.null(obj$origin)) as.POSIXct(as.numeric(obj$origin) + t * sec, origin = "1970-01-01", tz = tz)
                         else if (u == "days") as.POSIXct(t * 86400, origin = "1970-01-01", tz = "UTC") else NULL
  # span
  if (span != "all") {
    len <- if (span == "day") 86400 else 7 * 86400
    if (clock) { ct <- to_time(e$time)
      key <- if (span == "day") as.Date(ct, tz = tz) else as.Date(cut(as.Date(ct, tz = tz), "week"))
      best <- names(which.max(table(key))); e <- e[as.character(key) == best]
      s0 <- (as.numeric(as.POSIXct(paste(best, "00:00:00"), tz = tz)) - if (is.null(obj$origin)) 0 else as.numeric(obj$origin)) / sec
      if (u == "days" && is.null(obj$origin)) s0 <- as.numeric(as.Date(best))
    } else { key <- floor(e$time * sec / len); best <- as.numeric(names(which.max(table(key)))); e <- e[key == best]; s0 <- best * len / sec }
    s1 <- s0 + len / sec
    # trim to the hours with events
    s0 <- s0 + floor((min(e$time) - s0) / width) * width; s1 <- min(s1, max(e$time) + width)
  } else { s0 <- floor(min(e$time) / width) * width; s1 <- max(e$time) + width }
  br <- seq(s0, s1, by = width); e[, f := findInterval(time, br)]; e <- e[f >= 1 & f < length(br)]
  # nodes and layout
  act <- sort(table(c(e$a, e$b)), decreasing = TRUE); top <- names(act)[seq_len(min(n_nodes, length(act)))]
  w <- e[a %in% top & b %in% top, .(n = .N), by = .(a, b)]
  g <- igraph::graph_from_data_frame(w, directed = FALSE, vertices = data.frame(name = top))
  set.seed(seed); xy <- igraph::layout_with_fr(g, weights = log1p(igraph::E(g)$n), niter = 2000)
  if (nrow(xy) > 2) xy <- stats::prcomp(xy)$x[, 1:2]
  r <- max(diff(range(xy[, 1])), 1e-9); xy[, 1] <- (xy[, 1] - min(xy[, 1])) / r; xy[, 2] <- (xy[, 2] - min(xy[, 2])) / r
  grp <- if (!is.null(group_of)) group_of(top) else {
    cm <- igraph::membership(igraph::cluster_louvain(g, weights = igraph::E(g)$n))
    match(cm, as.integer(names(sort(table(cm), decreasing = TRUE)))) }
  nodes <- data.frame(id = top, x = xy[, 1], y = xy[, 2], group = grp, activity = as.integer(act[top]))
  frames <- as.data.frame(e[a %in% top & b %in% top, .(n = .N), by = .(f, a, b)])
  # window labels
  st <- head(br, -1)
  lab <- if (clock) { ct <- to_time(st); wsec <- width * sec
    if (wsec < 86400) format(ct, if (span == "day") "%a %d %b %Y, %H:%M" else "%a %d %b %Y, %H:%M")
    else if (wsec < 60 * 86400) format(ct, "%d %b %Y")
    else if (wsec < 365 * 86400) format(ct, "%b %Y")
    else paste0(format(ct, "%Y"), "–", format(to_time(st + width) - 86400, "%Y")) }
  else if (u == "years") { if (width == 1) format(st) else paste0(st, "–", st + width - 1) }
  else if (u == "seconds") sprintf("day %d, %02d:%02d from start", floor(st / 86400) + 1, floor((st %% 86400) / 3600), floor((st %% 3600) / 60))
  else format(signif(st, 6))
  list(nodes = nodes, frames = frames, labels = lab, strip = tabulate(e$f, length(br) - 1),
       width = width, span = span, n_events = nrow(e), clock = clock)
}
