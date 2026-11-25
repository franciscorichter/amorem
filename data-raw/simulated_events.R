# data-raw/simulated_events.R
# Build `simulated_events`, the event log used by the package examples and
# tests: 600 directed events among 20 actors from the Gillespie simulator with
# a reciprocity and a transitivity effect. Run from the package root with
# pkgload::load_all().
set.seed(20261125)
a <- sprintf("a%02d", 1:20)
sim <- simulate_relational_events(
  n_events = 600, senders = a, receivers = a,
  endogenous_stats   = c("reciprocity_binary", "transitivity_binary"),
  endogenous_effects = c(reciprocity_binary = 1.5, transitivity_binary = 0.8),
  n_controls = 0)
simulated_events <- data.frame(time = sim$time, sender = sim$sender,
                               receiver = sim$receiver, stringsAsFactors = FALSE)
usethis::use_data(simulated_events, overwrite = TRUE, compress = "xz")
