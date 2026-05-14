# data-raw/social_evolution.R
# Build the tidy `social_evolution_calls`, `social_evolution_actors`, and
# `social_evolution_friendship` data objects from the goldfish-format
# RData file shipped under inst/extdata/social_evolution/
# (source: Madan et al. 2011, IEEE Pervasive Computing; redistributed via
# the goldfish R package, github.com/snlab-ch/goldfish).

env <- new.env()
load("inst/extdata/social_evolution/Social_Evolution.RData", envir = env)

raw_actors <- env$actors
raw_calls  <- env$calls
raw_fr     <- env$friendship

social_evolution_actors <- data.frame(
  id        = as.character(raw_actors$label),
  present   = as.logical(raw_actors$present),
  floor     = as.integer(raw_actors$floor),
  gradeType = factor(raw_actors$gradeType,
                     levels = sort(unique(raw_actors$gradeType))),
  stringsAsFactors = FALSE
)

social_evolution_calls <- data.frame(
  time      = as.numeric(raw_calls$time),
  sender    = as.character(raw_calls$sender),
  receiver  = as.character(raw_calls$receiver),
  increment = as.integer(raw_calls$increment),
  stringsAsFactors = FALSE
)
social_evolution_calls <- social_evolution_calls[order(social_evolution_calls$time), ]
rownames(social_evolution_calls) <- NULL

social_evolution_friendship <- data.frame(
  time     = as.numeric(raw_fr$time),
  sender   = as.character(raw_fr$sender),
  receiver = as.character(raw_fr$receiver),
  replace  = as.integer(raw_fr$replace),
  stringsAsFactors = FALSE
)
social_evolution_friendship <-
  social_evolution_friendship[order(social_evolution_friendship$time), ]
rownames(social_evolution_friendship) <- NULL

# Rebase both event streams to days since the first call (matches the
# unit used in the paper, Figure 6). Original Unix timestamps are kept
# as an attribute on each frame.
unix_origin <- min(social_evolution_calls$time)
attr(social_evolution_calls, "unix_origin")      <- unix_origin
attr(social_evolution_friendship, "unix_origin") <- unix_origin
social_evolution_calls$time      <- (social_evolution_calls$time      - unix_origin) / 86400
social_evolution_friendship$time <- (social_evolution_friendship$time - unix_origin) / 86400

usethis::use_data(
  social_evolution_calls,
  social_evolution_actors,
  social_evolution_friendship,
  overwrite = TRUE, compress = "xz"
)
