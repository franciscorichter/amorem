#' Simulate undirected hyperedge events (multi-actor meetings)
#'
#' Generates a sequence of *undirected* hyperevents — meetings of
#' varying size drawn from the actor set `actors` — under a linear
#' hyperedge model. Mirrors the simulation setup of Boschi, Lerner &
#' Wit (2025) Section 4: each event is a subset of `actors` with size
#' in `1..max_size`, fired with rate
#' \deqn{
#'   \lambda(t, I) \;=\; \mathrm{baseline\_rate} \;\cdot\;
#'                       \exp\!\left(\sum_k \beta_k \, x_k(t, I)\right),
#' }{
#'   lambda(t, I) = baseline_rate * exp(sum_k beta_k * x_k(t, I)),
#' }
#' where each \eqn{x_k(t, I)}{x_k(t, I)} is one of the hyperedge-native
#' covariates supported by `hyperedge_features()`
#' (`activity`, `subrep_<rho>` for undirected events) or `size`
#' (the event's cardinality \eqn{|I|}{|I|}).
#'
#' At each step the simulator enumerates **every subset** of `actors`
#' with size in `1..max_size`. The per-event work is therefore
#' \eqn{O\!\left(\sum_{s=1}^{w} \binom{|V|}{s}\right)}{O(sum_{s=1..w}
#' C(|V|, s))}; practical for small actor counts (e.g. \eqn{|V| \le 20}{|V| <= 20},
#' `max_size <= 4`).
#'
#' @param n_events Number of events to simulate.
#' @param actors Character vector of actor names.
#' @param max_size Maximum allowed meeting size (\eqn{w}{w} in the
#'   paper). Must be in `1..length(actors)`.
#' @param baseline_rate Multiplicative baseline (\eqn{\lambda_0}{lambda_0}).
#' @param endogenous_stats Character vector of stat names accepted by
#'   `hyperedge_features()` (undirected variants — `activity`,
#'   `subrep_1`, `subrep_2`, ...) or the literal `"size"` (the event's
#'   cardinality).
#' @param endogenous_effects Numeric vector of coefficients, same
#'   length and order as `endogenous_stats`.
#' @param start_time Simulation start time.
#' @param min_size Minimum allowed meeting size. Defaults to 1.
#' @return A hyperedge log (see [hyperedge_log()]) with `n_events`
#'   rows.
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
#' Time-Homogeneity: Relational Hyper Event Models with Time-Varying
#' Non-Linear Effects*. arXiv:2509.05289.
#' @examples
#' \dontrun{
#' # Five-actor meetings of size up to 3, with weak attractor on
#' # repeated triads and a size penalty:
#' hl <- simulate_hyperedge_events(
#'   n_events = 50,
#'   actors   = LETTERS[1:5],
#'   max_size = 3,
#'   baseline_rate = 0.2,
#'   endogenous_stats   = c("subrep_2", "size"),
#'   endogenous_effects = c(subrep_2 = 0.5, size = -0.3))
#' }
#' @export
simulate_hyperedge_events <- function(n_events, actors, max_size,
                                       baseline_rate,
                                       endogenous_stats = character(0),
                                       endogenous_effects = numeric(0),
                                       start_time = 0,
                                       min_size = 1L) {
  if (!is.numeric(n_events) || length(n_events) != 1 || n_events < 1) {
    stop("`n_events` must be a positive integer.")
  }
  if (!is.character(actors) || !length(actors) || anyDuplicated(actors)) {
    stop("`actors` must be a non-empty character vector with unique entries.")
  }
  if (!is.numeric(max_size) || max_size < 1 || max_size > length(actors)) {
    stop("`max_size` must be in 1..length(actors).")
  }
  if (!is.numeric(min_size) || min_size < 1 || min_size > max_size) {
    stop("`min_size` must be in 1..max_size.")
  }
  if (!is.numeric(baseline_rate) || baseline_rate <= 0) {
    stop("`baseline_rate` must be a positive scalar.")
  }
  if (length(endogenous_stats) != length(endogenous_effects)) {
    stop("`endogenous_stats` and `endogenous_effects` must be the same length.")
  }
  allowed <- c("size", "activity")
  is_subrep <- grepl("^subrep_[0-9]+$", endogenous_stats)
  bad <- !(endogenous_stats %in% allowed | is_subrep)
  if (any(bad)) {
    stop("Unsupported hyperedge stat(s): ",
         paste(endogenous_stats[bad], collapse = ", "),
         ". Allowed: ", paste(allowed, collapse = ", "),
         ", and subrep_<rho> for integer rho >= 1.")
  }
  # Coefficients indexed by stat name for fast lookup.
  beta <- setNames(as.numeric(endogenous_effects), endogenous_stats)
  rho_by_stat <- setNames(
    vapply(endogenous_stats, function(s) {
      if (s == "size" || s == "activity") return(NA_integer_)
      as.integer(sub("subrep_", "", s, fixed = TRUE))
    }, integer(1)),
    endogenous_stats)

  # Pre-enumerate every candidate subset of size min_size..max_size.
  candidates <- list()
  for (sz in seq.int(min_size, max_size)) {
    combs <- utils::combn(actors, sz, simplify = FALSE)
    candidates <- c(candidates, combs)
  }
  C <- length(candidates)
  sizes <- vapply(candidates, length, integer(1))

  # Rolling event history. We materialise the hyperedge log at the end.
  history_I    <- vector("list", n_events)
  history_time <- numeric(n_events)
  current_time <- start_time

  # Per-candidate score. The size term is constant per candidate; the
  # event-history terms (activity, subrep_<rho>) update as events fire.
  # Helper: subset-activity counter from scratch over the rolling history
  # up to and including row `m_done`.
  count_activity <- function(I_focal, rho) {
    if (m_done == 0L) return(0)
    sub <- utils::combn(I_focal, rho, simplify = FALSE)
    n_subs <- length(sub)
    total <- 0
    past_I <- history_I[seq_len(m_done)]
    for (Iv in sub) {
      ok <- vapply(past_I, function(im) all(Iv %in% im), logical(1))
      total <- total + sum(ok)
    }
    total / n_subs
  }
  count_full_activity <- function(I_focal) {
    if (m_done == 0L) return(0L)
    past_I <- history_I[seq_len(m_done)]
    sum(vapply(past_I, function(im) all(I_focal %in% im), logical(1)))
  }

  m_done <- 0L
  for (m in seq_len(n_events)) {
    # Score every candidate.
    log_rates <- numeric(C)
    if ("size" %in% endogenous_stats) {
      log_rates <- log_rates + beta[["size"]] * sizes
    }
    if ("activity" %in% endogenous_stats || any(is_subrep)) {
      for (i in seq_len(C)) {
        cand <- candidates[[i]]
        score_endo <- 0
        for (st in endogenous_stats) {
          if (st == "size") next
          v <- if (st == "activity") {
            count_full_activity(cand)
          } else {
            rho <- rho_by_stat[[st]]
            if (rho > length(cand)) NA_real_ else count_activity(cand, rho)
          }
          if (is.na(v)) { score_endo <- -Inf; break }
          score_endo <- score_endo + beta[[st]] * v
        }
        log_rates[i] <- log_rates[i] + score_endo
      }
    }
    rates <- baseline_rate * exp(log_rates)
    rates[!is.finite(rates)] <- 0
    total_rate <- sum(rates)
    if (total_rate <= 0) {
      stop("No candidate hyperedge has positive intensity at step ", m, ".")
    }
    dt <- stats::rexp(1L, rate = total_rate)
    current_time <- current_time + dt
    idx <- sample.int(C, size = 1L, prob = rates / total_rate)
    history_I[[m]]    <- candidates[[idx]]
    history_time[m]   <- current_time
    m_done <- m
  }

  hyperedge_log(
    I    = history_I,
    J    = replicate(n_events, character(0), simplify = FALSE),
    time = history_time)
}
