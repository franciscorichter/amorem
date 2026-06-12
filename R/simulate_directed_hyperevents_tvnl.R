#' Simulate directed hyper-events with time-varying and non-linear effects
#'
#' A teaching-oriented simulator for **directed relational hyper-events** in
#' which the sender set and the receiver set are disjoint, driven by exogenous
#' group covariates with a **time-varying** effect on the sender side and a
#' **non-linear** effect on the receiver side. It is the packaged, parameterised
#' form of the workshop running example (`sunbelt-workshop-materials/running_example.R`)
#' and produces a ready-to-fit case-control dataset for GAM-based estimation of
#' smooth (TV / NL) effects.
#'
#' @details
#' Each sender (resp. receiver) *group* is a non-empty subset of the sender
#' (resp. receiver) actors -- a hyperedge endpoint. A group's covariate is the
#' mean of its members' actor attributes. For an ordered group pair
#' \eqn{(g_s, g_r)} the instantaneous rate at time \eqn{t} is
#' \deqn{\lambda_{g_s, g_r}(t) = \exp\bigl(\alpha(t)\, x_{g_s} + f(x_{g_r})\bigr),}
#' where \eqn{\alpha(t)} is the time-varying sender effect
#' (`time_varying_effect`), \eqn{f(\cdot)} is the non-linear receiver effect
#' (`nonlinear_effect`), and \eqn{x} denotes a group covariate. Events are drawn
#' on a fixed time grid of width `dt` by a thinning scheme: within each step the
#' next inter-event time is sampled from an exponential with the total rate
#' evaluated at the step midpoint, and the firing pair is chosen with
#' probability proportional to its rate. For every realised event,
#' `n_controls` non-event pairs are sampled uniformly from the remaining group
#' pairs, yielding a case-`n_controls`-control design.
#'
#' Setting `max_group_size_sender = 1` and `max_group_size_receiver = 1` reduces
#' the groups to single actors, i.e. ordinary directed dyadic events.
#'
#' @param sender_attr Named numeric vector of sender actor attributes
#'   (names are the sender ids).
#' @param receiver_attr Named numeric vector of receiver actor attributes.
#' @param time_varying_effect Function of one argument giving the time-varying
#'   coefficient \eqn{\alpha(t)} multiplying the sender-group covariate.
#'   Defaults to \code{function(t) sin(2 * t)}.
#' @param nonlinear_effect Function of one argument giving the non-linear effect
#'   \eqn{f(x)} of the receiver-group covariate. Defaults to a Gaussian bump.
#' @param horizon Positive numeric; the simulation end time (start is 0).
#' @param dt Positive numeric; the time-grid step used by the thinning scheme
#'   (must be smaller than `horizon`).
#' @param n_controls Non-negative integer; number of non-event pairs sampled per
#'   event. Defaults to 1 (a case-1-control design).
#' @param max_group_size_sender,max_group_size_receiver Integers; the largest
#'   subset size considered when enumerating sender / receiver groups. Default to
#'   the full actor sets (all non-empty subsets). Use 1 for ordinary dyadic
#'   events.
#'
#' @return A long-format data.frame, one row per (event or control), with
#'   columns \code{event_id} (links a case to its controls), \code{event_time},
#'   \code{event} (1 = realised event, 0 = sampled non-event),
#'   \code{sender_group}, \code{receiver_group} (group labels), and
#'   \code{cov_sender}, \code{cov_receiver} (group covariates). The true
#'   data-generating effect functions are attached as
#'   \code{attr(x, "truth")} (a list with `time_varying_effect`,
#'   `nonlinear_effect`, and `horizon`) for comparison against fitted smooths.
#'
#' @examples
#' set.seed(1234)
#' sa <- setNames(rnorm(4, 5, 1.5), paste0("S", 1:4))
#' ra <- setNames(rnorm(4, 3, 2.0), paste0("R", 1:4))
#' d  <- simulate_directed_hyperevents_tvnl(sa, ra, horizon = 2, n_controls = 1)
#' head(d)
#' table(d$event)
#'
#' @export
simulate_directed_hyperevents_tvnl <- function(
    sender_attr,
    receiver_attr,
    time_varying_effect = function(t) sin(2 * t),
    nonlinear_effect = function(x) -4 + 2 * exp(-((x - 3)^2) / (2 * 2^2)),
    horizon = 2,
    dt = 0.01,
    n_controls = 1L,
    max_group_size_sender = length(sender_attr),
    max_group_size_receiver = length(receiver_attr)) {

  if (!is.numeric(sender_attr) || !length(sender_attr) ||
      is.null(names(sender_attr)) || anyDuplicated(names(sender_attr))) {
    stop("`sender_attr` must be a non-empty named numeric vector with unique names.")
  }
  if (!is.numeric(receiver_attr) || !length(receiver_attr) ||
      is.null(names(receiver_attr)) || anyDuplicated(names(receiver_attr))) {
    stop("`receiver_attr` must be a non-empty named numeric vector with unique names.")
  }
  if (!is.function(time_varying_effect) || !is.function(nonlinear_effect)) {
    stop("`time_varying_effect` and `nonlinear_effect` must be functions.")
  }
  if (length(horizon) != 1 || !is.finite(horizon) || horizon <= 0) {
    stop("`horizon` must be a positive finite scalar.")
  }
  if (length(dt) != 1 || !is.finite(dt) || dt <= 0 || dt >= horizon) {
    stop("`dt` must be a positive scalar smaller than `horizon`.")
  }
  n_controls <- as.integer(n_controls)
  if (length(n_controls) != 1 || is.na(n_controls) || n_controls < 0) {
    stop("`n_controls` must be a non-negative integer.")
  }

  # Enumerate non-empty subsets (groups) up to the requested size, returning
  # the label and the mean attribute of each group.
  build_groups <- function(attr_vec, max_size) {
    ids <- names(attr_vec)
    V <- length(ids)
    max_size <- min(as.integer(max_size), V)
    if (max_size < 1L) stop("group size must be >= 1.")
    subsets <- list()
    for (k in seq_len(max_size)) {
      combs <- utils::combn(V, k, simplify = FALSE)
      for (cm in combs) subsets[[length(subsets) + 1L]] <- ids[cm]
    }
    labels <- vapply(subsets,
                     function(m) paste0("{", paste(m, collapse = ","), "}"),
                     character(1))
    covs <- vapply(subsets, function(m) mean(attr_vec[m]), numeric(1))
    list(labels = labels, cov = covs)
  }

  sg <- build_groups(sender_attr, max_group_size_sender)
  rg <- build_groups(receiver_attr, max_group_size_receiver)
  G_S <- length(sg$labels)
  G_R <- length(rg$labels)
  n_pairs <- G_S * G_R
  if (n_pairs > 1e5) {
    stop("This configuration yields ", n_pairs, " group pairs; reduce ",
         "`max_group_size_sender` / `max_group_size_receiver`.")
  }
  if (n_controls >= n_pairs) {
    stop("`n_controls` must be smaller than the number of group pairs (",
         n_pairs, ").")
  }

  # pair_grid[p, ] = (sender-group index, receiver-group index)
  pair_gs <- rep(seq_len(G_S), times = G_R)
  pair_gr <- rep(seq_len(G_R), each = G_S)
  cov_s_pair <- sg$cov[pair_gs]
  cov_r_pair <- rg$cov[pair_gr]
  f_r_pair <- nonlinear_effect(cov_r_pair)        # receiver effect (static in t)

  rate_at <- function(t) exp(time_varying_effect(t) * cov_s_pair + f_r_pair)

  # Thinning simulation on a grid of width dt.
  ev <- list()   # realised events
  nv <- list()   # sampled non-events
  event_count <- 0L
  tl <- 0
  while (tl < horizon) {
    tu <- tl + dt
    l_sr <- rate_at(tl + dt / 2)
    tot <- sum(l_sr)
    tm <- stats::rexp(1, rate = tot)
    tl_r <- tl
    dt_r <- dt
    while (tm < dt_r && tl_r < horizon) {
      event_count <- event_count + 1L
      st <- tl_r + tm
      pair_id <- sample.int(n_pairs, size = 1, prob = l_sr / tot)
      ev[[event_count]] <- data.frame(
        event_id = event_count, event_time = st, event = 1L,
        sender_group   = sg$labels[pair_gs[pair_id]],
        receiver_group = rg$labels[pair_gr[pair_id]],
        cov_sender     = cov_s_pair[pair_id],
        cov_receiver   = cov_r_pair[pair_id],
        stringsAsFactors = FALSE
      )
      if (n_controls > 0L) {
        non_ids <- sample(setdiff(seq_len(n_pairs), pair_id), n_controls)
        nv[[event_count]] <- data.frame(
          event_id = event_count, event_time = st, event = 0L,
          sender_group   = sg$labels[pair_gs[non_ids]],
          receiver_group = rg$labels[pair_gr[non_ids]],
          cov_sender     = cov_s_pair[non_ids],
          cov_receiver   = cov_r_pair[non_ids],
          stringsAsFactors = FALSE
        )
      }
      tl_r <- st
      dt_r <- tu - tl_r
      l_sr <- rate_at(tl_r + dt_r / 2)
      tot <- sum(l_sr)
      tm <- stats::rexp(1, rate = tot)
    }
    tl <- tu
  }

  out <- if (event_count == 0L) {
    data.frame(event_id = integer(0), event_time = numeric(0),
               event = integer(0), sender_group = character(0),
               receiver_group = character(0), cov_sender = numeric(0),
               cov_receiver = numeric(0), stringsAsFactors = FALSE)
  } else {
    rbind(do.call(rbind, ev), do.call(rbind, nv))
  }
  out <- out[order(out$event_time, out$event_id, -out$event), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "truth") <- list(time_varying_effect = time_varying_effect,
                             nonlinear_effect = nonlinear_effect,
                             horizon = horizon)
  out
}
