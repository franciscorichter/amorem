#' Simulate directed two-mode hyperedge events
#'
#' Generates a sequence of *directed* hyperevents from a sender set
#' \eqn{I_m \subseteq V^I}{I_m subset of V^I} to a receiver set
#' \eqn{J_m \subseteq V^J}{J_m subset of V^J}, with both \eqn{I_m}{I_m}
#' and \eqn{J_m}{J_m} non-empty. This is the directed two-mode
#' counterpart to [simulate_hyperedge_events()] and matches the data
#' model used in Boschi, Lerner & Wit (2025) Section 5 for
#' citation networks (authors citing papers).
#'
#' At each step the simulator enumerates every candidate hyperedge
#' \eqn{(I, J)}{(I, J)} with
#' \eqn{|I| \in [\mathrm{min\_size\_I}, \mathrm{max\_size\_I}]}{|I| in [min_size_I, max_size_I]}
#' and \eqn{|J| \in [\mathrm{min\_size\_J}, \mathrm{max\_size\_J}]}{|J| in [min_size_J, max_size_J]},
#' computes the rate
#' \deqn{
#'   \lambda(t, I, J) \;=\; \mathrm{baseline\_rate} \;\cdot\;
#'                          \exp\!\left(\sum_k \beta_k \, x_k(t, I, J)\right),
#' }{
#'   lambda(t, I, J) = baseline_rate * exp(sum_k beta_k * x_k(t, I, J)),
#' }
#' and draws one event proportional to its rate. The waiting time
#' is exponential with rate equal to the total intensity.
#'
#' Candidate-space size is exponential in
#' \eqn{|V^I|}{|V^I|} and \eqn{|V^J|}{|V^J|}, so practical use is
#' limited to small actor / item universes (see *Computational cost*
#' in [Limitations and roadmap](https://github.com/franciscorichter/amore/wiki/Limitations-and-roadmap)).
#'
#' @param n_events Number of events to simulate.
#' @param senders Character vector of sender names \eqn{V^I}{V^I}.
#' @param receivers Character vector of receiver names \eqn{V^J}{V^J}.
#'   Must be non-empty.
#' @param min_size_I,max_size_I Sender-side cardinality bounds.
#' @param min_size_J,max_size_J Receiver-side cardinality bounds.
#' @param baseline_rate Multiplicative baseline (\eqn{\lambda_0}{lambda_0}).
#' @param endogenous_stats Character vector of supported stat names:
#'   `"size_I"` (sender-side size penalty), `"size_J"` (receiver-side),
#'   `"activity"` (number of past events covering the full focal
#'   `(I, J)`), `"subrep_<rho>_<l>"` (directed subset repetition,
#'   paper eq. 4).
#' @param endogenous_effects Numeric vector of coefficients,
#'   same length and order as `endogenous_stats`.
#' @param start_time Simulation start time.
#' @return A directed hyperedge log
#'   (`amore_hyperedge_log` data frame with `I`, `J`, `time` columns;
#'   `J` non-empty on every row).
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and
#' Time-Homogeneity: Relational Hyper Event Models with Time-Varying
#' Non-Linear Effects*. arXiv:2509.05289, Section 5.
#' @examples
#' \dontrun{
#' hl <- simulate_directed_hyperedge_events(
#'   n_events  = 40,
#'   senders   = paste0("a", 1:4),
#'   receivers = paste0("p", 1:4),
#'   max_size_I = 2, max_size_J = 2,
#'   baseline_rate = 0.3,
#'   endogenous_stats   = c("subrep_1_1", "size_I"),
#'   endogenous_effects = c(subrep_1_1 = 0.8, size_I = -0.4))
#' }
#' @export
simulate_directed_hyperedge_events <- function(
    n_events, senders, receivers,
    min_size_I = 1L, max_size_I = 1L,
    min_size_J = 1L, max_size_J = 1L,
    baseline_rate = 1,
    endogenous_stats = character(0),
    endogenous_effects = numeric(0),
    start_time = 0) {

  if (!is.numeric(n_events) || length(n_events) != 1 || n_events < 1) {
    stop("`n_events` must be a positive integer.")
  }
  if (!is.character(senders) || !length(senders) || anyDuplicated(senders)) {
    stop("`senders` must be a non-empty character vector with unique entries.")
  }
  if (!is.character(receivers) || !length(receivers) ||
      anyDuplicated(receivers)) {
    stop("`receivers` must be a non-empty character vector with unique entries.")
  }
  if (min_size_I < 1 || min_size_I > max_size_I ||
      max_size_I > length(senders)) {
    stop("`min_size_I` / `max_size_I` must satisfy 1 <= min <= max <= length(senders).")
  }
  if (min_size_J < 1 || min_size_J > max_size_J ||
      max_size_J > length(receivers)) {
    stop("`min_size_J` / `max_size_J` must satisfy 1 <= min <= max <= length(receivers).")
  }
  if (!is.numeric(baseline_rate) || baseline_rate <= 0) {
    stop("`baseline_rate` must be a positive scalar.")
  }
  if (length(endogenous_stats) != length(endogenous_effects)) {
    stop("`endogenous_stats` and `endogenous_effects` must be the same length.")
  }
  allowed <- c("size_I", "size_J", "activity")
  is_subrep <- grepl("^subrep_[0-9]+_[0-9]+$", endogenous_stats)
  bad <- !(endogenous_stats %in% allowed | is_subrep)
  if (any(bad)) {
    stop("Unsupported stat(s): ",
         paste(endogenous_stats[bad], collapse = ", "),
         ". Allowed: size_I, size_J, activity, ",
         "subrep_<rho>_<l> for integer rho >= 1 and l >= 1.")
  }
  beta <- setNames(as.numeric(endogenous_effects), endogenous_stats)
  rho_by_stat <- setNames(integer(length(endogenous_stats)), endogenous_stats)
  l_by_stat   <- setNames(integer(length(endogenous_stats)), endogenous_stats)
  for (st in endogenous_stats) {
    if (st %in% c("size_I", "size_J", "activity")) next
    parts <- strsplit(st, "_", fixed = TRUE)[[1]]
    rho_by_stat[st] <- as.integer(parts[2])
    l_by_stat[st]   <- as.integer(parts[3])
  }

  # Enumerate every candidate hyperedge once: cartesian product of
  # sender subsets x receiver subsets at the allowed cardinalities.
  I_cands <- list()
  for (sz in seq.int(min_size_I, max_size_I)) {
    I_cands <- c(I_cands, utils::combn(senders, sz, simplify = FALSE))
  }
  J_cands <- list()
  for (sz in seq.int(min_size_J, max_size_J)) {
    J_cands <- c(J_cands, utils::combn(receivers, sz, simplify = FALSE))
  }
  # Cartesian product as two-column structure for indexing.
  n_I <- length(I_cands); n_J <- length(J_cands); C <- n_I * n_J
  size_I_per_cand <- rep(vapply(I_cands, length, integer(1)), each = n_J)
  size_J_per_cand <- rep(vapply(J_cands, length, integer(1)), times = n_I)

  history_I    <- vector("list", n_events)
  history_J    <- vector("list", n_events)
  history_time <- numeric(n_events)
  current_time <- start_time
  m_done <- 0L

  count_full_activity <- function(I_focal, J_focal) {
    if (m_done == 0L) return(0L)
    pI <- history_I[seq_len(m_done)]
    pJ <- history_J[seq_len(m_done)]
    ok <- mapply(function(im, jm) {
      all(I_focal %in% im) && all(J_focal %in% jm)
    }, pI, pJ, USE.NAMES = FALSE)
    sum(ok)
  }
  count_subrep <- function(I_focal, J_focal, rho, l) {
    if (m_done == 0L) return(0)
    sub_I <- utils::combn(I_focal, rho, simplify = FALSE)
    sub_J <- utils::combn(J_focal, l,   simplify = FALSE)
    pI <- history_I[seq_len(m_done)]
    pJ <- history_J[seq_len(m_done)]
    tot <- 0
    for (Iv in sub_I) for (Jv in sub_J) {
      ok <- mapply(function(im, jm) {
        all(Iv %in% im) && all(Jv %in% jm)
      }, pI, pJ, USE.NAMES = FALSE)
      tot <- tot + sum(ok)
    }
    tot / (length(sub_I) * length(sub_J))
  }

  for (m in seq_len(n_events)) {
    log_rates <- numeric(C)
    if ("size_I" %in% endogenous_stats) {
      log_rates <- log_rates + beta[["size_I"]] * size_I_per_cand
    }
    if ("size_J" %in% endogenous_stats) {
      log_rates <- log_rates + beta[["size_J"]] * size_J_per_cand
    }
    if (any(c("activity", endogenous_stats[is_subrep]) %in% endogenous_stats)) {
      # Walk each (I, J) candidate.
      for (i in seq_len(n_I)) {
        Iv <- I_cands[[i]]
        for (j in seq_len(n_J)) {
          Jv <- J_cands[[j]]
          idx <- (i - 1L) * n_J + j
          score <- 0
          for (st in endogenous_stats) {
            if (st %in% c("size_I", "size_J")) next
            v <- if (st == "activity") {
              count_full_activity(Iv, Jv)
            } else {
              rho <- rho_by_stat[[st]]
              l   <- l_by_stat[[st]]
              if (rho > length(Iv) || l > length(Jv)) NA_real_
              else count_subrep(Iv, Jv, rho, l)
            }
            if (is.na(v)) { score <- -Inf; break }
            score <- score + beta[[st]] * v
          }
          log_rates[idx] <- log_rates[idx] + score
        }
      }
    }
    rates <- baseline_rate * exp(log_rates)
    rates[!is.finite(rates)] <- 0
    total <- sum(rates)
    if (total <= 0) {
      stop("No candidate hyperedge has positive intensity at step ", m, ".")
    }
    dt <- stats::rexp(1L, rate = total)
    current_time <- current_time + dt
    idx <- sample.int(C, size = 1L, prob = rates / total)
    i_pick <- ((idx - 1L) %/% n_J) + 1L
    j_pick <- ((idx - 1L) %%  n_J) + 1L
    history_I[[m]]  <- I_cands[[i_pick]]
    history_J[[m]]  <- J_cands[[j_pick]]
    history_time[m] <- current_time
    m_done <- m
  }

  hyperedge_log(I = history_I, J = history_J, time = history_time)
}
