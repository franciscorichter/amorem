#' Activity counter for hyperedge subsets
#'
#' For a focal candidate hyperedge \eqn{(t, I, J)}{(t, I, J)},
#' `activity(t, I, J)` counts the number of past events
#' \eqn{(t_m, I_m, J_m)}{(t_m, I_m, J_m)} with \eqn{t_m < t}{t_m < t}
#' satisfying \eqn{I \subseteq I_m}{I in I_m} AND
#' \eqn{J \subseteq J_m}{J in J_m}.
#'
#' @param hyperedge_log A hyperedge log (see [hyperedge_log()]).
#' @param I Character vector of sender names defining the focal subset.
#' @param J Character vector of receiver names defining the focal
#'   subset. Pass `character(0)` to ignore the receiver side
#'   (undirected events).
#' @param t Focal time. Only events strictly before `t` contribute.
#' @return A single non-negative integer.
#' @references
#' Lerner J, Boschi M, Wit EC (2025). Subset repetition.
#' @export
hyperedge_activity <- function(hyperedge_log, I, J = character(0), t) {
  if (!is_hyperedge_log(hyperedge_log)) {
    stop("`hyperedge_log` is not a hyperedge log.")
  }
  if (!is.character(I)) stop("`I` must be a character vector.")
  if (!is.character(J)) stop("`J` must be a character vector.")
  if (length(t) != 1 || !is.numeric(t)) stop("`t` must be a numeric scalar.")
  hits <- 0L
  prior <- hyperedge_log$time < t
  for (m in which(prior)) {
    if (all(I %in% hyperedge_log$I[[m]]) &&
        all(J %in% hyperedge_log$J[[m]])) {
      hits <- hits + 1L
    }
  }
  hits
}

#' Subset repetition statistic for a hyperedge event log
#'
#' For a focal hyperedge \eqn{(t, I, J)}{(t, I, J)} and orders
#' \eqn{(\rho, \ell)}{(rho, l)}, computes the **average activity** over
#' every sender subset of `I` of size `rho` and every receiver subset
#' of `J` of size `l`, per Boschi, Lerner & Wit (2025) Equation 4:
#' \deqn{
#'   \mathrm{subrep}^{\rho,\ell}(t,I,J)
#'   = \frac{1}{\binom{|I|}{\rho}\binom{|J|}{\ell}}
#'     \sum_{I' \subseteq I,\ |I'|=\rho}
#'     \sum_{J' \subseteq J,\ |J'|=\ell}
#'     \mathrm{activity}(t, I', J').
#' }
#'
#' For dyadic events with \eqn{|I| = |J| = 1}{|I|=|J|=1},
#' `subrep(rho = 1, l = 1)` reduces to the dyad event count
#' (already exposed as `reciprocity_count` and related stats in
#' [endogenous_features()]). The function exists because
#' for true hyperedge data the average over subsets of intermediate
#' size captures partial-subset repetition that no dyadic statistic
#' can represent.
#'
#' @param hyperedge_log A hyperedge log (see [hyperedge_log()]).
#' @param I Character vector of senders for the focal event.
#' @param J Character vector of receivers (or `character(0)` for
#'   undirected).
#' @param t Focal time.
#' @param rho Order on the sender side: subset cardinality. Must be
#'   between 1 and `length(I)`. Defaults to `length(I)` (full subset).
#' @param l Order on the receiver side: subset cardinality. Must be
#'   between 0 and `length(J)`. Defaults to `length(J)` (full subset);
#'   pass 0 to ignore receivers (undirected).
#' @return A single non-negative numeric.
#' @references
#' Boschi M, Lerner J, Wit EC (2025). *Beyond Linearity and Time-
#' Homogeneity: Relational Hyper Event Models with Time-Varying
#' Non-Linear Effects*. arXiv:2509.05289.
#' Lerner J, et al. (2025). The eventnet computation framework.
#' @examples
#' hl <- hyperedge_log(
#'   I    = list(c("a","b"), c("a","c"), c("b","c")),
#'   J    = list(c("X"),     c("X","Y"), c("Y")),
#'   time = c(1, 2, 3))
#' # Activity for the (a, X) sub-pair before t = 4:
#' hyperedge_activity(hl, I = "a", J = "X", t = 4)
#' # First-order subrep on event (a, b) -> X at t = 4:
#' hyperedge_subrep(hl, I = c("a","b"), J = "X", t = 4, rho = 1, l = 1)
#' @export
hyperedge_subrep <- function(hyperedge_log, I, J = character(0), t,
                              rho = length(I),
                              l   = length(J)) {
  if (!is_hyperedge_log(hyperedge_log)) {
    stop("`hyperedge_log` is not a hyperedge log.")
  }
  if (!is.character(I) || !length(I)) {
    stop("`I` must be a non-empty character vector.")
  }
  if (!is.character(J)) stop("`J` must be a character vector.")
  if (rho < 1L || rho > length(I)) {
    stop("`rho` must be between 1 and length(I).")
  }
  if (l < 0L || l > length(J)) {
    stop("`l` must be between 0 and length(J).")
  }
  if (length(t) != 1 || !is.numeric(t)) stop("`t` must be a numeric scalar.")

  prior_idx <- which(hyperedge_log$time < t)
  if (!length(prior_idx)) return(0)

  # Precompute, for every prior event, whether each requested actor
  # is among its participants -- avoids quadratic re-membership lookups.
  prior_I <- hyperedge_log$I[prior_idx]
  prior_J <- hyperedge_log$J[prior_idx]

  # Enumerate sender / receiver subsets.
  I_sub <- if (rho == 0L) list(character(0)) else
           utils::combn(I, rho, simplify = FALSE)
  J_sub <- if (l == 0L)   list(character(0)) else
           utils::combn(J, l,   simplify = FALSE)

  total <- 0
  for (Iv in I_sub) {
    # Per-prior-event boolean: I' ⊆ I_m  (vectorised over prior events)
    ok_I <- vapply(prior_I, function(im) all(Iv %in% im), logical(1))
    for (Jv in J_sub) {
      ok_J <- if (!length(Jv)) rep(TRUE, length(prior_idx)) else
              vapply(prior_J, function(jm) all(Jv %in% jm), logical(1))
      total <- total + sum(ok_I & ok_J)
    }
  }
  total / (length(I_sub) * length(J_sub))
}
