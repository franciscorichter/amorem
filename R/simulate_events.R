#' Simulate relational event sequences
#'
#' Generate a simple relational event log for a sender set and receiver set
#' using a softmax allocation rule over dyadic intensities. The process follows
#' the Gillespie algorithm, where the time between events is drawn from an
#' exponential distribution with rate equal to the sum of all dyadic intensities.
#'
#' @param n_events Number of events to generate.
#' @param senders Character vector listing the sender set \eqn{\mathcal{S}}.
#' @param receivers Character vector listing the receiver set \eqn{\mathcal{R}}.
#' @param baseline_rate Positive scalar. A constant baseline hazard multiplier
#'   applied to all dyads. Defaults to 1.
#' @param start_time Initial time stamp.
#' @param horizon Optional maximum horizon; simulation stops once the cumulative
#'   time would exceed this value.
#' @param contribution_logits Optional \code{length(senders) x length(receivers)}
#'   matrix of dyad-level contributions to the log-rate (i.e. the dyad-specific
#'   part of the linear predictor, distinct from the baseline hazard). Defaults
#'   to zeros.
#' @param sender_covariates Optional numeric data.frame/matrix with one row per
#'   sender.
#' @param sender_effects Optional numeric vector of coefficients for
#'   \code{sender_covariates}. Required when sender covariates are supplied.
#' @param receiver_covariates Optional numeric data.frame/matrix with one row per
#'   receiver.
#' @param receiver_effects Optional numeric vector of coefficients for
#'   \code{receiver_covariates}. Required when receiver covariates are supplied.
#' @param allow_loops Logical; whether sender and receiver can coincide.
#' @param n_controls Integer; number of non-events (controls) to sample
#'   uniformly at random for each realized event. If \code{n_controls > 0}, the
#'   function returns a case-control data frame suitable for conditional logistic
#'   regression / GAM modeling. Defaults to 0.
#' @param endogenous_stats Optional character vector of endogenous mechanisms to
#'   include in the rate. Each entry updates a state matrix after every event so
#'   the intensity of the next event depends on the realized history. Supported
#'   values:
#'   \itemize{
#'     \item \code{"reciprocity_count"} — number of past reverse-dyad events.
#'     \item \code{"reciprocity_binary"} — 1 if the reverse dyad has fired at
#'       least once, 0 otherwise.
#'     \item \code{"reciprocity_exp_decay"} — sum of past reverse-dyad events
#'       with exponential half-life decay (requires \code{half_life}).
#'     \item \code{"transitivity_exp_decay"} —
#'       \eqn{\sum_{k} e^{-(t - t^{(s,k,r)}_{\text{form}}) \log 2 / T}}
#'       where \eqn{t^{(s,k,r)}_{\text{form}}} is the formation time of
#'       two-path \eqn{s \to k \to r} (definition \eqn{t^{(5c)}} of
#'       Juozaitienė & Wit, 2024). Requires \code{half_life}.
#'     \item \code{"transitivity_exp_decay_ordered"} — same as
#'       \code{"transitivity_exp_decay"} but only counts \emph{ordered}
#'       two-paths (s → k strictly before k → r), definition
#'       \eqn{t^{(6c)}}.  Requires \code{half_life}.
#'     \item \code{"reciprocity_time_recent"} — elapsed time since the most
#'       recent reverse-dyad event \eqn{t - t_{\text{recent}}(r,s)}; reports
#'       \code{0} for dyads whose reverse has never fired (rather than the
#'       post-hoc \code{NA}, so the rate computation stays numeric).
#'     \item \code{"reciprocity_time_first"} — elapsed time since the
#'       \emph{first} reverse-dyad event \eqn{t - t_{\text{first}}(r,s)};
#'       same \code{0}-for-never-seen convention.
#'     \item \code{"recency"} — elapsed time on the same ordered dyad
#'       \eqn{t - t_{\text{last}}(s,r)}, defaulting to
#'       \eqn{t - \text{start\_time}} for dyads that have never fired.
#'     \item \code{"sender_outdegree"} — total number of events previously sent
#'       by \eqn{s} (constant across receivers).
#'     \item \code{"receiver_indegree"} — total number of events previously
#'       received by \eqn{r} (constant across senders).
#'     \item \code{"transitivity_count"} / \code{"transitivity_binary"} —
#'       number of intermediaries \eqn{k} (or indicator that at least one
#'       exists) for which both \eqn{(s,k)} and \eqn{(k,r)} have fired.
#'     \item \code{"cyclic_count"} / \code{"cyclic_binary"} — number of
#'       intermediaries \eqn{k} (or indicator) for which both \eqn{(r,k)} and
#'       \eqn{(k,s)} have fired (cyclic two-path closing \eqn{s \to r}).
#'     \item \code{"sending_balance_count"} / \code{"sending_balance_binary"} —
#'       number of shared targets \eqn{k} (or indicator) where both
#'       \eqn{(s,k)} and \eqn{(r,k)} have fired.
#'     \item \code{"receiving_balance_count"} /
#'       \code{"receiving_balance_binary"} — number of shared sources
#'       \eqn{k} (or indicator) where both \eqn{(k,s)} and \eqn{(k,r)} have
#'       fired.
#'     \item \code{"transitivity_time_recent"} — elapsed time since the most
#'       recent two-path \eqn{s \to k \to r} was completed, for any
#'       intermediary \eqn{k} (definition 7ac of Juozaitienė & Wit, 2024).
#'       Reports \code{0} for dyads where no two-path has ever existed.
#'     \item \code{"transitivity_time_first"} — elapsed time since the
#'       \emph{first} two-path \eqn{s \to k \to r} was completed
#'       (definition 7bc of Juozaitienė & Wit, 2024). Same
#'       \code{0}-for-never-seen convention.
#'     \item \code{"cyclic_time_recent"} / \code{"cyclic_time_first"} —
#'       elapsed time since the most recent / first cyclic two-path
#'       \eqn{r \to k \to s} was completed.
#'     \item \code{"sending_balance_time_recent"} /
#'       \code{"sending_balance_time_first"} — elapsed time since the
#'       most recent / first shared-target two-path
#'       \eqn{s \to k,\ r \to k} was completed.
#'     \item \code{"receiving_balance_time_recent"} /
#'       \code{"receiving_balance_time_first"} — elapsed time since the
#'       most recent / first shared-source two-path
#'       \eqn{k \to s,\ k \to r} was completed.
#'     \item \code{"transitivity_count_ordered"} /
#'       \code{"transitivity_binary_ordered"} — number of intermediaries
#'       \eqn{k} (or indicator) for which an ordered two-path
#'       \eqn{s \to k} \emph{before} \eqn{k \to r} has been observed
#'       (definitions \eqn{t^{(4c)}} / \eqn{t^{(2c)}} of
#'       Juozaitienė & Wit, 2024).
#'     \item \code{"transitivity_time_recent_ordered"} /
#'       \code{"transitivity_time_first_ordered"} — elapsed time since
#'       the most recent / first ordered two-path
#'       \eqn{s \to k} \emph{before} \eqn{k \to r} was completed
#'       (definitions \eqn{t^{(8ac)}} / \eqn{t^{(8bc)}} of
#'       Juozaitienė & Wit, 2024).
#'   }
#'   Defaults to \code{NULL} for a memoryless process.
#' @param endogenous_effects Numeric vector of linear coefficients for
#'   \code{endogenous_stats}. May be named (names must match
#'   \code{endogenous_stats}) or unnamed (positionally matched). Required when
#'   \code{endogenous_stats} is supplied.
#' @param half_life Positive scalar; the half-life \eqn{T} (in time units) used
#'   by every \code{*_exp_decay} stat. A past contribution at time \eqn{t_k}
#'   carries weight \eqn{\exp(-(t - t_k)\,\log 2/T)} into the stat value at
#'   time \eqn{t}. The same \eqn{T} is shared across all decay stats, matching
#'   the convention in Juozaitienė & Wit (2024). Required when any of
#'   \code{"reciprocity_exp_decay"}, \code{"transitivity_exp_decay"},
#'   \code{"transitivity_exp_decay_ordered"} is in \code{endogenous_stats}.
#' @param risk Risk-set rule. \code{"standard"} (the default) keeps every dyad
#'   eligible at every step. \code{"remove"} removes a dyad from the risk set
#'   as soon as it fires, which mimics one-shot processes such as species
#'   invasions or first-citation events.
#' @param global_covariates Optional data.frame describing piecewise-constant
#'   global covariates: variables whose value at time \eqn{t} is the same for
#'   every dyad (e.g. weekday/weekend, weather, policy regime). Must contain a
#'   numeric \code{time_start} column giving the start of each interval; rows
#'   are assumed sorted in time and the first \code{time_start} must be at or
#'   before \code{start_time}. Each additional numeric column is treated as a
#'   global covariate. Defaults to \code{NULL} (no global effects).
#' @param global_effects Numeric vector of linear coefficients for the global
#'   covariates. May be named (names must match the covariate columns in
#'   \code{global_covariates}) or unnamed (positionally matched). Required when
#'   \code{global_covariates} is supplied.
#' @param method Simulation algorithm. Either \code{"gillespie"} (the default,
#'   exact event-driven algorithm: draw inter-event waiting times one at a time)
#'   or \code{"tau_leap"} (approximate, time-driven algorithm: advance the clock
#'   in fixed \code{tau} increments and Poisson-sample event counts per dyad
#'   within each step).
#' @param tau Positive scalar; the step size for \code{method = "tau_leap"}.
#'   Required when method is \code{"tau_leap"} and ignored otherwise. Smaller
#'   values give better approximation but more iterations; as \eqn{\tau \to 0}
#'   the tau-leap result converges in distribution to the exact Gillespie
#'   result.
#'
#' @return If \code{n_controls = 0}, a data.frame with columns \code{sender},
#'   \code{receiver} and \code{time}. If \code{n_controls > 0}, it returns a
#'   long-format data.frame with additional columns \code{stratum} (grouping an
#'   event with its controls) and \code{event} (1 for the realized event,
#'   0 for controls). When \code{endogenous_stats} is supplied, one extra column
#'   per stat is appended carrying the value each row's dyad had at its event
#'   time (immediately before the event fired), so downstream conditional
#'   logistic / GAM estimators can recover the effects. When
#'   \code{global_covariates} is supplied, one column per covariate is appended
#'   carrying the value of that covariate at each row's event time.
#'
#' @details When \code{global_covariates} is supplied, the simulator uses a
#'   boundary-aware Gillespie scheme: the total event rate is rescaled by
#'   \eqn{\exp(\sum_k \beta_k\,x_k(t))}; whenever a sampled waiting time would
#'   cross an interval boundary, the clock is advanced to the boundary without
#'   recording an event, and the next waiting time is redrawn under the new
#'   global multiplier.  Global covariates do not change the per-dyad selection
#'   probabilities (the multiplier cancels), only the waiting-time
#'   distribution.  When combined with \code{endogenous_stats}, the
#'   per-dyad rates are recomputed at every step from the current endogenous
#'   state and then rescaled by the global multiplier.
#'
#'   The \code{"tau_leap"} algorithm advances the clock by a user-chosen step
#'   \eqn{\tau} and draws, for every dyad, a \eqn{\mathrm{Poisson}(\lambda_{sr}(t)\,\tau)}
#'   number of events using the rates at the *start* of the step. Multiple
#'   events can fire in the same step; they are placed at uniform times within
#'   \eqn{[t, t+\tau)} and reported in time order, but they share the
#'   start-of-step endogenous state and global multiplier. Endogenous state is
#'   updated once at the end of the step using all events in that step. The
#'   tau-leap algorithm trades exactness for predictable, vectorised work per
#'   step; it is most useful for high-rate regimes or for problems where the
#'   per-event recomputation in the Gillespie path is the bottleneck. Choose
#'   \eqn{\tau} small enough that (i) \eqn{\lambda \tau \ll 1} on every active
#'   dyad and (ii) \eqn{\tau} is smaller than the shortest interval in
#'   \code{global_covariates} (within-step boundary crossings are not
#'   resolved; the start-of-step global multiplier is used for the entire
#'   step).
#' @export
#'
#' @examples
#' set.seed(1)
#' senders <- receivers <- LETTERS[1:3]
#' sender_cov <- data.frame(activity = c(0.5, -0.2, 1.1))
#' receiver_cov <- data.frame(popularity = c(0.1, 0.3, -0.4))
#' # Standard event simulation
#' events <- simulate_relational_events(
#'   n_events = 5,
#'   senders = senders,
#'   receivers = receivers,
#'   sender_covariates = sender_cov,
#'   sender_effects = 1,
#'   receiver_covariates = receiver_cov,
#'   receiver_effects = 2
#' )
#' events
#'
#' # Case-control generation for partial likelihood inference
#' cc_events <- simulate_relational_events(
#'   n_events = 5,
#'   senders = senders,
#'   receivers = receivers,
#'   sender_covariates = sender_cov,
#'   sender_effects = 1,
#'   n_controls = 2
#' )
#' head(cc_events)
simulate_relational_events <- function(
    n_events,
    senders,
    receivers,
    baseline_rate = 1,
    start_time = 0,
    horizon = Inf,
    contribution_logits = NULL,
    sender_covariates = NULL,
    sender_effects = NULL,
    receiver_covariates = NULL,
    receiver_effects = NULL,
    allow_loops = FALSE,
    n_controls = 0,
    endogenous_stats = NULL,
    endogenous_effects = NULL,
    global_covariates = NULL,
    global_effects = NULL,
    method = c("gillespie", "tau_leap"),
    tau = NULL,
    half_life = NULL,
    risk = c("standard", "remove")) {
  risk <- match.arg(risk)
  stopifnot(length(n_events) == 1, n_events > 0)
  stopifnot(length(baseline_rate) == 1, baseline_rate > 0)
  stopifnot(length(start_time) == 1)
  stopifnot(length(horizon) == 1)
  stopifnot(length(n_controls) == 1, n_controls >= 0)

  method <- match.arg(method)
  if (method == "tau_leap") {
    if (is.null(tau)) {
      stop("tau must be supplied when method = \"tau_leap\".")
    }
    if (length(tau) != 1 || !is.finite(tau) || tau <= 0) {
      stop("tau must be a positive finite scalar.")
    }
  } else {
    if (!is.null(tau)) {
      stop("tau is only used when method = \"tau_leap\".")
    }
  }

  global_active <- !is.null(global_covariates)
  if (global_active) {
    if (!is.data.frame(global_covariates)) {
      stop("global_covariates must be a data.frame.")
    }
    if (!"time_start" %in% names(global_covariates)) {
      stop("global_covariates must include a 'time_start' column.")
    }
    if (nrow(global_covariates) == 0) {
      stop("global_covariates must have at least one row.")
    }
    global_cov_names <- setdiff(names(global_covariates), "time_start")
    if (!length(global_cov_names)) {
      stop("global_covariates must include at least one covariate column besides 'time_start'.")
    }
    time_breaks <- as.numeric(global_covariates$time_start)
    if (any(is.na(time_breaks))) {
      stop("time_start in global_covariates must be numeric and non-missing.")
    }
    if (is.unsorted(time_breaks, strictly = TRUE)) {
      stop("global_covariates$time_start must be strictly increasing.")
    }
    if (time_breaks[1] > start_time) {
      stop("global_covariates$time_start must begin at or before start_time.")
    }
    global_cov_matrix <- as.matrix(
      global_covariates[, global_cov_names, drop = FALSE]
    )
    if (!is.numeric(global_cov_matrix)) {
      stop("Global covariate columns must be numeric.")
    }
    if (any(is.na(global_cov_matrix))) {
      stop("Global covariate values must be non-missing.")
    }
    if (is.null(global_effects)) {
      stop("global_effects must be supplied when global_covariates is set.")
    }
    g_eff_names <- names(global_effects)
    g_eff_vals <- as.numeric(global_effects)
    if (length(g_eff_vals) != length(global_cov_names)) {
      stop("global_effects must have one entry per global covariate column.")
    }
    if (!is.null(g_eff_names) && !all(g_eff_names == "")) {
      if (!setequal(g_eff_names, global_cov_names)) {
        stop("Names of global_effects must match the covariate columns of global_covariates.")
      }
      names(g_eff_vals) <- g_eff_names
      global_effects <- g_eff_vals[global_cov_names]
    } else {
      names(g_eff_vals) <- global_cov_names
      global_effects <- g_eff_vals
    }
    global_log_mult <- as.numeric(global_cov_matrix %*% global_effects)
  }

  reciprocity_stats <- c("reciprocity_count", "reciprocity_binary",
                         "reciprocity_exp_decay",
                         "reciprocity_time_recent", "reciprocity_time_first")
  network_stats <- c("transitivity_count", "transitivity_binary",
                     "cyclic_count", "cyclic_binary",
                     "sending_balance_count", "sending_balance_binary",
                     "receiving_balance_count", "receiving_balance_binary",
                     "transitivity_time_recent", "transitivity_time_first",
                     "cyclic_time_recent", "cyclic_time_first",
                     "sending_balance_time_recent", "sending_balance_time_first",
                     "receiving_balance_time_recent",
                     "receiving_balance_time_first",
                     "transitivity_count_ordered",
                     "transitivity_binary_ordered",
                     "transitivity_time_recent_ordered",
                     "transitivity_time_first_ordered",
                     "transitivity_exp_decay",
                     "transitivity_exp_decay_ordered")
  ordered_stats <- c("transitivity_count_ordered",
                     "transitivity_binary_ordered",
                     "transitivity_time_recent_ordered",
                     "transitivity_time_first_ordered",
                     "transitivity_exp_decay_ordered")
  exp_decay_stats <- c("reciprocity_exp_decay", "transitivity_exp_decay",
                       "transitivity_exp_decay_ordered")
  degree_stats <- c("sender_outdegree", "receiver_indegree")
  supported_endogenous <- c(reciprocity_stats, "recency",
                            degree_stats, network_stats)
  # `recency` and the degree_* stats are per-dyad / per-actor with no
  # actor-graph semantics, so they work for bipartite settings too. The
  # reciprocity_* and network_* families require a one-mode setting
  # (square actor universe) enforced below.
  endogenous_active <- !is.null(endogenous_stats) && length(endogenous_stats) > 0
  if (endogenous_active) {
    endogenous_stats <- as.character(endogenous_stats)
    bad <- setdiff(endogenous_stats, supported_endogenous)
    if (length(bad)) {
      stop("Unsupported endogenous_stats: ", paste(bad, collapse = ", "),
           ". Supported: ", paste(supported_endogenous, collapse = ", "), ".")
    }
    requires_half_life <- any(endogenous_stats %in% exp_decay_stats)
    if (requires_half_life) {
      if (is.null(half_life) || length(half_life) != 1 || !is.finite(half_life) ||
          half_life <= 0) {
        stop("half_life must be a positive finite scalar when any of ",
             paste(sprintf("\"%s\"", exp_decay_stats), collapse = ", "),
             " is in endogenous_stats.")
      }
    }
    if (anyDuplicated(endogenous_stats)) {
      stop("endogenous_stats must not contain duplicates.")
    }
    if (is.null(endogenous_effects)) {
      stop("endogenous_effects must be supplied when endogenous_stats is set.")
    }
    eff_names <- names(endogenous_effects)
    eff_vals <- as.numeric(endogenous_effects)
    if (length(eff_vals) != length(endogenous_stats)) {
      stop("endogenous_effects must have the same length as endogenous_stats.")
    }
    if (!is.null(eff_names) && !all(eff_names == "")) {
      if (!setequal(eff_names, endogenous_stats)) {
        stop("Names of endogenous_effects must match endogenous_stats.")
      }
      names(eff_vals) <- eff_names
      endogenous_effects <- eff_vals[endogenous_stats]
    } else {
      names(eff_vals) <- endogenous_stats
      endogenous_effects <- eff_vals
    }
  }

  senders <- as.character(senders)
  receivers <- as.character(receivers)
  S <- length(senders)
  R <- length(receivers)

  if (S == 0 || R == 0) {
    stop("Both sender and receiver sets must be non-empty.")
  }

  one_mode_required_stats <- c(reciprocity_stats, network_stats)
  needs_one_mode <- endogenous_active &&
    any(endogenous_stats %in% one_mode_required_stats)
  if (needs_one_mode) {
    # The reciprocity_* stats maintain a state matrix indexed by
    # (sender, receiver) and update the *reverse* dyad after each event;
    # the network_* (transitivity / cyclic / balance) stats use a binary
    # adjacency matrix and matrix products that only make sense when the
    # actor universe is the same on both axes. Both families require senders
    # and receivers to be the same character vector in the same order.
    # `recency` is per-dyad with no reverse-dyad or path semantics, so it
    # does not trigger this check.
    if (S != R || !identical(senders, receivers)) {
      stop("reciprocity_* and network_* endogenous stats currently require ",
           "senders and receivers to be the same character vector in the ",
           "same order (one-mode networks). Bipartite / two-mode support ",
           "is on the roadmap.")
    }
  }

  if (is.null(contribution_logits)) {
    contribution_logits <- matrix(0, nrow = S, ncol = R)
  }
  if (!is.matrix(contribution_logits) || any(dim(contribution_logits) != c(S, R))) {
    stop("contribution_logits must be an S x R matrix.")
  }

  sender_score <- rep(0, S)
  if (!is.null(sender_covariates)) {
    sc <- as.matrix(sender_covariates)
    if (nrow(sc) != S) {
      stop("sender_covariates must have one row per sender.")
    }
    if (is.null(sender_effects)) {
      stop("sender_effects must be supplied when sender_covariates are used.")
    }
    sender_effects <- as.numeric(sender_effects)
    if (ncol(sc) != length(sender_effects)) {
      stop("Length of sender_effects must match number of sender covariates.")
    }
    sender_score <- as.numeric(sc %*% sender_effects)
  }

  receiver_score <- rep(0, R)
  if (!is.null(receiver_covariates)) {
    rc <- as.matrix(receiver_covariates)
    if (nrow(rc) != R) {
      stop("receiver_covariates must have one row per receiver.")
    }
    if (is.null(receiver_effects)) {
      stop("receiver_effects must be supplied when receiver_covariates are used.")
    }
    receiver_effects <- as.numeric(receiver_effects)
    if (ncol(rc) != length(receiver_effects)) {
      stop("Length of receiver_effects must match number of receiver covariates.")
    }
    receiver_score <- as.numeric(rc %*% receiver_effects)
  }

  static_log_weights <- contribution_logits + outer(sender_score, receiver_score, "+")

  if (!allow_loops) {
    same_actor <- outer(senders, receivers, "==")
    static_log_weights[same_actor] <- -Inf
  }

  compute_weights <- function(log_w) {
    w <- exp(log_w) * baseline_rate
    w[!is.finite(w)] <- 0
    tot <- sum(w)
    if (tot <= 0) {
      stop("No admissible dyads with positive intensity.")
    }
    list(weights = w, total = tot, probs = as.vector(w) / tot,
         valid = which(w > 0))
  }

  endo_state <- list()
  if (endogenous_active) {
    for (st in endogenous_stats) {
      if (st == "recency") {
        # State cell holds the time of the last event on dyad (s, r);
        # initialised to start_time so the "elapsed time since last event"
        # stat is zero for every dyad at t = start_time and grows from
        # there.
        endo_state[[st]] <- matrix(start_time, nrow = S, ncol = R)
      } else if (st %in% c("reciprocity_time_recent",
                            "reciprocity_time_first",
                            "transitivity_time_recent",
                            "transitivity_time_first",
                            "cyclic_time_recent",
                            "cyclic_time_first",
                            "sending_balance_time_recent",
                            "sending_balance_time_first",
                            "receiving_balance_time_recent",
                            "receiving_balance_time_first",
                            "transitivity_time_recent_ordered",
                            "transitivity_time_first_ordered")) {
        # NA marks "the relevant past event (reverse dyad, or two-path)
        # has never happened". Replaced with 0 in the score / output
        # matrices so the rate computation stays numeric (see
        # endo_stat_values()).
        endo_state[[st]] <- matrix(NA_real_, nrow = S, ncol = R)
      } else {
        endo_state[[st]] <- matrix(0, nrow = S, ncol = R)
      }
    }
  }

  # Shared binary adjacency matrix used by every network_* stat
  # (transitivity / cyclic / sending_balance / receiving_balance). Only
  # allocated when at least one such stat is active. The matrix is square
  # because needs_one_mode is enforced earlier.
  has_network_stats <- endogenous_active &&
    any(endogenous_stats %in% network_stats)
  adj_state <- if (has_network_stats) {
    matrix(0, nrow = S, ncol = S)
  } else NULL

  # Ordered transitivity needs per-dyad first / last event timestamps so we
  # can detect when an event (i, j) is the first (i, j) AFTER a previously
  # observed (s, i) -- the only situation in which a chronologically
  # ordered chain s -> i -> j is newly validated.
  has_ordered_stats <- endogenous_active &&
    any(endogenous_stats %in% ordered_stats)
  if (has_ordered_stats) {
    first_dyad_time <- matrix(NA_real_, nrow = S, ncol = S)
    last_dyad_time  <- matrix(NA_real_, nrow = S, ncol = S)
    # Shared count state, fed by every ordered stat (count, binary,
    # time_recent, time_first) so that the binary version can be
    # derived from the count even when the count itself isn't
    # requested by the caller.
    ord_count_state <- matrix(0L, nrow = S, ncol = S)
  } else {
    first_dyad_time <- NULL
    last_dyad_time  <- NULL
    ord_count_state <- NULL
  }

  # Per-actor accumulators for the degree_* stats. Length-S sender count
  # vector and length-R receiver count vector, both starting at zero.
  has_outdeg <- endogenous_active && "sender_outdegree" %in% endogenous_stats
  has_indeg  <- endogenous_active && "receiver_indegree" %in% endogenous_stats
  sender_out_count <- if (has_outdeg) numeric(S) else NULL
  receiver_in_count <- if (has_indeg) numeric(R) else NULL

  has_exp_decay <- endogenous_active &&
    any(endogenous_stats %in% exp_decay_stats)
  active_exp_decay_stats <- if (has_exp_decay) {
    intersect(endogenous_stats, exp_decay_stats)
  } else character(0)
  last_state_time <- start_time
  if (has_exp_decay) {
    decay_rate <- log(2) / half_life
  }

  # Map each generative "two-path timing" stat to (family, is_first) so the
  # state-update sweep can be derived in a single helper instead of branching
  # per stat name in two places (Gillespie + tau-leap inner loops).
  two_path_time_lookup <- list(
    transitivity_time_recent      = list(family = "transitivity",      first = FALSE),
    transitivity_time_first       = list(family = "transitivity",      first = TRUE),
    cyclic_time_recent            = list(family = "cyclic",            first = FALSE),
    cyclic_time_first             = list(family = "cyclic",            first = TRUE),
    sending_balance_time_recent   = list(family = "sending_balance",   first = FALSE),
    sending_balance_time_first    = list(family = "sending_balance",   first = TRUE),
    receiving_balance_time_recent = list(family = "receiving_balance", first = FALSE),
    receiving_balance_time_first  = list(family = "receiving_balance", first = TRUE)
  )

  # Returns the (row, col) integer matrix of state-matrix cells that are
  # newly "two-path-formed" by event (i, j), given `adj` = current binary
  # adjacency *before* (i, j) is added. The four families correspond to the
  # four endogenous-closure structures:
  #   transitivity      : s -> k -> r (two-path closing s -> r)
  #   cyclic            : r -> k -> s (cyclic counterpart)
  #   sending_balance   : (s -> k) and (r -> k), shared target k
  #   receiving_balance : (k -> s) and (k -> r), shared source k
  # The caller is responsible for the gate `adj[i, j] == 0`: a re-fire
  # of an already-present edge doesn't form any new two-path.
  two_path_writes <- function(family, i, j, adj) {
    switch(family,
      transitivity = {
        a <- which(adj[, i] == 1L)  # a -> i exists -> chain a -> i -> j forms
        b <- which(adj[j, ] == 1L)  # j -> b exists -> chain i -> j -> b forms
        rbind(
          cbind(a,                  rep(j, length(a))),
          cbind(rep(i, length(b)),  b))
      },
      cyclic = {
        s_A <- which(adj[j, ] == 1L)   # j -> s exists -> cyclic r=i, k=j, s
        r_B <- which(adj[, i] == 1L)   # r -> i exists -> cyclic r, k=i, s=j
        rbind(
          cbind(s_A,                rep(i, length(s_A))),
          cbind(rep(j, length(r_B)), r_B))
      },
      sending_balance = {
        k_targets <- which(adj[, j] == 1L)  # nodes that already sent to k=j
        # As (s = i, k = j): for each r in k_targets (r != i), state[i, r] forms
        r_A <- k_targets[k_targets != i]
        # As (r = i, k = j): for each s in k_targets (s != i), state[s, i] forms
        s_B <- k_targets[k_targets != i]
        rbind(
          cbind(rep(i, length(r_A)), r_A),
          cbind(s_B,                 rep(i, length(s_B))))
      },
      receiving_balance = {
        k_sources <- which(adj[i, ] == 1L)  # nodes already targeted by k=i
        r_A <- k_sources[k_sources != j]
        s_B <- k_sources[k_sources != j]
        rbind(
          cbind(rep(j, length(r_A)), r_A),
          cbind(s_B,                 rep(j, length(s_B))))
      },
      stop("Unknown two-path family: ", family)
    )
  }

  # Apply the (row, col) writes to a state matrix. `is_first = TRUE` only
  # touches NA cells (preserves the first-formation time); otherwise
  # overwrites unconditionally (records the most-recent formation time).
  apply_time_writes <- function(M, writes, t_now, is_first) {
    if (!nrow(writes)) return(M)
    if (is_first) {
      mask <- is.na(M[writes])
      if (any(mask)) M[writes[mask, , drop = FALSE]] <- t_now
    } else {
      M[writes] <- t_now
    }
    M
  }

  # Detects every chronologically ordered chain s -> i -> j that is *newly
  # validated* by the event (i, j) firing at time `t_now`. A chain
  # (s, i, j) is newly validated iff
  #   (a) first_dyad_time[s, i] is set (s -> i happened earlier in the run),
  #   (b) this (i, j) event is the first (i, j) AFTER first_dyad_time[s, i].
  # Condition (b) holds when there is no prior (i, j) event, or when the
  # most recent (i, j) event was earlier than the first (s, i) event.
  # Returns the integer index vector of senders s whose chain was newly
  # validated by this event. Callers update ord_count_state and the
  # time_*_ordered state matrices using this vector.
  ordered_validation_mask <- function(i, j) {
    if (!has_ordered_stats) return(integer(0))
    col_first_si <- first_dyad_time[, i]
    last_ij_prev <- last_dyad_time[i, j]
    mask <- !is.na(col_first_si) &
            (is.na(last_ij_prev) | col_first_si > last_ij_prev)
    which(mask)
  }

  # Single helper that performs the full ordered-stat update for an event
  # (i, j) at time t_now: validates new ordered chains, increments
  # ord_count_state, refreshes the time_*_ordered state matrices, and
  # bumps first_dyad_time / last_dyad_time. Called from both the Gillespie
  # and tau-leap inner loops.
  apply_ordered_update <- function(i, j, t_now) {
    if (has_ordered_stats) {
      validated <- ordered_validation_mask(i, j)
      if (length(validated)) {
        idx <- cbind(validated, rep(j, length(validated)))
        ord_count_state[idx] <<- ord_count_state[idx] + 1L
        if (!is.null(endo_state[["transitivity_time_recent_ordered"]])) {
          endo_state[["transitivity_time_recent_ordered"]][idx] <<- t_now
        }
        if (!is.null(endo_state[["transitivity_time_first_ordered"]])) {
          M <- endo_state[["transitivity_time_first_ordered"]]
          fresh <- is.na(M[idx])
          if (any(fresh)) M[idx[fresh, , drop = FALSE]] <- t_now
          endo_state[["transitivity_time_first_ordered"]] <<- M
        }
        if (!is.null(endo_state[["transitivity_exp_decay_ordered"]])) {
          # Decay state is current as of t_now (apply_exp_decay was called
          # at the start of this event). Each newly validated chain adds a
          # fresh contribution of weight 1, which then decays from t_now.
          endo_state[["transitivity_exp_decay_ordered"]][idx] <<-
            endo_state[["transitivity_exp_decay_ordered"]][idx] + 1
        }
      }
      # Per-dyad bookkeeping after the validation sweep so the *current*
      # event doesn't pollute its own predecessor view.
      if (is.na(first_dyad_time[i, j])) first_dyad_time[i, j] <<- t_now
      last_dyad_time[i, j] <<- t_now
    }
    invisible()
  }

  apply_exp_decay <- function() {
    # Multiplicative decay of every active exp-decay state matrix to the
    # current clock time. Called when reading or snapshotting state so the
    # value carried is correctly attenuated for the time elapsed since
    # the last update. All exp-decay stats share `decay_rate` (= log 2 /
    # half_life) per the convention of Juozaitienė & Wit (2024).
    if (!has_exp_decay) return(invisible())
    dt_decay <- current_time - last_state_time
    if (dt_decay > 0) {
      decay_factor <- exp(-dt_decay * decay_rate)
      for (st in active_exp_decay_stats) {
        endo_state[[st]] <<- endo_state[[st]] * decay_factor
      }
      last_state_time <<- current_time
    }
    invisible()
  }

  endo_stat_values <- function() {
    # Returns a named list of S x R stat-value matrices, one per requested
    # stat, evaluated at the current clock time and state. Used by both
    # score (linear predictor) and snapshot (output columns). Recomputed
    # whenever called -- callers should reuse the result within a step.
    if (!endogenous_active) return(NULL)
    needs_AA  <- any(endogenous_stats %in% c("transitivity_count",
                                              "transitivity_binary",
                                              "cyclic_count",
                                              "cyclic_binary"))
    needs_AAt <- any(endogenous_stats %in% c("sending_balance_count",
                                              "sending_balance_binary"))
    needs_AtA <- any(endogenous_stats %in% c("receiving_balance_count",
                                              "receiving_balance_binary"))
    AA  <- if (needs_AA)  adj_state %*% adj_state         else NULL
    AAt <- if (needs_AAt) adj_state %*% t(adj_state)       else NULL
    AtA <- if (needs_AtA) t(adj_state) %*% adj_state       else NULL
    # The degree_* stats are constant across one axis of the dyad matrix:
    # outdegree depends only on the sender, indegree only on the receiver.
    # Broadcasting via matrix(v, S, R) (column-fill) replicates the
    # length-S sender vector across columns; matrix(v, S, R, byrow = TRUE)
    # replicates the length-R receiver vector across rows.
    # Helper: time-elapsed stat with NA -> 0 replacement so the score stays
    # numeric for never-seen cells. Used by the reciprocity_time_* family.
    time_elapsed_or_zero <- function(state_mat) {
      v <- current_time - state_mat
      v[is.na(v)] <- 0
      v
    }
    vals <- list()
    for (st in endogenous_stats) {
      vals[[st]] <- switch(st,
        "recency"                   = current_time - endo_state[[st]],
        "reciprocity_time_recent"   = time_elapsed_or_zero(endo_state[[st]]),
        "reciprocity_time_first"    = time_elapsed_or_zero(endo_state[[st]]),
        "transitivity_time_recent"      = time_elapsed_or_zero(endo_state[[st]]),
        "transitivity_time_first"       = time_elapsed_or_zero(endo_state[[st]]),
        "cyclic_time_recent"            = time_elapsed_or_zero(endo_state[[st]]),
        "cyclic_time_first"             = time_elapsed_or_zero(endo_state[[st]]),
        "sending_balance_time_recent"   = time_elapsed_or_zero(endo_state[[st]]),
        "sending_balance_time_first"    = time_elapsed_or_zero(endo_state[[st]]),
        "receiving_balance_time_recent" = time_elapsed_or_zero(endo_state[[st]]),
        "receiving_balance_time_first"  = time_elapsed_or_zero(endo_state[[st]]),
        "transitivity_count_ordered"      = ord_count_state * 1.0,
        "transitivity_binary_ordered"     = (ord_count_state > 0) * 1.0,
        "transitivity_time_recent_ordered"= time_elapsed_or_zero(endo_state[[st]]),
        "transitivity_time_first_ordered" = time_elapsed_or_zero(endo_state[[st]]),
        "transitivity_exp_decay"          = endo_state[[st]],
        "transitivity_exp_decay_ordered"  = endo_state[[st]],
        "sender_outdegree"          = matrix(sender_out_count, nrow = S, ncol = R),
        "receiver_indegree"         = matrix(receiver_in_count, nrow = S, ncol = R,
                                              byrow = TRUE),
        "transitivity_count"        = AA,
        "transitivity_binary"       = (AA > 0) * 1.0,
        "cyclic_count"              = t(AA),
        "cyclic_binary"             = (t(AA) > 0) * 1.0,
        "sending_balance_count"     = AAt,
        "sending_balance_binary"    = (AAt > 0) * 1.0,
        "receiving_balance_count"   = AtA,
        "receiving_balance_binary"  = (AtA > 0) * 1.0,
        endo_state[[st]]
      )
    }
    vals
  }

  endo_score_matrix <- function() {
    if (!endogenous_active) {
      return(NULL)
    }
    vals <- endo_stat_values()
    es <- matrix(0, nrow = S, ncol = R)
    for (st in endogenous_stats) {
      es <- es + endogenous_effects[[st]] * vals[[st]]
    }
    es
  }

  ww <- compute_weights(static_log_weights)
  weights <- ww$weights
  total_weight <- ww$total
  probs <- ww$probs
  valid_dyads <- ww$valid
  n_valid_dyads <- length(valid_dyads)
  if (n_controls > 0 && n_controls >= n_valid_dyads) {
    stop("Requested n_controls is >= the number of admissible dyads.")
  }

  event_senders <- character(n_events)
  event_receivers <- character(n_events)
  event_times <- numeric(n_events)

  if (n_controls > 0) {
    control_senders <- character(n_events * n_controls)
    control_receivers <- character(n_events * n_controls)
    control_times <- numeric(n_events * n_controls)
    control_strata <- integer(n_events * n_controls)
  }

  if (endogenous_active) {
    event_stat_vals <- matrix(0,
        nrow = n_events, ncol = length(endogenous_stats),
        dimnames = list(NULL, endogenous_stats))
    if (n_controls > 0) {
      control_stat_vals <- matrix(0,
          nrow = n_events * n_controls, ncol = length(endogenous_stats),
          dimnames = list(NULL, endogenous_stats))
    }
  }

  if (global_active) {
    event_global_vals <- matrix(0,
        nrow = n_events, ncol = length(global_cov_names),
        dimnames = list(NULL, global_cov_names))
    if (n_controls > 0) {
      control_global_vals <- matrix(0,
          nrow = n_events * n_controls, ncol = length(global_cov_names),
          dimnames = list(NULL, global_cov_names))
    }
  }

  interval_at <- function(t) {
    idx <- findInterval(t, time_breaks, rightmost.closed = FALSE)
    if (idx < 1L) 1L else idx
  }

  current_time <- start_time
  event_counter <- 0L
  exceeded_horizon <- FALSE

  if (method == "tau_leap") {
    while (event_counter < n_events && current_time < horizon) {
      # Decay exp-decay state up to the start of this step so the rates
      # used below are correctly attenuated.
      apply_exp_decay()

      # Start-of-step rate matrix.
      log_w <- static_log_weights
      if (endogenous_active) {
        log_w <- log_w + endo_score_matrix()
      }
      weights <- exp(log_w) * baseline_rate
      weights[!is.finite(weights)] <- 0
      if (sum(weights) <= 0) {
        if (risk == "remove") break
        stop("No admissible dyads with positive intensity.")
      }
      if (global_active) {
        idx_step <- interval_at(current_time)
        g_mult <- exp(global_log_mult[idx_step])
      } else {
        g_mult <- 1
      }

      step <- min(tau, horizon - current_time)
      expected <- weights * g_mult * step
      if (risk == "remove") {
        # One-shot dyads: at most one event per dyad per step. Use a
        # Bernoulli with success probability 1 - exp(-lambda*tau) rather
        # than Poisson, which would allow more than one event on a dyad
        # that must be removed after its first firing.
        p_fire <- 1 - exp(-as.vector(expected))
        counts <- stats::rbinom(S * R, size = 1, prob = p_fire)
      } else {
        counts <- stats::rpois(S * R, as.vector(expected))
      }
      n_in_step <- sum(counts)

      if (n_in_step > 0L) {
        valid_dyads_step <- which(weights > 0)
        if (n_controls > 0 && n_controls >= length(valid_dyads_step)) {
          stop("Requested n_controls is >= the number of admissible dyads ",
               "during a tau-leap step.")
        }
        # Build an event vector by repeating each dyad index `counts` times.
        ev_dyads <- rep(seq_len(S * R), counts)
        ev_times <- current_time + stats::runif(n_in_step, 0, step)
        ord <- order(ev_times)
        ev_dyads <- ev_dyads[ord]
        ev_times <- ev_times[ord]

        # Snapshot stat-value matrices at the start of the step. All events
        # in the step are scored against this snapshot; the live state is
        # updated once at the end of the step. For time-dependent stats
        # (recency, reciprocity_time_recent, reciprocity_time_first) we
        # capture the raw state and subtract the per-event time when
        # emitting each row, so the value carried is correct for that
        # specific event time within the step.
        step_vals_snapshot <- if (endogenous_active) endo_stat_values() else NULL
        time_state_snapshots <- if (endogenous_active) {
          snap <- list()
          for (ts in c("recency", "reciprocity_time_recent",
                       "reciprocity_time_first",
                       "transitivity_time_recent",
                       "transitivity_time_first",
                       "cyclic_time_recent", "cyclic_time_first",
                       "sending_balance_time_recent",
                       "sending_balance_time_first",
                       "receiving_balance_time_recent",
                       "receiving_balance_time_first",
                       "transitivity_time_recent_ordered",
                       "transitivity_time_first_ordered")) {
            if (ts %in% endogenous_stats) {
              snap[[ts]] <- endo_state[[ts]]
            }
          }
          snap
        } else list()

        # Per-event time-dependent stat value, single-cell variant.
        time_stat_at <- function(st, s, r, t) {
          v <- t - time_state_snapshots[[st]][s, r]
          if (st == "recency") v else if (is.na(v)) 0 else v
        }
        # Per-event time-dependent stat value, vectorized (rectangular
        # selection) variant.
        time_stat_at_v <- function(st, ss, rs, t) {
          v <- t - time_state_snapshots[[st]][cbind(ss, rs)]
          if (st == "recency") return(v)
          v[is.na(v)] <- 0
          v
        }
        time_stats_active <- names(time_state_snapshots)

        for (k in seq_len(n_in_step)) {
          if (event_counter >= n_events) break
          choice <- ev_dyads[k]
          s_idx <- ((choice - 1L) %% S) + 1L
          r_idx <- ((choice - 1L) %/% S) + 1L

          event_counter <- event_counter + 1L
          event_senders[event_counter] <- senders[s_idx]
          event_receivers[event_counter] <- receivers[r_idx]
          event_times[event_counter] <- ev_times[k]

          if (endogenous_active) {
            for (st in endogenous_stats) {
              event_stat_vals[event_counter, st] <- if (st %in% time_stats_active) {
                time_stat_at(st, s_idx, r_idx, ev_times[k])
              } else {
                step_vals_snapshot[[st]][s_idx, r_idx]
              }
            }
          }

          if (global_active) {
            for (cn in global_cov_names) {
              event_global_vals[event_counter, cn] <- global_cov_matrix[idx_step, cn]
            }
          }

          if (n_controls > 0) {
            non_event_pool <- setdiff(valid_dyads_step, choice)
            if (length(non_event_pool) < n_controls) {
              non_event_choices <- non_event_pool
            } else {
              non_event_choices <- sample(non_event_pool, size = n_controls,
                                          replace = FALSE)
            }
            ctrl_start_idx <- (event_counter - 1L) * n_controls + 1L
            ctrl_end_idx <- event_counter * n_controls
            c_s_idxs <- ((non_event_choices - 1L) %% S) + 1L
            c_r_idxs <- ((non_event_choices - 1L) %/% S) + 1L
            control_senders[ctrl_start_idx:ctrl_end_idx] <- senders[c_s_idxs]
            control_receivers[ctrl_start_idx:ctrl_end_idx] <- receivers[c_r_idxs]
            control_times[ctrl_start_idx:ctrl_end_idx] <- ev_times[k]
            control_strata[ctrl_start_idx:ctrl_end_idx] <- event_counter

            if (endogenous_active) {
              ctrl_rows <- ctrl_start_idx:ctrl_end_idx
              for (st in endogenous_stats) {
                control_stat_vals[ctrl_rows, st] <- if (st %in% time_stats_active) {
                  time_stat_at_v(st, c_s_idxs, c_r_idxs, ev_times[k])
                } else {
                  step_vals_snapshot[[st]][cbind(c_s_idxs, c_r_idxs)]
                }
              }
            }
            if (global_active) {
              ctrl_rows <- ctrl_start_idx:ctrl_end_idx
              for (cn in global_cov_names) {
                control_global_vals[ctrl_rows, cn] <- global_cov_matrix[idx_step, cn]
              }
            }
          }
        }

        # End-of-step bulk update of live endogenous state with every
        # event from this step (events emitted past the n_events cap are
        # excluded — they were not recorded).
        if (endogenous_active || risk == "remove") {
          for (k in seq_len(n_in_step)) {
            choice <- ev_dyads[k]
            s_k <- ((choice - 1L) %% S) + 1L
            r_k <- ((choice - 1L) %/% S) + 1L
            if (endogenous_active) {
              for (st in endogenous_stats) {
                if (st == "reciprocity_count" || st == "reciprocity_exp_decay") {
                  endo_state[[st]][r_k, s_k] <- endo_state[[st]][r_k, s_k] + 1
                } else if (st == "reciprocity_binary") {
                  endo_state[[st]][r_k, s_k] <- 1
                } else if (st == "reciprocity_time_recent") {
                  endo_state[[st]][r_k, s_k] <- ev_times[k]
                } else if (st == "reciprocity_time_first") {
                  if (is.na(endo_state[[st]][r_k, s_k])) {
                    endo_state[[st]][r_k, s_k] <- ev_times[k]
                  }
                } else if (st == "recency") {
                  endo_state[[st]][s_k, r_k] <- ev_times[k]
                } else if (!is.null(two_path_time_lookup[[st]])) {
                  if (adj_state[s_k, r_k] == 0) {
                    info <- two_path_time_lookup[[st]]
                    writes <- two_path_writes(info$family, s_k, r_k, adj_state)
                    endo_state[[st]] <- apply_time_writes(
                      endo_state[[st]], writes, ev_times[k], info$first)
                  }
                } else if (st == "transitivity_exp_decay") {
                  if (adj_state[s_k, r_k] == 0) {
                    writes <- two_path_writes("transitivity", s_k, r_k, adj_state)
                    if (nrow(writes)) {
                      endo_state[[st]][writes] <- endo_state[[st]][writes] + 1
                    }
                  }
                }
              }
              if (has_network_stats) {
                adj_state[s_k, r_k] <- 1
              }
              apply_ordered_update(s_k, r_k, ev_times[k])
              if (has_outdeg) sender_out_count[s_k]  <- sender_out_count[s_k]  + 1
              if (has_indeg)  receiver_in_count[r_k] <- receiver_in_count[r_k] + 1
            }
            if (risk == "remove") {
              static_log_weights[s_k, r_k] <- -Inf
            }
          }
        }
      }

      current_time <- current_time + step
    }
  } else {

  for (i in seq_len(n_events)) {
    if (endogenous_active || risk == "remove") {
      log_w <- static_log_weights
      if (endogenous_active) {
        log_w <- log_w + endo_score_matrix()
      }
      weights <- exp(log_w) * baseline_rate
      weights[!is.finite(weights)] <- 0
      total_weight <- sum(weights)
      if (total_weight <= 0) {
        if (risk == "remove") {
          # All admissible dyads have fired and been removed -- stop
          # gracefully and return whatever was produced so far.
          break
        }
        stop("No admissible dyads with positive intensity.")
      }
      probs <- as.vector(weights) / total_weight
      valid_dyads <- which(weights > 0)
      if (n_controls > 0 && n_controls >= length(valid_dyads)) {
        stop("Requested n_controls is >= the number of admissible dyads at step ", i, ".")
      }
    }

    if (global_active) {
      # Boundary-aware waiting time: redraw whenever a sampled dt would
      # cross into the next interval. Each boundary crossing advances
      # `current_time` to the boundary without emitting an event.
      repeat {
        idx <- interval_at(current_time)
        g_mult <- exp(global_log_mult[idx])
        next_boundary <- if (idx < length(time_breaks)) {
          time_breaks[idx + 1L]
        } else {
          Inf
        }
        rate_eff <- total_weight * g_mult
        dt <- stats::rexp(1, rate = rate_eff)
        t_new <- current_time + dt
        if (t_new < next_boundary) {
          if (t_new > horizon) {
            exceeded_horizon <- TRUE
            break
          }
          current_time <- t_new
          break
        }
        if (next_boundary > horizon) {
          exceeded_horizon <- TRUE
          break
        }
        current_time <- next_boundary
      }
      if (exceeded_horizon) break
    } else {
      # Gillespie timing: rexp(1, rate = sum of all hazards)
      dt <- stats::rexp(1, rate = total_weight)
      current_time <- current_time + dt
      if (current_time > horizon) {
        break
      }
    }

    choice <- sample.int(S * R, size = 1, prob = probs)
    s_idx <- ((choice - 1L) %% S) + 1L
    r_idx <- ((choice - 1L) %/% S) + 1L

    event_counter <- event_counter + 1L
    event_senders[event_counter] <- senders[s_idx]
    event_receivers[event_counter] <- receivers[r_idx]
    event_times[event_counter] <- current_time

    # Decay exp-decay state up to the event time before snapshotting it,
    # so the value carried on the output row reflects the time elapsed
    # since the previous event.
    apply_exp_decay()
    # Compute the full stat-value matrices once per event so the same
    # values are reused for both the event row and any control rows
    # below.
    step_vals <- if (endogenous_active) endo_stat_values() else NULL

    if (endogenous_active) {
      for (st in endogenous_stats) {
        event_stat_vals[event_counter, st] <- step_vals[[st]][s_idx, r_idx]
      }
    }

    if (global_active) {
      idx_evt <- interval_at(current_time)
      for (cn in global_cov_names) {
        event_global_vals[event_counter, cn] <- global_cov_matrix[idx_evt, cn]
      }
    }

    if (n_controls > 0) {
      # Sample 'n_controls' non-events uniformally from valid dyads excluding the chosen one
      non_event_pool <- setdiff(valid_dyads, choice)
      if (length(non_event_pool) < n_controls) {
        # Should not happen if `n_controls < n_valid_dyads` check holds initially
        # taking into account `choice` is one valid dyad.
        non_event_choices <- non_event_pool
      } else {
        # uniform sampling of non-events
        non_event_choices <- sample(non_event_pool, size = n_controls, replace = FALSE)
      }

      ctrl_start_idx <- (event_counter - 1L) * n_controls + 1L
      ctrl_end_idx <- event_counter * n_controls

      c_s_idxs <- ((non_event_choices - 1L) %% S) + 1L
      c_r_idxs <- ((non_event_choices - 1L) %/% S) + 1L

      control_senders[ctrl_start_idx:ctrl_end_idx] <- senders[c_s_idxs]
      control_receivers[ctrl_start_idx:ctrl_end_idx] <- receivers[c_r_idxs]
      control_times[ctrl_start_idx:ctrl_end_idx] <- current_time
      control_strata[ctrl_start_idx:ctrl_end_idx] <- event_counter

      if (endogenous_active) {
        ctrl_rows <- ctrl_start_idx:ctrl_end_idx
        for (st in endogenous_stats) {
          control_stat_vals[ctrl_rows, st] <-
            step_vals[[st]][cbind(c_s_idxs, c_r_idxs)]
        }
      }

      if (global_active) {
        idx_evt <- interval_at(current_time)
        ctrl_rows <- ctrl_start_idx:ctrl_end_idx
        for (cn in global_cov_names) {
          control_global_vals[ctrl_rows, cn] <- global_cov_matrix[idx_evt, cn]
        }
      }
    }

    if (endogenous_active) {
      # Update state matrices using the realized event (s_idx -> r_idx).
      # reciprocity_* stats update the *reverse* dyad (r_idx, s_idx).
      # recency updates the *same* dyad (s_idx, r_idx) with the event time.
      # network_* stats share the binary adjacency adj_state, updated below.
      # degree_* stats accumulate into per-actor vectors.
      for (st in endogenous_stats) {
        if (st == "reciprocity_count" || st == "reciprocity_exp_decay") {
          endo_state[[st]][r_idx, s_idx] <- endo_state[[st]][r_idx, s_idx] + 1
        } else if (st == "reciprocity_binary") {
          endo_state[[st]][r_idx, s_idx] <- 1
        } else if (st == "reciprocity_time_recent") {
          endo_state[[st]][r_idx, s_idx] <- current_time
        } else if (st == "reciprocity_time_first") {
          if (is.na(endo_state[[st]][r_idx, s_idx])) {
            endo_state[[st]][r_idx, s_idx] <- current_time
          }
        } else if (st == "recency") {
          endo_state[[st]][s_idx, r_idx] <- current_time
        } else if (!is.null(two_path_time_lookup[[st]])) {
          # A two-path is *formed* at the time the second of its two legs
          # is first observed; re-fires of an existing leg don't form
          # new two-paths. So only sweep when this is the first
          # occurrence of dyad (s_idx, r_idx). The per-family geometry
          # is encapsulated in two_path_writes().
          if (adj_state[s_idx, r_idx] == 0) {
            info <- two_path_time_lookup[[st]]
            writes <- two_path_writes(info$family, s_idx, r_idx, adj_state)
            endo_state[[st]] <- apply_time_writes(
              endo_state[[st]], writes, current_time, info$first)
          }
        } else if (st == "transitivity_exp_decay") {
          # Unordered exp-decay: each newly-formed two-path contributes
          # +1 (decay state was just attenuated to current_time, so a
          # fresh contribution of weight exp(0) = 1 is correct). Same
          # first-fire gate as the timing stats.
          if (adj_state[s_idx, r_idx] == 0) {
            writes <- two_path_writes("transitivity", s_idx, r_idx, adj_state)
            if (nrow(writes)) {
              endo_state[[st]][writes] <- endo_state[[st]][writes] + 1
            }
          }
        }
      }
      if (has_network_stats) {
        adj_state[s_idx, r_idx] <- 1
      }
      apply_ordered_update(s_idx, r_idx, current_time)
      if (has_outdeg) sender_out_count[s_idx]  <- sender_out_count[s_idx]  + 1
      if (has_indeg)  receiver_in_count[r_idx] <- receiver_in_count[r_idx] + 1
    }

    if (risk == "remove") {
      # One-shot dyad: drop it from the risk set so it cannot fire again.
      static_log_weights[s_idx, r_idx] <- -Inf
    }
  }
  }  # end method == "gillespie" branch

  if (event_counter == 0L) {
    if (n_controls == 0) {
      out <- data.frame(sender = character(0), receiver = character(0), time = numeric(0))
    } else {
      out <- data.frame(
        stratum = integer(0), event = integer(0),
        sender = character(0), receiver = character(0), time = numeric(0)
      )
    }
    if (endogenous_active) {
      for (st in endogenous_stats) out[[st]] <- numeric(0)
    }
    if (global_active) {
      for (cn in global_cov_names) out[[cn]] <- numeric(0)
    }
    return(out)
  }

  if (n_controls == 0) {
    out <- data.frame(
      sender = event_senders[seq_len(event_counter)],
      receiver = event_receivers[seq_len(event_counter)],
      time = event_times[seq_len(event_counter)],
      stringsAsFactors = FALSE
    )
    if (endogenous_active) {
      for (st in endogenous_stats) {
        out[[st]] <- event_stat_vals[seq_len(event_counter), st]
      }
    }
    if (global_active) {
      for (cn in global_cov_names) {
        out[[cn]] <- event_global_vals[seq_len(event_counter), cn]
      }
    }
    return(out)
  } else {
    realized_df <- data.frame(
      stratum = seq_len(event_counter),
      event = 1L,
      sender = event_senders[seq_len(event_counter)],
      receiver = event_receivers[seq_len(event_counter)],
      time = event_times[seq_len(event_counter)],
      stringsAsFactors = FALSE
    )

    c_records <- event_counter * n_controls
    control_df <- data.frame(
      stratum = control_strata[seq_len(c_records)],
      event = 0L,
      sender = control_senders[seq_len(c_records)],
      receiver = control_receivers[seq_len(c_records)],
      time = control_times[seq_len(c_records)],
      stringsAsFactors = FALSE
    )

    if (endogenous_active) {
      for (st in endogenous_stats) {
        realized_df[[st]] <- event_stat_vals[seq_len(event_counter), st]
        control_df[[st]] <- control_stat_vals[seq_len(c_records), st]
      }
    }
    if (global_active) {
      for (cn in global_cov_names) {
        realized_df[[cn]] <- event_global_vals[seq_len(event_counter), cn]
        control_df[[cn]] <- control_global_vals[seq_len(c_records), cn]
      }
    }

    out <- rbind(realized_df, control_df)
    out <- out[order(out$time, decreasing = FALSE), ]
    rownames(out) <- NULL
    return(out)
  }
}
