# figures_datasets.R
# Produces a panel of descriptive figures for the three bundled
# real-world datasets shipped with amore. Outputs to paper/figures/.

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(igraph); library(ggplot2); library(ggraph)
})

theme_set(theme_minimal(base_size = 9) +
          theme(panel.grid.minor = element_blank()))

# ---------- Helpers ----------------------------------------------------------

cumulative_events <- function(ev, title, x_unit) {
  df <- data.frame(time = sort(ev$time), n = seq_len(nrow(ev)))
  ggplot(df, aes(time, n)) +
    geom_step(linewidth = 0.35, colour = "#1f3a5f") +
    labs(title = title, x = paste0("Time (", x_unit, ")"),
         y = "Cumulative events") +
    theme(plot.title = element_text(size = 9, face = "bold"))
}

ied_histogram <- function(ev, title) {
  iet <- diff(sort(ev$time))
  iet <- iet[iet > 0]
  df <- data.frame(iet = iet)
  ggplot(df, aes(iet)) +
    geom_histogram(bins = 40, fill = "#1f3a5f", colour = "white",
                   linewidth = 0.15) +
    scale_x_log10() +
    labs(title = title, x = "Inter-event time (log scale)", y = "Count") +
    theme(plot.title = element_text(size = 9, face = "bold"))
}

# ---------- 1. Classroom network --------------------------------------------

data(classroom_events); data(classroom_actors)
edge_df <- aggregate(time ~ sender + receiver, classroom_events,
                     FUN = length)
names(edge_df)[3] <- "weight"
g <- graph_from_data_frame(edge_df, directed = TRUE,
                            vertices = data.frame(
                              name = classroom_actors$id,
                              sex  = as.character(classroom_actors$sex),
                              role = as.character(classroom_actors$role)))
V(g)$label <- V(g)$name
set.seed(42)

p_class <- ggraph(g, layout = "stress") +
  geom_edge_link(aes(width = weight),
                 arrow = arrow(length = unit(1.4, "mm"), type = "closed"),
                 end_cap = circle(2.4, "mm"),
                 alpha = 0.35, colour = "#7d7d7d") +
  scale_edge_width(range = c(0.1, 1.3), guide = "none") +
  geom_node_point(aes(colour = role, shape = sex), size = 4) +
  geom_node_text(aes(label = label), size = 2.4, vjust = -1.0) +
  scale_colour_manual(values = c(instructor = "#d62728",
                                  grade_11   = "#1f77b4",
                                  grade_12   = "#2ca02c"),
                      name = "Role") +
  scale_shape_manual(values = c(F = 16, M = 17), name = "Sex") +
  labs(title = "Classroom: 691 directed interactions, 20 actors",
       subtitle = "McFarland (2001) — edges scaled by event count") +
  theme_void(base_size = 9) +
  theme(legend.position = "right",
        plot.title    = element_text(face = "bold", size = 10),
        plot.subtitle = element_text(size = 8, colour = "grey40"))

ggsave("paper/figures/classroom_network.pdf", p_class,
       width = 6.4, height = 4.4)
cat("Wrote classroom_network.pdf\n")

# ---------- 2. Cumulative-events panel --------------------------------------

data(social_evolution_calls); data(radoslaw_email)
re_clean <- radoslaw_email[radoslaw_email$sender != radoslaw_email$receiver, ]

pdf("paper/figures/cumulative_events.pdf", width = 7.2, height = 2.6)
op <- par(mfrow = c(1, 3), mar = c(4, 4, 2.4, 1), cex.axis = 0.8, las = 1)
plot(sort(classroom_events$time), seq_len(nrow(classroom_events)),
     type = "s", col = "#1f3a5f", lwd = 1,
     xlab = "Time (minutes)", ylab = "Cumulative events",
     main = "Classroom (n = 691)")
plot(sort(social_evolution_calls$time), seq_len(nrow(social_evolution_calls)),
     type = "s", col = "#1f3a5f", lwd = 1,
     xlab = "Time (days)", ylab = "Cumulative events",
     main = "Social Evolution (n = 439)")
plot(sort(re_clean$time), seq_len(nrow(re_clean)),
     type = "s", col = "#1f3a5f", lwd = 0.6,
     xlab = "Time (days)", ylab = "Cumulative events",
     main = "Radoslaw (n = 82,876)")
par(op); dev.off()
cat("Wrote cumulative_events.pdf\n")

# ---------- 3. Inter-event time distributions -------------------------------

pdf("paper/figures/inter_event.pdf", width = 7.2, height = 2.4)
op <- par(mfrow = c(1, 3), mar = c(4, 4, 2.4, 1), cex.axis = 0.8, las = 1)
for (dat in list(
    list(ev = classroom_events,         lbl = "Classroom",        unit = "min"),
    list(ev = social_evolution_calls,   lbl = "Social Evolution", unit = "days"),
    list(ev = re_clean,                 lbl = "Radoslaw",         unit = "days"))) {
  iet <- diff(sort(dat$ev$time)); iet <- iet[iet > 0]
  hist(log10(iet), breaks = 40, col = "#9bb7d4", border = "white",
       main = dat$lbl,
       xlab = sprintf("log10 inter-event time (%s)", dat$unit),
       ylab = "Count")
}
par(op); dev.off()
cat("Wrote inter_event.pdf\n")

# ---------- 4. Radoslaw sender activity heatmap (first 30 days) -------------

re30 <- re_clean[re_clean$time < 30, ]
top <- names(sort(table(c(re30$sender, re30$receiver)), decreasing = TRUE))[1:40]
re30s <- re30[re30$sender %in% top & re30$receiver %in% top, ]
re30s$sender   <- factor(re30s$sender,   levels = top)
re30s$receiver <- factor(re30s$receiver, levels = top)
tab <- table(re30s$sender, re30s$receiver)
pdf("paper/figures/radoslaw_heatmap.pdf", width = 5.6, height = 4.6)
op <- par(mar = c(3, 3, 2.2, 4), cex.axis = 0.55)
image(log1p(t(tab)), axes = FALSE,
      col = hcl.colors(50, "Blues 3", rev = TRUE),
      main = "Radoslaw 30-day slice: log(1 + count) of (sender, receiver)")
axis(1, at = seq(0, 1, length.out = length(top)), labels = top, las = 2)
axis(2, at = seq(0, 1, length.out = length(top)), labels = top, las = 2)
mtext("receiver", side = 2, line = 2)
mtext("sender",   side = 1, line = 2)
par(op); dev.off()
cat("Wrote radoslaw_heatmap.pdf\n")
