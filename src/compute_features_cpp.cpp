// compute_features_cpp.cpp
//
// C++ inner loop for compute_endogenous_features(), covering the
// count / binary / per-actor stat families plus the four closure
// families' time_recent / time_first / exp_decay variants:
//
//   reciprocity_binary, reciprocity_count, reciprocity (alias),
//   transitivity_binary, transitivity_count,
//   cyclic_binary, cyclic_count,
//   sending_balance_binary, sending_balance_count,
//   receiving_balance_binary, receiving_balance_count,
//   sender_outdegree, receiver_indegree,
//   recency,
//   {transitivity, cyclic, sending_balance,
//    receiving_balance}_{time_recent, time_first, exp_decay}.
//
// State is held in integer-indexed std::vector / unordered_map
// containers, eliminating the env-based string lookups that the R
// profile identified as 80% of the per-event cost.
//
// The ordered / interrupted variants are NOT yet covered here;
// the R caller dispatches to this C++ entry point only when every
// requested stat is in the supported subset, and falls back to the
// existing R implementation otherwise.

#include <Rcpp.h>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>

using namespace Rcpp;

// Bit flags identifying which stats the caller wants. Avoids
// per-event string comparisons in the inner loop.
enum StatFlag : uint64_t {
  F_RECIPROCITY        = UINT64_C(1) << 0,
  F_RECIPROCITY_BINARY = UINT64_C(1) << 1,
  F_RECIPROCITY_COUNT  = UINT64_C(1) << 2,
  F_TRANSITIVITY_BINARY = UINT64_C(1) << 3,
  F_TRANSITIVITY_COUNT  = UINT64_C(1) << 4,
  F_CYCLIC_BINARY       = UINT64_C(1) << 5,
  F_CYCLIC_COUNT        = UINT64_C(1) << 6,
  F_SENDING_BALANCE_BINARY = UINT64_C(1) << 7,
  F_SENDING_BALANCE_COUNT  = UINT64_C(1) << 8,
  F_RECEIVING_BALANCE_BINARY = UINT64_C(1) << 9,
  F_RECEIVING_BALANCE_COUNT  = UINT64_C(1) << 10,
  F_SENDER_OUTDEGREE  = UINT64_C(1) << 11,
  F_RECEIVER_INDEGREE = UINT64_C(1) << 12,
  F_RECENCY           = UINT64_C(1) << 13,
  F_TRANSITIVITY_TIME_RECENT      = UINT64_C(1) << 14,
  F_TRANSITIVITY_TIME_FIRST       = UINT64_C(1) << 15,
  F_CYCLIC_TIME_RECENT            = UINT64_C(1) << 16,
  F_CYCLIC_TIME_FIRST             = UINT64_C(1) << 17,
  F_SENDING_BALANCE_TIME_RECENT   = UINT64_C(1) << 18,
  F_SENDING_BALANCE_TIME_FIRST    = UINT64_C(1) << 19,
  F_RECEIVING_BALANCE_TIME_RECENT = UINT64_C(1) << 20,
  F_RECEIVING_BALANCE_TIME_FIRST  = UINT64_C(1) << 21,
  F_TRANSITIVITY_EXP_DECAY        = UINT64_C(1) << 22,
  F_CYCLIC_EXP_DECAY              = UINT64_C(1) << 23,
  F_SENDING_BALANCE_EXP_DECAY     = UINT64_C(1) << 24,
  F_RECEIVING_BALANCE_EXP_DECAY   = UINT64_C(1) << 25,
  // *_interrupted: same chain accumulators as the non-interrupted
  // variants, gated by formation_k > t_closure(s, r) where
  // t_closure = last time the focal dyad (s, r) fired (or -inf).
  F_TRANSITIVITY_COUNT_INTERRUPTED       = UINT64_C(1) << 26,
  F_TRANSITIVITY_BINARY_INTERRUPTED      = UINT64_C(1) << 27,
  F_TRANSITIVITY_EXP_DECAY_INTERRUPTED   = UINT64_C(1) << 28,
  F_TRANSITIVITY_TIME_RECENT_INTERRUPTED = UINT64_C(1) << 29,
  F_TRANSITIVITY_TIME_FIRST_INTERRUPTED  = UINT64_C(1) << 30,
  F_CYCLIC_COUNT_INTERRUPTED             = UINT64_C(1) << 31,
  F_CYCLIC_BINARY_INTERRUPTED            = UINT64_C(1) << 32,
  F_CYCLIC_EXP_DECAY_INTERRUPTED         = UINT64_C(1) << 33,
  F_CYCLIC_TIME_RECENT_INTERRUPTED       = UINT64_C(1) << 34,
  F_CYCLIC_TIME_FIRST_INTERRUPTED        = UINT64_C(1) << 35,
  F_SENDING_BALANCE_COUNT_INTERRUPTED       = UINT64_C(1) << 36,
  F_SENDING_BALANCE_BINARY_INTERRUPTED      = UINT64_C(1) << 37,
  F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED   = UINT64_C(1) << 38,
  F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED = UINT64_C(1) << 39,
  F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED  = UINT64_C(1) << 40,
  F_RECEIVING_BALANCE_COUNT_INTERRUPTED       = UINT64_C(1) << 41,
  F_RECEIVING_BALANCE_BINARY_INTERRUPTED      = UINT64_C(1) << 42,
  F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED   = UINT64_C(1) << 43,
  F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED = UINT64_C(1) << 44,
  F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED  = UINT64_C(1) << 45,
  // *_count_ordered / *_binary_ordered: ordered-validation state
  // matrix maintained event-by-event, mirroring the R simulator's
  // apply_ordered_update logic.
  F_TRANSITIVITY_COUNT_ORDERED        = UINT64_C(1) << 46,
  F_TRANSITIVITY_BINARY_ORDERED       = UINT64_C(1) << 47,
  F_CYCLIC_COUNT_ORDERED              = UINT64_C(1) << 48,
  F_CYCLIC_BINARY_ORDERED             = UINT64_C(1) << 49,
  F_SENDING_BALANCE_COUNT_ORDERED     = UINT64_C(1) << 50,
  F_SENDING_BALANCE_BINARY_ORDERED    = UINT64_C(1) << 51,
  F_RECEIVING_BALANCE_COUNT_ORDERED   = UINT64_C(1) << 52,
  F_RECEIVING_BALANCE_BINARY_ORDERED  = UINT64_C(1) << 53
};

// Second mask word -- bits 0..63 of `active` are full above. The
// ordered timing / exp_decay variants live here.
enum StatFlagExtra : uint64_t {
  FE_TRANSITIVITY_TIME_RECENT_ORDERED      = UINT64_C(1) << 0,
  FE_TRANSITIVITY_TIME_FIRST_ORDERED       = UINT64_C(1) << 1,
  FE_TRANSITIVITY_EXP_DECAY_ORDERED        = UINT64_C(1) << 2,
  FE_CYCLIC_TIME_RECENT_ORDERED            = UINT64_C(1) << 3,
  FE_CYCLIC_TIME_FIRST_ORDERED             = UINT64_C(1) << 4,
  FE_CYCLIC_EXP_DECAY_ORDERED              = UINT64_C(1) << 5,
  FE_SENDING_BALANCE_TIME_RECENT_ORDERED   = UINT64_C(1) << 6,
  FE_SENDING_BALANCE_TIME_FIRST_ORDERED    = UINT64_C(1) << 7,
  FE_SENDING_BALANCE_EXP_DECAY_ORDERED     = UINT64_C(1) << 8,
  FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED = UINT64_C(1) << 9,
  FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED  = UINT64_C(1) << 10,
  FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED   = UINT64_C(1) << 11
};

static const std::vector<std::string> SUPPORTED_STATS = {
  "reciprocity", "reciprocity_binary", "reciprocity_count",
  "transitivity_binary", "transitivity_count",
  "cyclic_binary", "cyclic_count",
  "sending_balance_binary", "sending_balance_count",
  "receiving_balance_binary", "receiving_balance_count",
  "sender_outdegree", "receiver_indegree", "recency",
  "transitivity_time_recent", "transitivity_time_first",
  "cyclic_time_recent", "cyclic_time_first",
  "sending_balance_time_recent", "sending_balance_time_first",
  "receiving_balance_time_recent", "receiving_balance_time_first",
  "transitivity_exp_decay", "cyclic_exp_decay",
  "sending_balance_exp_decay", "receiving_balance_exp_decay",
  "transitivity_count_interrupted", "transitivity_binary_interrupted",
  "transitivity_exp_decay_interrupted",
  "transitivity_time_recent_interrupted",
  "transitivity_time_first_interrupted",
  "cyclic_count_interrupted", "cyclic_binary_interrupted",
  "cyclic_exp_decay_interrupted",
  "cyclic_time_recent_interrupted", "cyclic_time_first_interrupted",
  "sending_balance_count_interrupted",
  "sending_balance_binary_interrupted",
  "sending_balance_exp_decay_interrupted",
  "sending_balance_time_recent_interrupted",
  "sending_balance_time_first_interrupted",
  "receiving_balance_count_interrupted",
  "receiving_balance_binary_interrupted",
  "receiving_balance_exp_decay_interrupted",
  "receiving_balance_time_recent_interrupted",
  "receiving_balance_time_first_interrupted",
  "transitivity_count_ordered", "transitivity_binary_ordered",
  "cyclic_count_ordered", "cyclic_binary_ordered",
  "sending_balance_count_ordered", "sending_balance_binary_ordered",
  "receiving_balance_count_ordered", "receiving_balance_binary_ordered",
  "transitivity_time_recent_ordered", "transitivity_time_first_ordered",
  "transitivity_exp_decay_ordered",
  "cyclic_time_recent_ordered", "cyclic_time_first_ordered",
  "cyclic_exp_decay_ordered",
  "sending_balance_time_recent_ordered", "sending_balance_time_first_ordered",
  "sending_balance_exp_decay_ordered",
  "receiving_balance_time_recent_ordered", "receiving_balance_time_first_ordered",
  "receiving_balance_exp_decay_ordered"
};

static uint64_t flag_for(const std::string& s) {
  if (s == "reciprocity")              return F_RECIPROCITY;
  if (s == "reciprocity_binary")       return F_RECIPROCITY_BINARY;
  if (s == "reciprocity_count")        return F_RECIPROCITY_COUNT;
  if (s == "transitivity_binary")      return F_TRANSITIVITY_BINARY;
  if (s == "transitivity_count")       return F_TRANSITIVITY_COUNT;
  if (s == "cyclic_binary")            return F_CYCLIC_BINARY;
  if (s == "cyclic_count")             return F_CYCLIC_COUNT;
  if (s == "sending_balance_binary")   return F_SENDING_BALANCE_BINARY;
  if (s == "sending_balance_count")    return F_SENDING_BALANCE_COUNT;
  if (s == "receiving_balance_binary") return F_RECEIVING_BALANCE_BINARY;
  if (s == "receiving_balance_count")  return F_RECEIVING_BALANCE_COUNT;
  if (s == "sender_outdegree")         return F_SENDER_OUTDEGREE;
  if (s == "receiver_indegree")        return F_RECEIVER_INDEGREE;
  if (s == "recency")                  return F_RECENCY;
  if (s == "transitivity_time_recent")      return F_TRANSITIVITY_TIME_RECENT;
  if (s == "transitivity_time_first")       return F_TRANSITIVITY_TIME_FIRST;
  if (s == "cyclic_time_recent")            return F_CYCLIC_TIME_RECENT;
  if (s == "cyclic_time_first")             return F_CYCLIC_TIME_FIRST;
  if (s == "sending_balance_time_recent")   return F_SENDING_BALANCE_TIME_RECENT;
  if (s == "sending_balance_time_first")    return F_SENDING_BALANCE_TIME_FIRST;
  if (s == "receiving_balance_time_recent") return F_RECEIVING_BALANCE_TIME_RECENT;
  if (s == "receiving_balance_time_first")  return F_RECEIVING_BALANCE_TIME_FIRST;
  if (s == "transitivity_exp_decay")        return F_TRANSITIVITY_EXP_DECAY;
  if (s == "cyclic_exp_decay")              return F_CYCLIC_EXP_DECAY;
  if (s == "sending_balance_exp_decay")     return F_SENDING_BALANCE_EXP_DECAY;
  if (s == "receiving_balance_exp_decay")   return F_RECEIVING_BALANCE_EXP_DECAY;
  if (s == "transitivity_count_interrupted")        return F_TRANSITIVITY_COUNT_INTERRUPTED;
  if (s == "transitivity_binary_interrupted")       return F_TRANSITIVITY_BINARY_INTERRUPTED;
  if (s == "transitivity_exp_decay_interrupted")    return F_TRANSITIVITY_EXP_DECAY_INTERRUPTED;
  if (s == "transitivity_time_recent_interrupted")  return F_TRANSITIVITY_TIME_RECENT_INTERRUPTED;
  if (s == "transitivity_time_first_interrupted")   return F_TRANSITIVITY_TIME_FIRST_INTERRUPTED;
  if (s == "cyclic_count_interrupted")              return F_CYCLIC_COUNT_INTERRUPTED;
  if (s == "cyclic_binary_interrupted")             return F_CYCLIC_BINARY_INTERRUPTED;
  if (s == "cyclic_exp_decay_interrupted")          return F_CYCLIC_EXP_DECAY_INTERRUPTED;
  if (s == "cyclic_time_recent_interrupted")        return F_CYCLIC_TIME_RECENT_INTERRUPTED;
  if (s == "cyclic_time_first_interrupted")         return F_CYCLIC_TIME_FIRST_INTERRUPTED;
  if (s == "sending_balance_count_interrupted")       return F_SENDING_BALANCE_COUNT_INTERRUPTED;
  if (s == "sending_balance_binary_interrupted")      return F_SENDING_BALANCE_BINARY_INTERRUPTED;
  if (s == "sending_balance_exp_decay_interrupted")   return F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED;
  if (s == "sending_balance_time_recent_interrupted") return F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED;
  if (s == "sending_balance_time_first_interrupted")  return F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED;
  if (s == "receiving_balance_count_interrupted")       return F_RECEIVING_BALANCE_COUNT_INTERRUPTED;
  if (s == "receiving_balance_binary_interrupted")      return F_RECEIVING_BALANCE_BINARY_INTERRUPTED;
  if (s == "receiving_balance_exp_decay_interrupted")   return F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED;
  if (s == "receiving_balance_time_recent_interrupted") return F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED;
  if (s == "receiving_balance_time_first_interrupted")  return F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED;
  if (s == "transitivity_count_ordered")       return F_TRANSITIVITY_COUNT_ORDERED;
  if (s == "transitivity_binary_ordered")      return F_TRANSITIVITY_BINARY_ORDERED;
  if (s == "cyclic_count_ordered")             return F_CYCLIC_COUNT_ORDERED;
  if (s == "cyclic_binary_ordered")            return F_CYCLIC_BINARY_ORDERED;
  if (s == "sending_balance_count_ordered")    return F_SENDING_BALANCE_COUNT_ORDERED;
  if (s == "sending_balance_binary_ordered")   return F_SENDING_BALANCE_BINARY_ORDERED;
  if (s == "receiving_balance_count_ordered")  return F_RECEIVING_BALANCE_COUNT_ORDERED;
  if (s == "receiving_balance_binary_ordered") return F_RECEIVING_BALANCE_BINARY_ORDERED;
  return UINT64_C(0);
}

// Companion lookup for the StatFlagExtra mask (bits 0..11 carry the
// ordered timing / exp_decay variants that no longer fit in `active`).
static uint64_t flag_for_extra(const std::string& s) {
  if (s == "transitivity_time_recent_ordered")      return FE_TRANSITIVITY_TIME_RECENT_ORDERED;
  if (s == "transitivity_time_first_ordered")       return FE_TRANSITIVITY_TIME_FIRST_ORDERED;
  if (s == "transitivity_exp_decay_ordered")        return FE_TRANSITIVITY_EXP_DECAY_ORDERED;
  if (s == "cyclic_time_recent_ordered")            return FE_CYCLIC_TIME_RECENT_ORDERED;
  if (s == "cyclic_time_first_ordered")             return FE_CYCLIC_TIME_FIRST_ORDERED;
  if (s == "cyclic_exp_decay_ordered")              return FE_CYCLIC_EXP_DECAY_ORDERED;
  if (s == "sending_balance_time_recent_ordered")   return FE_SENDING_BALANCE_TIME_RECENT_ORDERED;
  if (s == "sending_balance_time_first_ordered")    return FE_SENDING_BALANCE_TIME_FIRST_ORDERED;
  if (s == "sending_balance_exp_decay_ordered")     return FE_SENDING_BALANCE_EXP_DECAY_ORDERED;
  if (s == "receiving_balance_time_recent_ordered") return FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED;
  if (s == "receiving_balance_time_first_ordered")  return FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED;
  if (s == "receiving_balance_exp_decay_ordered")   return FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED;
  return UINT64_C(0);
}

// Ordered-family bitmasks: which flags belong to each family on the
// ordered-validation path. The validation sweep runs once per family
// per event when any of the family's flags are active.
static constexpr uint64_t F_TRANSITIVITY_ORDERED_ANY      = F_TRANSITIVITY_COUNT_ORDERED      | F_TRANSITIVITY_BINARY_ORDERED;
static constexpr uint64_t F_CYCLIC_ORDERED_ANY            = F_CYCLIC_COUNT_ORDERED            | F_CYCLIC_BINARY_ORDERED;
static constexpr uint64_t F_SENDING_BALANCE_ORDERED_ANY   = F_SENDING_BALANCE_COUNT_ORDERED   | F_SENDING_BALANCE_BINARY_ORDERED;
static constexpr uint64_t F_RECEIVING_BALANCE_ORDERED_ANY = F_RECEIVING_BALANCE_COUNT_ORDERED | F_RECEIVING_BALANCE_BINARY_ORDERED;

static constexpr uint64_t F_ANY_EXP_DECAY =
  F_TRANSITIVITY_EXP_DECAY | F_CYCLIC_EXP_DECAY |
  F_SENDING_BALANCE_EXP_DECAY | F_RECEIVING_BALANCE_EXP_DECAY |
  F_TRANSITIVITY_EXP_DECAY_INTERRUPTED |
  F_CYCLIC_EXP_DECAY_INTERRUPTED |
  F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED |
  F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED;

// Sorted-set intersection of two ascending integer vectors a, b.
// Returns the integer count of elements that appear in both AND
// equal neither `excl_s` nor `excl_r` (the focal sender/receiver
// indices, which are excluded as intermediaries by definition).
static int sorted_intersect_count(const std::vector<int>& a,
                                  const std::vector<int>& b,
                                  int excl_s, int excl_r) {
  int i = 0, j = 0, count = 0;
  while (i < (int)a.size() && j < (int)b.size()) {
    if (a[i] < b[j]) {
      ++i;
    } else if (a[i] > b[j]) {
      ++j;
    } else {
      int v = a[i];
      if (v != excl_s && v != excl_r) ++count;
      ++i; ++j;
    }
  }
  return count;
}

// Per-family accumulators collected during a single walk through the
// intersection of two sorted ascending integer vectors. Mirrors
// compute_triadic's accumulators on the post-hoc side
// (R/preprocess.R): regular bucket covers every validated k; the
// interrupted bucket additionally requires `formation > t_closure`
// (the most recent prior firing of the focal (s, r) dyad).
struct FamilyAccumulator {
  int    n      = 0;
  double f_min  =  std::numeric_limits<double>::infinity();
  double f_max  = -std::numeric_limits<double>::infinity();
  double e_sum  = 0.0;
  int    n_int     = 0;
  double f_int_min =  std::numeric_limits<double>::infinity();
  double f_int_max = -std::numeric_limits<double>::infinity();
  double e_int_sum = 0.0;
};

// Walk the intersection of two sorted ascending integer vectors and
// fill `acc` with per-k formation aggregates. For each
// `k ∈ (a ∩ b) \ {excl_s, excl_r}`, formation_k =
// max(first[leg1_key(k)], first[leg2_key(k)]). `t_closure` is the
// most recent prior firing of the focal (s, r) dyad (or -∞ if none);
// the interrupted-bucket gate is `formation > t_closure`. The
// per-k exp_decay contribution is `exp(-(t_now - formation_k) *
// decay_rate)`; exp() is only called when its respective
// `need_exp{_int}` flag is on.
template <typename L1, typename L2>
static void walk_intersect_formation(const std::vector<int>& a,
                                     const std::vector<int>& b,
                                     int excl_s, int excl_r,
                                     const std::unordered_map<long long, double>& first_map,
                                     L1 leg1_key, L2 leg2_key,
                                     double t_now, double decay_rate,
                                     double t_closure,
                                     bool need_exp, bool need_int_exp,
                                     bool need_int_any,
                                     FamilyAccumulator& acc) {
  acc = FamilyAccumulator();
  int i = 0, j = 0;
  while (i < (int)a.size() && j < (int)b.size()) {
    if (a[i] < b[j]) {
      ++i;
    } else if (a[i] > b[j]) {
      ++j;
    } else {
      int k = a[i];
      if (k != excl_s && k != excl_r) {
        long long k1 = leg1_key(k);
        long long k2 = leg2_key(k);
        auto it1 = first_map.find(k1);
        auto it2 = first_map.find(k2);
        // By construction both legs exist (k is in out_targets/in_sources
        // intersection, so both directed edges have been seen at least
        // once), so the lookups must succeed.
        if (it1 != first_map.end() && it2 != first_map.end()) {
          double form = std::max(it1->second, it2->second);
          if (form > acc.f_max) acc.f_max = form;
          if (form < acc.f_min) acc.f_min = form;
          double decay_contrib = 0.0;
          if (need_exp || need_int_exp) {
            decay_contrib = std::exp(-(t_now - form) * decay_rate);
          }
          if (need_exp) acc.e_sum += decay_contrib;
          ++acc.n;
          if (need_int_any && form > t_closure) {
            if (form > acc.f_int_max) acc.f_int_max = form;
            if (form < acc.f_int_min) acc.f_int_min = form;
            if (need_int_exp) acc.e_int_sum += decay_contrib;
            ++acc.n_int;
          }
        }
      }
      ++i; ++j;
    }
  }
}

// Insert `v` into the sorted vector `vec` if not already present.
static inline void sorted_insert_unique(std::vector<int>& vec, int v) {
  auto it = std::lower_bound(vec.begin(), vec.end(), v);
  if (it == vec.end() || *it != v) vec.insert(it, v);
}

// [[Rcpp::export(rng = false)]]
List compute_features_cpp(CharacterVector senders,
                          CharacterVector receivers,
                          NumericVector times,
                          CharacterVector stat_names,
                          LogicalVector is_event,
                          double half_life = NA_REAL) {

  const R_xlen_t n = senders.size();
  if (n != receivers.size() || n != times.size()) {
    stop("senders, receivers, times must have the same length.");
  }
  // `is_event` marks which rows update the running history state. Length 0
  // means "every row is an event" (the default, history-free behaviour);
  // otherwise rows with is_event[i] == FALSE are read-only -- their
  // statistics are computed, but they never enter the history (used so that
  // sampled non-events / controls do not pollute the event history).
  const bool mask_active = (is_event.size() > 0);
  if (mask_active && is_event.size() != n) {
    stop("is_event must have length 0 (all events) or length n.");
  }

  uint64_t active = 0u;
  uint64_t active_extra = 0u;
  for (R_xlen_t i = 0; i < stat_names.size(); ++i) {
    const std::string s = as<std::string>(stat_names[i]);
    uint64_t f  = flag_for(s);
    uint64_t fe = flag_for_extra(s);
    if (f == 0u && fe == 0u) {
      stop("Stat not supported by the C++ inner loop: " + s);
    }
    active       |= f;
    active_extra |= fe;
  }

  // exp_decay stats require a positive finite half-life. Mirrors the
  // pure-R caller's validation so the dispatch is transparent.
  double decay_rate = 0.0;
  bool any_extra_exp_decay =
       (active_extra & FE_TRANSITIVITY_EXP_DECAY_ORDERED) ||
       (active_extra & FE_CYCLIC_EXP_DECAY_ORDERED) ||
       (active_extra & FE_SENDING_BALANCE_EXP_DECAY_ORDERED) ||
       (active_extra & FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED);
  if ((active & F_ANY_EXP_DECAY) || any_extra_exp_decay) {
    if (!R_finite(half_life) || half_life <= 0.0) {
      stop("`half_life` must be a positive finite number when an "
           "exp_decay statistic is requested.");
    }
    decay_rate = std::log(2.0) / half_life;
  }

  // 1. Map actor IDs to integer indices (unified universe).
  std::unordered_map<std::string, int> actor_id;
  std::vector<std::string> id_to_actor;
  auto intern = [&](SEXP s) {
    std::string k = as<std::string>(s);
    auto it = actor_id.find(k);
    if (it == actor_id.end()) {
      int idx = (int)id_to_actor.size();
      actor_id.emplace(k, idx);
      id_to_actor.push_back(k);
      return idx;
    }
    return it->second;
  };

  // First pass: assign integer IDs in event order.
  std::vector<int> s_idx(n), r_idx(n);
  for (R_xlen_t i = 0; i < n; ++i) {
    s_idx[i] = intern(senders[i]);
    r_idx[i] = intern(receivers[i]);
  }
  const int A = (int)id_to_actor.size();

  // 2. State containers.
  std::vector<long> sender_count(A, 0);
  std::vector<long> receiver_count(A, 0);
  // Dyad event count, keyed by (s, r) -> long. dyad_key = (long long)s * A + r
  // is unique for s, r in [0, A).
  std::unordered_map<long long, long> dyad_event_count;
  // Last and first event time per ordered dyad.
  std::unordered_map<long long, double> dyad_last_time;
  std::unordered_map<long long, double> dyad_first_time;
  // No per-family ordered state is maintained -- the count is
  // recomputed at every focal event via a direct walk of the
  // family's intersection, mirroring compute_triadic in
  // R/preprocess.R. The check per intermediary k is
  //   last_dyad_time[leg2_dyad(k)] > first_dyad_time[leg1_dyad(k)]
  // which is equivalent to compute_triadic's
  //   any(e2 > min(e1))
  // and avoids the tied-timestamp bug that the simulator's
  // incremental apply_ordered_update path has.
  //
  // For the ORDERED TIMING / EXP_DECAY variants we additionally
  // need the *time of validation*, formation_ord(k) =
  // min(e2 > min(e1)). That requires the per-dyad full event-time
  // vector for leg2. We append on each event; the vector stays
  // sorted because events arrive in chronological order.
  std::unordered_map<long long, std::vector<double>> dyad_times;
  // Per-actor outgoing / incoming target sets (sorted ascending).
  std::vector<std::vector<int>> out_targets(A);
  std::vector<std::vector<int>> in_sources(A);

  // 3. Allocate output columns.
  const bool need_rec_bin   = (active & F_RECIPROCITY) || (active & F_RECIPROCITY_BINARY);
  const bool need_rec_cnt   = active & F_RECIPROCITY_COUNT;
  const bool need_trans_cnt = active & (F_TRANSITIVITY_BINARY | F_TRANSITIVITY_COUNT);
  const bool need_cyclic_cnt= active & (F_CYCLIC_BINARY | F_CYCLIC_COUNT);
  const bool need_sb_cnt    = active & (F_SENDING_BALANCE_BINARY | F_SENDING_BALANCE_COUNT);
  const bool need_rb_cnt    = active & (F_RECEIVING_BALANCE_BINARY | F_RECEIVING_BALANCE_COUNT);
  const bool need_trans_time= active & (F_TRANSITIVITY_TIME_RECENT | F_TRANSITIVITY_TIME_FIRST);
  const bool need_cyclic_time= active & (F_CYCLIC_TIME_RECENT | F_CYCLIC_TIME_FIRST);
  const bool need_sb_time   = active & (F_SENDING_BALANCE_TIME_RECENT | F_SENDING_BALANCE_TIME_FIRST);
  const bool need_rb_time   = active & (F_RECEIVING_BALANCE_TIME_RECENT | F_RECEIVING_BALANCE_TIME_FIRST);
  const bool need_trans_exp = active & F_TRANSITIVITY_EXP_DECAY;
  const bool need_cyclic_exp= active & F_CYCLIC_EXP_DECAY;
  const bool need_sb_exp    = active & F_SENDING_BALANCE_EXP_DECAY;
  const bool need_rb_exp    = active & F_RECEIVING_BALANCE_EXP_DECAY;
  // Interrupted variants: per-family flags by output kind.
  const bool need_trans_int_cnt  = active & (F_TRANSITIVITY_COUNT_INTERRUPTED | F_TRANSITIVITY_BINARY_INTERRUPTED);
  const bool need_trans_int_exp  = active & F_TRANSITIVITY_EXP_DECAY_INTERRUPTED;
  const bool need_trans_int_time = active & (F_TRANSITIVITY_TIME_RECENT_INTERRUPTED | F_TRANSITIVITY_TIME_FIRST_INTERRUPTED);
  const bool need_cyclic_int_cnt = active & (F_CYCLIC_COUNT_INTERRUPTED | F_CYCLIC_BINARY_INTERRUPTED);
  const bool need_cyclic_int_exp = active & F_CYCLIC_EXP_DECAY_INTERRUPTED;
  const bool need_cyclic_int_time= active & (F_CYCLIC_TIME_RECENT_INTERRUPTED | F_CYCLIC_TIME_FIRST_INTERRUPTED);
  const bool need_sb_int_cnt     = active & (F_SENDING_BALANCE_COUNT_INTERRUPTED | F_SENDING_BALANCE_BINARY_INTERRUPTED);
  const bool need_sb_int_exp     = active & F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED;
  const bool need_sb_int_time    = active & (F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED | F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED);
  const bool need_rb_int_cnt     = active & (F_RECEIVING_BALANCE_COUNT_INTERRUPTED | F_RECEIVING_BALANCE_BINARY_INTERRUPTED);
  const bool need_rb_int_exp     = active & F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED;
  const bool need_rb_int_time    = active & (F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED | F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED);
  const bool need_trans_int_any  = need_trans_int_cnt  || need_trans_int_exp  || need_trans_int_time;
  const bool need_cyclic_int_any = need_cyclic_int_cnt || need_cyclic_int_exp || need_cyclic_int_time;
  const bool need_sb_int_any     = need_sb_int_cnt     || need_sb_int_exp     || need_sb_int_time;
  const bool need_rb_int_any     = need_rb_int_cnt     || need_rb_int_exp     || need_rb_int_time;
  const bool need_outdeg    = active & F_SENDER_OUTDEGREE;
  const bool need_indeg     = active & F_RECEIVER_INDEGREE;
  const bool need_recency   = active & F_RECENCY;
  const bool need_triadic_cnt  = need_trans_cnt || need_cyclic_cnt || need_sb_cnt || need_rb_cnt;
  const bool need_triadic_time = need_trans_time || need_cyclic_time || need_sb_time || need_rb_time;
  const bool need_triadic_exp  = need_trans_exp || need_cyclic_exp || need_sb_exp || need_rb_exp;
  const bool need_triadic_int  = need_trans_int_any || need_cyclic_int_any ||
                                  need_sb_int_any    || need_rb_int_any;
  // Ordered: per-family active flag. The validation sweep runs whenever
  // any of a family's *_count_ordered or *_binary_ordered flags is on.
  const bool need_trans_ord = active & F_TRANSITIVITY_ORDERED_ANY;
  const bool need_cyc_ord   = active & F_CYCLIC_ORDERED_ANY;
  const bool need_sb_ord    = active & F_SENDING_BALANCE_ORDERED_ANY;
  const bool need_rb_ord    = active & F_RECEIVING_BALANCE_ORDERED_ANY;
  // Per-family ordered timing / exp_decay (extra-mask):
  const bool need_trans_time_ord = active_extra & (FE_TRANSITIVITY_TIME_RECENT_ORDERED | FE_TRANSITIVITY_TIME_FIRST_ORDERED);
  const bool need_trans_exp_ord  = active_extra & FE_TRANSITIVITY_EXP_DECAY_ORDERED;
  const bool need_cyc_time_ord   = active_extra & (FE_CYCLIC_TIME_RECENT_ORDERED | FE_CYCLIC_TIME_FIRST_ORDERED);
  const bool need_cyc_exp_ord    = active_extra & FE_CYCLIC_EXP_DECAY_ORDERED;
  const bool need_sb_time_ord    = active_extra & (FE_SENDING_BALANCE_TIME_RECENT_ORDERED | FE_SENDING_BALANCE_TIME_FIRST_ORDERED);
  const bool need_sb_exp_ord     = active_extra & FE_SENDING_BALANCE_EXP_DECAY_ORDERED;
  const bool need_rb_time_ord    = active_extra & (FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED | FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED);
  const bool need_rb_exp_ord     = active_extra & FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED;
  // Per-family "any formation-time-based ordered read needed"
  // -- triggers the per-event vector walk + upper_bound lookup.
  const bool need_trans_form_ord = need_trans_time_ord || need_trans_exp_ord;
  const bool need_cyc_form_ord   = need_cyc_time_ord   || need_cyc_exp_ord;
  const bool need_sb_form_ord    = need_sb_time_ord    || need_sb_exp_ord;
  const bool need_rb_form_ord    = need_rb_time_ord    || need_rb_exp_ord;
  const bool need_any_form_ord   = need_trans_form_ord || need_cyc_form_ord ||
                                    need_sb_form_ord    || need_rb_form_ord;
  const bool need_triadic_ord = need_trans_ord || need_cyc_ord ||
                                 need_sb_ord    || need_rb_ord;
  const bool need_triadic   = need_triadic_cnt || need_triadic_time ||
                              need_triadic_exp || need_triadic_int ||
                              need_triadic_ord || need_any_form_ord;
  // need_X for the joint family walk: timing, exp_decay, AND interrupted
  // readers all use the intersection + first_dyad_time pair.
  const bool need_trans_form  = need_trans_time  || need_trans_exp  || need_trans_int_any;
  const bool need_cyclic_form = need_cyclic_time || need_cyclic_exp || need_cyclic_int_any;
  const bool need_sb_form     = need_sb_time     || need_sb_exp     || need_sb_int_any;
  const bool need_rb_form     = need_rb_time     || need_rb_exp     || need_rb_int_any;

  IntegerVector reciprocity(need_rec_bin ? n : 0);
  IntegerVector reciprocity_binary(need_rec_bin ? n : 0);
  NumericVector reciprocity_count(need_rec_cnt ? n : 0);
  IntegerVector transitivity_binary(active & F_TRANSITIVITY_BINARY ? n : 0);
  NumericVector transitivity_count(active & F_TRANSITIVITY_COUNT ? n : 0);
  IntegerVector cyclic_binary(active & F_CYCLIC_BINARY ? n : 0);
  NumericVector cyclic_count(active & F_CYCLIC_COUNT ? n : 0);
  IntegerVector sending_balance_binary(active & F_SENDING_BALANCE_BINARY ? n : 0);
  NumericVector sending_balance_count(active & F_SENDING_BALANCE_COUNT ? n : 0);
  IntegerVector receiving_balance_binary(active & F_RECEIVING_BALANCE_BINARY ? n : 0);
  NumericVector receiving_balance_count(active & F_RECEIVING_BALANCE_COUNT ? n : 0);
  NumericVector sender_outdegree(need_outdeg ? n : 0);
  NumericVector receiver_indegree(need_indeg ? n : 0);
  NumericVector recency(need_recency ? n : 0);
  if (need_recency) {
    for (R_xlen_t i = 0; i < n; ++i) recency[i] = NA_REAL;
  }
  // Timing columns: NA when no validated intermediary is in scope.
  auto alloc_na = [&](bool needed) {
    NumericVector v(needed ? n : 0);
    if (needed) for (R_xlen_t i = 0; i < n; ++i) v[i] = NA_REAL;
    return v;
  };
  NumericVector transitivity_time_recent      = alloc_na(active & F_TRANSITIVITY_TIME_RECENT);
  NumericVector transitivity_time_first       = alloc_na(active & F_TRANSITIVITY_TIME_FIRST);
  NumericVector cyclic_time_recent            = alloc_na(active & F_CYCLIC_TIME_RECENT);
  NumericVector cyclic_time_first             = alloc_na(active & F_CYCLIC_TIME_FIRST);
  NumericVector sending_balance_time_recent   = alloc_na(active & F_SENDING_BALANCE_TIME_RECENT);
  NumericVector sending_balance_time_first    = alloc_na(active & F_SENDING_BALANCE_TIME_FIRST);
  NumericVector receiving_balance_time_recent = alloc_na(active & F_RECEIVING_BALANCE_TIME_RECENT);
  NumericVector receiving_balance_time_first  = alloc_na(active & F_RECEIVING_BALANCE_TIME_FIRST);
  // exp_decay columns: default 0 when no validated intermediary is in
  // scope, matching compute_triadic's `exp_sum <- 0` initialiser.
  NumericVector transitivity_exp_decay     (need_trans_exp ? n : 0);
  NumericVector cyclic_exp_decay           (need_cyclic_exp ? n : 0);
  NumericVector sending_balance_exp_decay  (need_sb_exp ? n : 0);
  NumericVector receiving_balance_exp_decay(need_rb_exp ? n : 0);
  // Interrupted count / binary / exp_decay columns: default 0; timing
  // variants follow the same NA-when-empty convention as the
  // non-interrupted timing columns.
  NumericVector transitivity_count_interrupted     (active & F_TRANSITIVITY_COUNT_INTERRUPTED ? n : 0);
  IntegerVector transitivity_binary_interrupted    (active & F_TRANSITIVITY_BINARY_INTERRUPTED ? n : 0);
  NumericVector transitivity_exp_decay_interrupted (active & F_TRANSITIVITY_EXP_DECAY_INTERRUPTED ? n : 0);
  NumericVector cyclic_count_interrupted     (active & F_CYCLIC_COUNT_INTERRUPTED ? n : 0);
  IntegerVector cyclic_binary_interrupted    (active & F_CYCLIC_BINARY_INTERRUPTED ? n : 0);
  NumericVector cyclic_exp_decay_interrupted (active & F_CYCLIC_EXP_DECAY_INTERRUPTED ? n : 0);
  NumericVector sending_balance_count_interrupted     (active & F_SENDING_BALANCE_COUNT_INTERRUPTED ? n : 0);
  IntegerVector sending_balance_binary_interrupted    (active & F_SENDING_BALANCE_BINARY_INTERRUPTED ? n : 0);
  NumericVector sending_balance_exp_decay_interrupted (active & F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED ? n : 0);
  NumericVector receiving_balance_count_interrupted     (active & F_RECEIVING_BALANCE_COUNT_INTERRUPTED ? n : 0);
  IntegerVector receiving_balance_binary_interrupted    (active & F_RECEIVING_BALANCE_BINARY_INTERRUPTED ? n : 0);
  NumericVector receiving_balance_exp_decay_interrupted (active & F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED ? n : 0);
  NumericVector transitivity_time_recent_interrupted = alloc_na(active & F_TRANSITIVITY_TIME_RECENT_INTERRUPTED);
  NumericVector transitivity_time_first_interrupted  = alloc_na(active & F_TRANSITIVITY_TIME_FIRST_INTERRUPTED);
  NumericVector cyclic_time_recent_interrupted       = alloc_na(active & F_CYCLIC_TIME_RECENT_INTERRUPTED);
  NumericVector cyclic_time_first_interrupted        = alloc_na(active & F_CYCLIC_TIME_FIRST_INTERRUPTED);
  NumericVector sending_balance_time_recent_interrupted   = alloc_na(active & F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED);
  NumericVector sending_balance_time_first_interrupted    = alloc_na(active & F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED);
  NumericVector receiving_balance_time_recent_interrupted = alloc_na(active & F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED);
  NumericVector receiving_balance_time_first_interrupted  = alloc_na(active & F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED);
  // Ordered count / binary: default 0 (state is initialised empty).
  NumericVector transitivity_count_ordered      (active & F_TRANSITIVITY_COUNT_ORDERED ? n : 0);
  IntegerVector transitivity_binary_ordered     (active & F_TRANSITIVITY_BINARY_ORDERED ? n : 0);
  NumericVector cyclic_count_ordered            (active & F_CYCLIC_COUNT_ORDERED ? n : 0);
  IntegerVector cyclic_binary_ordered           (active & F_CYCLIC_BINARY_ORDERED ? n : 0);
  NumericVector sending_balance_count_ordered   (active & F_SENDING_BALANCE_COUNT_ORDERED ? n : 0);
  IntegerVector sending_balance_binary_ordered  (active & F_SENDING_BALANCE_BINARY_ORDERED ? n : 0);
  NumericVector receiving_balance_count_ordered (active & F_RECEIVING_BALANCE_COUNT_ORDERED ? n : 0);
  IntegerVector receiving_balance_binary_ordered(active & F_RECEIVING_BALANCE_BINARY_ORDERED ? n : 0);
  // Ordered timing: NA when no validated intermediary exists.
  NumericVector transitivity_time_recent_ordered      = alloc_na(active_extra & FE_TRANSITIVITY_TIME_RECENT_ORDERED);
  NumericVector transitivity_time_first_ordered       = alloc_na(active_extra & FE_TRANSITIVITY_TIME_FIRST_ORDERED);
  NumericVector cyclic_time_recent_ordered            = alloc_na(active_extra & FE_CYCLIC_TIME_RECENT_ORDERED);
  NumericVector cyclic_time_first_ordered             = alloc_na(active_extra & FE_CYCLIC_TIME_FIRST_ORDERED);
  NumericVector sending_balance_time_recent_ordered   = alloc_na(active_extra & FE_SENDING_BALANCE_TIME_RECENT_ORDERED);
  NumericVector sending_balance_time_first_ordered    = alloc_na(active_extra & FE_SENDING_BALANCE_TIME_FIRST_ORDERED);
  NumericVector receiving_balance_time_recent_ordered = alloc_na(active_extra & FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED);
  NumericVector receiving_balance_time_first_ordered  = alloc_na(active_extra & FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED);
  // Ordered exp_decay: default 0.
  NumericVector transitivity_exp_decay_ordered      (active_extra & FE_TRANSITIVITY_EXP_DECAY_ORDERED ? n : 0);
  NumericVector cyclic_exp_decay_ordered            (active_extra & FE_CYCLIC_EXP_DECAY_ORDERED ? n : 0);
  NumericVector sending_balance_exp_decay_ordered   (active_extra & FE_SENDING_BALANCE_EXP_DECAY_ORDERED ? n : 0);
  NumericVector receiving_balance_exp_decay_ordered (active_extra & FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED ? n : 0);

  // 4. Main loop. The per-row READ phase (compute every statistic) and
  // WRITE phase (update the history state) are factored into lambdas so they
  // can be driven two ways: history-free in row order (preserving the
  // documented "ties resolve in row order" semantics and the prior
  // behaviour), or history-aware in time groups (so non-events read the
  // pre-t state and never write).
  auto do_read = [&](R_xlen_t i) {
    const int s = s_idx[i], r = r_idx[i];
    const double ti = times[i];
    const long long key_sr = (long long)s * A + r;
    const long long key_rs = (long long)r * A + s;

    if (need_outdeg)  sender_outdegree[i]   = (double)sender_count[s];
    if (need_indeg)   receiver_indegree[i]  = (double)receiver_count[r];
    if (need_recency) {
      auto it = dyad_last_time.find(key_sr);
      if (it != dyad_last_time.end()) recency[i] = ti - it->second;
    }
    // Ordered count/binary: per-focal-event walk of the family's
    // intersection k-set, counting k where the last leg2 time
    // strictly exceeds the first leg1 time. Mirrors compute_triadic
    // in R/preprocess.R (the post-hoc reference), and is robust to
    // tied timestamps.
    auto count_ordered_k = [&](const std::vector<int>& a,
                                const std::vector<int>& b,
                                auto leg1_key_fn, auto leg2_key_fn) -> int {
      int ii = 0, jj = 0, cnt = 0;
      while (ii < (int)a.size() && jj < (int)b.size()) {
        if (a[ii] < b[jj]) { ++ii; }
        else if (a[ii] > b[jj]) { ++jj; }
        else {
          int k = a[ii];
          if (k != s && k != r) {
            auto it1 = dyad_first_time.find(leg1_key_fn(k));
            auto it2 = dyad_last_time.find(leg2_key_fn(k));
            if (it1 != dyad_first_time.end() &&
                it2 != dyad_last_time.end() &&
                it2->second > it1->second) {
              ++cnt;
            }
          }
          ++ii; ++jj;
        }
      }
      return cnt;
    };
    if (need_trans_ord) {
      const std::vector<int>& s_out = out_targets[s];
      const std::vector<int>& r_in  = in_sources[r];
      int v = count_ordered_k(s_out, r_in,
        [s, A](int k){ return (long long)s * A + k; },   // leg1 = s->k
        [r, A](int k){ return (long long)k * A + r; });  // leg2 = k->r
      if (active & F_TRANSITIVITY_COUNT_ORDERED)  transitivity_count_ordered[i]  = (double)v;
      if (active & F_TRANSITIVITY_BINARY_ORDERED) transitivity_binary_ordered[i] = v > 0;
    }
    if (need_cyc_ord) {
      const std::vector<int>& r_out = out_targets[r];
      const std::vector<int>& s_in  = in_sources[s];
      int v = count_ordered_k(r_out, s_in,
        [r, A](int k){ return (long long)r * A + k; },   // leg1 = r->k
        [s, A](int k){ return (long long)k * A + s; });  // leg2 = k->s
      if (active & F_CYCLIC_COUNT_ORDERED)  cyclic_count_ordered[i]  = (double)v;
      if (active & F_CYCLIC_BINARY_ORDERED) cyclic_binary_ordered[i] = v > 0;
    }
    if (need_sb_ord) {
      const std::vector<int>& s_out = out_targets[s];
      const std::vector<int>& r_out = out_targets[r];
      int v = count_ordered_k(s_out, r_out,
        [s, A](int k){ return (long long)s * A + k; },   // leg1 = s->k
        [r, A](int k){ return (long long)r * A + k; });  // leg2 = r->k
      if (active & F_SENDING_BALANCE_COUNT_ORDERED)  sending_balance_count_ordered[i]  = (double)v;
      if (active & F_SENDING_BALANCE_BINARY_ORDERED) sending_balance_binary_ordered[i] = v > 0;
    }
    if (need_rb_ord) {
      const std::vector<int>& s_in = in_sources[s];
      const std::vector<int>& r_in = in_sources[r];
      int v = count_ordered_k(s_in, r_in,
        [s, A](int k){ return (long long)k * A + s; },   // leg1 = k->s
        [r, A](int k){ return (long long)k * A + r; });  // leg2 = k->r
      if (active & F_RECEIVING_BALANCE_COUNT_ORDERED)  receiving_balance_count_ordered[i]  = (double)v;
      if (active & F_RECEIVING_BALANCE_BINARY_ORDERED) receiving_balance_binary_ordered[i] = v > 0;
    }
    // Ordered timing / exp_decay: per-intermediary
    //   formation_ord(k) = first leg2 event time > min(leg1)
    // computed via upper_bound on the per-dyad sorted event-time
    // vector (dyad_times). Walker reduces to compute_triadic's
    // ordered branch in R/preprocess.R but per-event (no state).
    auto walk_ord_formation = [&](const std::vector<int>& a,
                                   const std::vector<int>& b,
                                   auto leg1_key_fn, auto leg2_key_fn,
                                   bool need_exp_local,
                                   int& nk, double& fmin, double& fmax,
                                   double& esum) {
      nk = 0;
      fmin = std::numeric_limits<double>::infinity();
      fmax = -std::numeric_limits<double>::infinity();
      esum = 0.0;
      int ii = 0, jj = 0;
      while (ii < (int)a.size() && jj < (int)b.size()) {
        if (a[ii] < b[jj]) { ++ii; }
        else if (a[ii] > b[jj]) { ++jj; }
        else {
          int k = a[ii];
          if (k != s && k != r) {
            auto it1 = dyad_first_time.find(leg1_key_fn(k));
            auto it2 = dyad_times.find(leg2_key_fn(k));
            if (it1 != dyad_first_time.end() &&
                it2 != dyad_times.end()) {
              double thr = it1->second;
              const auto& vec = it2->second;
              auto pos = std::upper_bound(vec.begin(), vec.end(), thr);
              if (pos != vec.end()) {
                double form = *pos;
                if (form > fmax) fmax = form;
                if (form < fmin) fmin = form;
                if (need_exp_local) {
                  esum += std::exp(-(ti - form) * decay_rate);
                }
                ++nk;
              }
            }
          }
          ++ii; ++jj;
        }
      }
    };
    if (need_trans_form_ord) {
      int nk; double fmin, fmax, esum;
      const std::vector<int>& s_out = out_targets[s];
      const std::vector<int>& r_in  = in_sources[r];
      walk_ord_formation(s_out, r_in,
        [s, A](int k){ return (long long)s * A + k; },
        [r, A](int k){ return (long long)k * A + r; },
        need_trans_exp_ord, nk, fmin, fmax, esum);
      if (nk > 0) {
        if (active_extra & FE_TRANSITIVITY_TIME_RECENT_ORDERED) transitivity_time_recent_ordered[i] = ti - fmax;
        if (active_extra & FE_TRANSITIVITY_TIME_FIRST_ORDERED)  transitivity_time_first_ordered[i]  = ti - fmin;
      }
      if (need_trans_exp_ord) transitivity_exp_decay_ordered[i] = esum;
    }
    if (need_cyc_form_ord) {
      int nk; double fmin, fmax, esum;
      const std::vector<int>& r_out = out_targets[r];
      const std::vector<int>& s_in  = in_sources[s];
      walk_ord_formation(r_out, s_in,
        [r, A](int k){ return (long long)r * A + k; },
        [s, A](int k){ return (long long)k * A + s; },
        need_cyc_exp_ord, nk, fmin, fmax, esum);
      if (nk > 0) {
        if (active_extra & FE_CYCLIC_TIME_RECENT_ORDERED) cyclic_time_recent_ordered[i] = ti - fmax;
        if (active_extra & FE_CYCLIC_TIME_FIRST_ORDERED)  cyclic_time_first_ordered[i]  = ti - fmin;
      }
      if (need_cyc_exp_ord) cyclic_exp_decay_ordered[i] = esum;
    }
    if (need_sb_form_ord) {
      int nk; double fmin, fmax, esum;
      const std::vector<int>& s_out = out_targets[s];
      const std::vector<int>& r_out = out_targets[r];
      walk_ord_formation(s_out, r_out,
        [s, A](int k){ return (long long)s * A + k; },
        [r, A](int k){ return (long long)r * A + k; },
        need_sb_exp_ord, nk, fmin, fmax, esum);
      if (nk > 0) {
        if (active_extra & FE_SENDING_BALANCE_TIME_RECENT_ORDERED) sending_balance_time_recent_ordered[i] = ti - fmax;
        if (active_extra & FE_SENDING_BALANCE_TIME_FIRST_ORDERED)  sending_balance_time_first_ordered[i]  = ti - fmin;
      }
      if (need_sb_exp_ord) sending_balance_exp_decay_ordered[i] = esum;
    }
    if (need_rb_form_ord) {
      int nk; double fmin, fmax, esum;
      const std::vector<int>& s_in = in_sources[s];
      const std::vector<int>& r_in = in_sources[r];
      walk_ord_formation(s_in, r_in,
        [s, A](int k){ return (long long)k * A + s; },
        [r, A](int k){ return (long long)k * A + r; },
        need_rb_exp_ord, nk, fmin, fmax, esum);
      if (nk > 0) {
        if (active_extra & FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED) receiving_balance_time_recent_ordered[i] = ti - fmax;
        if (active_extra & FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED)  receiving_balance_time_first_ordered[i]  = ti - fmin;
      }
      if (need_rb_exp_ord) receiving_balance_exp_decay_ordered[i] = esum;
    }

    // Reciprocity (count of past events on the REVERSE dyad).
    long rc = 0;
    {
      auto it = dyad_event_count.find(key_rs);
      if (it != dyad_event_count.end()) rc = it->second;
    }
    if (need_rec_bin) {
      int v = rc > 0 ? 1 : 0;
      reciprocity[i] = v;
      reciprocity_binary[i] = v;
    }
    if (need_rec_cnt) reciprocity_count[i] = (double)rc;

    if (need_triadic) {
      const std::vector<int>& s_out = out_targets[s];
      const std::vector<int>& r_out = out_targets[r];
      const std::vector<int>& s_in  = in_sources[s];
      const std::vector<int>& r_in  = in_sources[r];

      // transitivity:      k such that s -> k AND k -> r
      //   leg1 = (s, k);   leg2 = (k, r)
      // cyclic:            k such that r -> k AND k -> s
      //   leg1 = (r, k);   leg2 = (k, s)
      // sending_balance:   k such that s -> k AND r -> k
      //   leg1 = (s, k);   leg2 = (r, k)
      // receiving_balance: k such that k -> s AND k -> r
      //   leg1 = (k, s);   leg2 = (k, r)
      if (need_trans_cnt) {
        int c = sorted_intersect_count(s_out, r_in, s, r);
        if (active & F_TRANSITIVITY_COUNT)  transitivity_count[i]  = (double)c;
        if (active & F_TRANSITIVITY_BINARY) transitivity_binary[i] = c > 0;
      }
      if (need_cyclic_cnt) {
        int c = sorted_intersect_count(r_out, s_in, s, r);
        if (active & F_CYCLIC_COUNT)  cyclic_count[i]  = (double)c;
        if (active & F_CYCLIC_BINARY) cyclic_binary[i] = c > 0;
      }
      if (need_sb_cnt) {
        int c = sorted_intersect_count(s_out, r_out, s, r);
        if (active & F_SENDING_BALANCE_COUNT)  sending_balance_count[i]  = (double)c;
        if (active & F_SENDING_BALANCE_BINARY) sending_balance_binary[i] = c > 0;
      }
      if (need_rb_cnt) {
        int c = sorted_intersect_count(s_in, r_in, s, r);
        if (active & F_RECEIVING_BALANCE_COUNT)  receiving_balance_count[i]  = (double)c;
        if (active & F_RECEIVING_BALANCE_BINARY) receiving_balance_binary[i] = c > 0;
      }
      // For each family with any formation-based stat active, walk the
      // intersection once and emit timing / exp_decay / interrupted
      // outputs from the same accumulator.
      double t_closure;
      {
        auto it = dyad_last_time.find(key_sr);
        t_closure = (it == dyad_last_time.end())
                      ? -std::numeric_limits<double>::infinity()
                      : it->second;
      }
      if (need_trans_form) {
        FamilyAccumulator acc;
        walk_intersect_formation(s_out, r_in, s, r, dyad_first_time,
          [s, A](int k) { return (long long)s * A + k; },
          [r, A](int k) { return (long long)k * A + r; },
          ti, decay_rate, t_closure,
          need_trans_exp, need_trans_int_exp, need_trans_int_any,
          acc);
        if (acc.n > 0) {
          if (active & F_TRANSITIVITY_TIME_RECENT) transitivity_time_recent[i] = ti - acc.f_max;
          if (active & F_TRANSITIVITY_TIME_FIRST)  transitivity_time_first[i]  = ti - acc.f_min;
        }
        if (need_trans_exp) transitivity_exp_decay[i] = acc.e_sum;
        if (active & F_TRANSITIVITY_COUNT_INTERRUPTED)   transitivity_count_interrupted[i]    = (double)acc.n_int;
        if (active & F_TRANSITIVITY_BINARY_INTERRUPTED)  transitivity_binary_interrupted[i]   = acc.n_int > 0;
        if (need_trans_int_exp)                          transitivity_exp_decay_interrupted[i] = acc.e_int_sum;
        if (acc.n_int > 0) {
          if (active & F_TRANSITIVITY_TIME_RECENT_INTERRUPTED) transitivity_time_recent_interrupted[i] = ti - acc.f_int_max;
          if (active & F_TRANSITIVITY_TIME_FIRST_INTERRUPTED)  transitivity_time_first_interrupted[i]  = ti - acc.f_int_min;
        }
      }
      if (need_cyclic_form) {
        FamilyAccumulator acc;
        walk_intersect_formation(r_out, s_in, s, r, dyad_first_time,
          [r, A](int k) { return (long long)r * A + k; },
          [s, A](int k) { return (long long)k * A + s; },
          ti, decay_rate, t_closure,
          need_cyclic_exp, need_cyclic_int_exp, need_cyclic_int_any,
          acc);
        if (acc.n > 0) {
          if (active & F_CYCLIC_TIME_RECENT) cyclic_time_recent[i] = ti - acc.f_max;
          if (active & F_CYCLIC_TIME_FIRST)  cyclic_time_first[i]  = ti - acc.f_min;
        }
        if (need_cyclic_exp) cyclic_exp_decay[i] = acc.e_sum;
        if (active & F_CYCLIC_COUNT_INTERRUPTED)   cyclic_count_interrupted[i]    = (double)acc.n_int;
        if (active & F_CYCLIC_BINARY_INTERRUPTED)  cyclic_binary_interrupted[i]   = acc.n_int > 0;
        if (need_cyclic_int_exp)                   cyclic_exp_decay_interrupted[i] = acc.e_int_sum;
        if (acc.n_int > 0) {
          if (active & F_CYCLIC_TIME_RECENT_INTERRUPTED) cyclic_time_recent_interrupted[i] = ti - acc.f_int_max;
          if (active & F_CYCLIC_TIME_FIRST_INTERRUPTED)  cyclic_time_first_interrupted[i]  = ti - acc.f_int_min;
        }
      }
      if (need_sb_form) {
        FamilyAccumulator acc;
        walk_intersect_formation(s_out, r_out, s, r, dyad_first_time,
          [s, A](int k) { return (long long)s * A + k; },
          [r, A](int k) { return (long long)r * A + k; },
          ti, decay_rate, t_closure,
          need_sb_exp, need_sb_int_exp, need_sb_int_any,
          acc);
        if (acc.n > 0) {
          if (active & F_SENDING_BALANCE_TIME_RECENT) sending_balance_time_recent[i] = ti - acc.f_max;
          if (active & F_SENDING_BALANCE_TIME_FIRST)  sending_balance_time_first[i]  = ti - acc.f_min;
        }
        if (need_sb_exp) sending_balance_exp_decay[i] = acc.e_sum;
        if (active & F_SENDING_BALANCE_COUNT_INTERRUPTED)   sending_balance_count_interrupted[i]    = (double)acc.n_int;
        if (active & F_SENDING_BALANCE_BINARY_INTERRUPTED)  sending_balance_binary_interrupted[i]   = acc.n_int > 0;
        if (need_sb_int_exp)                                sending_balance_exp_decay_interrupted[i] = acc.e_int_sum;
        if (acc.n_int > 0) {
          if (active & F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED) sending_balance_time_recent_interrupted[i] = ti - acc.f_int_max;
          if (active & F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED)  sending_balance_time_first_interrupted[i]  = ti - acc.f_int_min;
        }
      }
      if (need_rb_form) {
        FamilyAccumulator acc;
        walk_intersect_formation(s_in, r_in, s, r, dyad_first_time,
          [s, A](int k) { return (long long)k * A + s; },
          [r, A](int k) { return (long long)k * A + r; },
          ti, decay_rate, t_closure,
          need_rb_exp, need_rb_int_exp, need_rb_int_any,
          acc);
        if (acc.n > 0) {
          if (active & F_RECEIVING_BALANCE_TIME_RECENT) receiving_balance_time_recent[i] = ti - acc.f_max;
          if (active & F_RECEIVING_BALANCE_TIME_FIRST)  receiving_balance_time_first[i]  = ti - acc.f_min;
        }
        if (need_rb_exp) receiving_balance_exp_decay[i] = acc.e_sum;
        if (active & F_RECEIVING_BALANCE_COUNT_INTERRUPTED)   receiving_balance_count_interrupted[i]    = (double)acc.n_int;
        if (active & F_RECEIVING_BALANCE_BINARY_INTERRUPTED)  receiving_balance_binary_interrupted[i]   = acc.n_int > 0;
        if (need_rb_int_exp)                                  receiving_balance_exp_decay_interrupted[i] = acc.e_int_sum;
        if (acc.n_int > 0) {
          if (active & F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED) receiving_balance_time_recent_interrupted[i] = ti - acc.f_int_max;
          if (active & F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED)  receiving_balance_time_first_interrupted[i]  = ti - acc.f_int_min;
        }
      }
    }

  };  // end do_read

  auto do_write = [&](R_xlen_t i) {
    const int s = s_idx[i], r = r_idx[i];
    const double ti = times[i];
    const long long key_sr = (long long)s * A + r;

    // --- state update (after stats are read) ---
    sender_count[s] += 1;
    receiver_count[r] += 1;
    dyad_event_count[key_sr] += 1;
    dyad_last_time[key_sr] = ti;
    {
      auto it = dyad_first_time.find(key_sr);
      if (it == dyad_first_time.end()) dyad_first_time.emplace(key_sr, ti);
    }
    // Per-dyad event-time vector (only when any ordered-form stat needs
    // it). Events arrive in chronological order, so the vector stays
    // sorted by simple push_back.
    if (need_any_form_ord) {
      dyad_times[key_sr].push_back(ti);
    }
    if (need_triadic) {
      sorted_insert_unique(out_targets[s], r);
      sorted_insert_unique(in_sources[r], s);
    }
  };  // end do_write

  if (!mask_active) {
    // History-free behaviour: process rows in row order, reading then
    // immediately writing, so tied timestamps resolve in row order. This
    // is identical to the original single-pass loop.
    for (R_xlen_t i = 0; i < n; ++i) { do_read(i); do_write(i); }
  } else {
    // History-aware behaviour: process in time groups. Every row at time t
    // runs its READ phase before any WRITE, so all rows sharing t see the
    // state as it stood strictly before t; only actual events
    // (is_event[i]) update the history, so sampled non-events never
    // pollute it.
    for (R_xlen_t g = 0; g < n; ) {
      R_xlen_t g_end = g;
      while (g_end < n && times[g_end] == times[g]) ++g_end;
      for (R_xlen_t i = g; i < g_end; ++i) do_read(i);
      for (R_xlen_t i = g; i < g_end; ++i) if (is_event[i] == TRUE) do_write(i);
      g = g_end;
    }
  }

  // 5. Assemble the named output list.
  List out;
  if (need_rec_bin) {
    if (active & F_RECIPROCITY)        out["reciprocity"]        = reciprocity;
    if (active & F_RECIPROCITY_BINARY) out["reciprocity_binary"] = reciprocity_binary;
  }
  if (need_rec_cnt) out["reciprocity_count"] = reciprocity_count;
  if (active & F_TRANSITIVITY_BINARY) out["transitivity_binary"] = transitivity_binary;
  if (active & F_TRANSITIVITY_COUNT)  out["transitivity_count"]  = transitivity_count;
  if (active & F_CYCLIC_BINARY)       out["cyclic_binary"]       = cyclic_binary;
  if (active & F_CYCLIC_COUNT)        out["cyclic_count"]        = cyclic_count;
  if (active & F_SENDING_BALANCE_BINARY) out["sending_balance_binary"] = sending_balance_binary;
  if (active & F_SENDING_BALANCE_COUNT)  out["sending_balance_count"]  = sending_balance_count;
  if (active & F_RECEIVING_BALANCE_BINARY) out["receiving_balance_binary"] = receiving_balance_binary;
  if (active & F_RECEIVING_BALANCE_COUNT)  out["receiving_balance_count"]  = receiving_balance_count;
  if (active & F_SENDER_OUTDEGREE)  out["sender_outdegree"]  = sender_outdegree;
  if (active & F_RECEIVER_INDEGREE) out["receiver_indegree"] = receiver_indegree;
  if (active & F_RECENCY)           out["recency"]           = recency;
  if (active & F_TRANSITIVITY_TIME_RECENT) out["transitivity_time_recent"] = transitivity_time_recent;
  if (active & F_TRANSITIVITY_TIME_FIRST)  out["transitivity_time_first"]  = transitivity_time_first;
  if (active & F_CYCLIC_TIME_RECENT)       out["cyclic_time_recent"]       = cyclic_time_recent;
  if (active & F_CYCLIC_TIME_FIRST)        out["cyclic_time_first"]        = cyclic_time_first;
  if (active & F_SENDING_BALANCE_TIME_RECENT) out["sending_balance_time_recent"] = sending_balance_time_recent;
  if (active & F_SENDING_BALANCE_TIME_FIRST)  out["sending_balance_time_first"]  = sending_balance_time_first;
  if (active & F_RECEIVING_BALANCE_TIME_RECENT) out["receiving_balance_time_recent"] = receiving_balance_time_recent;
  if (active & F_RECEIVING_BALANCE_TIME_FIRST)  out["receiving_balance_time_first"]  = receiving_balance_time_first;
  if (active & F_TRANSITIVITY_EXP_DECAY)        out["transitivity_exp_decay"]        = transitivity_exp_decay;
  if (active & F_CYCLIC_EXP_DECAY)              out["cyclic_exp_decay"]              = cyclic_exp_decay;
  if (active & F_SENDING_BALANCE_EXP_DECAY)     out["sending_balance_exp_decay"]     = sending_balance_exp_decay;
  if (active & F_RECEIVING_BALANCE_EXP_DECAY)   out["receiving_balance_exp_decay"]   = receiving_balance_exp_decay;
  if (active & F_TRANSITIVITY_COUNT_INTERRUPTED)       out["transitivity_count_interrupted"]       = transitivity_count_interrupted;
  if (active & F_TRANSITIVITY_BINARY_INTERRUPTED)      out["transitivity_binary_interrupted"]      = transitivity_binary_interrupted;
  if (active & F_TRANSITIVITY_EXP_DECAY_INTERRUPTED)   out["transitivity_exp_decay_interrupted"]   = transitivity_exp_decay_interrupted;
  if (active & F_TRANSITIVITY_TIME_RECENT_INTERRUPTED) out["transitivity_time_recent_interrupted"] = transitivity_time_recent_interrupted;
  if (active & F_TRANSITIVITY_TIME_FIRST_INTERRUPTED)  out["transitivity_time_first_interrupted"]  = transitivity_time_first_interrupted;
  if (active & F_CYCLIC_COUNT_INTERRUPTED)             out["cyclic_count_interrupted"]             = cyclic_count_interrupted;
  if (active & F_CYCLIC_BINARY_INTERRUPTED)            out["cyclic_binary_interrupted"]            = cyclic_binary_interrupted;
  if (active & F_CYCLIC_EXP_DECAY_INTERRUPTED)         out["cyclic_exp_decay_interrupted"]         = cyclic_exp_decay_interrupted;
  if (active & F_CYCLIC_TIME_RECENT_INTERRUPTED)       out["cyclic_time_recent_interrupted"]       = cyclic_time_recent_interrupted;
  if (active & F_CYCLIC_TIME_FIRST_INTERRUPTED)        out["cyclic_time_first_interrupted"]        = cyclic_time_first_interrupted;
  if (active & F_SENDING_BALANCE_COUNT_INTERRUPTED)       out["sending_balance_count_interrupted"]       = sending_balance_count_interrupted;
  if (active & F_SENDING_BALANCE_BINARY_INTERRUPTED)      out["sending_balance_binary_interrupted"]      = sending_balance_binary_interrupted;
  if (active & F_SENDING_BALANCE_EXP_DECAY_INTERRUPTED)   out["sending_balance_exp_decay_interrupted"]   = sending_balance_exp_decay_interrupted;
  if (active & F_SENDING_BALANCE_TIME_RECENT_INTERRUPTED) out["sending_balance_time_recent_interrupted"] = sending_balance_time_recent_interrupted;
  if (active & F_SENDING_BALANCE_TIME_FIRST_INTERRUPTED)  out["sending_balance_time_first_interrupted"]  = sending_balance_time_first_interrupted;
  if (active & F_RECEIVING_BALANCE_COUNT_INTERRUPTED)       out["receiving_balance_count_interrupted"]       = receiving_balance_count_interrupted;
  if (active & F_RECEIVING_BALANCE_BINARY_INTERRUPTED)      out["receiving_balance_binary_interrupted"]      = receiving_balance_binary_interrupted;
  if (active & F_RECEIVING_BALANCE_EXP_DECAY_INTERRUPTED)   out["receiving_balance_exp_decay_interrupted"]   = receiving_balance_exp_decay_interrupted;
  if (active & F_RECEIVING_BALANCE_TIME_RECENT_INTERRUPTED) out["receiving_balance_time_recent_interrupted"] = receiving_balance_time_recent_interrupted;
  if (active & F_RECEIVING_BALANCE_TIME_FIRST_INTERRUPTED)  out["receiving_balance_time_first_interrupted"]  = receiving_balance_time_first_interrupted;
  if (active & F_TRANSITIVITY_COUNT_ORDERED)      out["transitivity_count_ordered"]      = transitivity_count_ordered;
  if (active & F_TRANSITIVITY_BINARY_ORDERED)     out["transitivity_binary_ordered"]     = transitivity_binary_ordered;
  if (active & F_CYCLIC_COUNT_ORDERED)            out["cyclic_count_ordered"]            = cyclic_count_ordered;
  if (active & F_CYCLIC_BINARY_ORDERED)           out["cyclic_binary_ordered"]           = cyclic_binary_ordered;
  if (active & F_SENDING_BALANCE_COUNT_ORDERED)   out["sending_balance_count_ordered"]   = sending_balance_count_ordered;
  if (active & F_SENDING_BALANCE_BINARY_ORDERED)  out["sending_balance_binary_ordered"]  = sending_balance_binary_ordered;
  if (active & F_RECEIVING_BALANCE_COUNT_ORDERED) out["receiving_balance_count_ordered"] = receiving_balance_count_ordered;
  if (active & F_RECEIVING_BALANCE_BINARY_ORDERED) out["receiving_balance_binary_ordered"] = receiving_balance_binary_ordered;
  if (active_extra & FE_TRANSITIVITY_TIME_RECENT_ORDERED)      out["transitivity_time_recent_ordered"]      = transitivity_time_recent_ordered;
  if (active_extra & FE_TRANSITIVITY_TIME_FIRST_ORDERED)       out["transitivity_time_first_ordered"]       = transitivity_time_first_ordered;
  if (active_extra & FE_TRANSITIVITY_EXP_DECAY_ORDERED)        out["transitivity_exp_decay_ordered"]        = transitivity_exp_decay_ordered;
  if (active_extra & FE_CYCLIC_TIME_RECENT_ORDERED)            out["cyclic_time_recent_ordered"]            = cyclic_time_recent_ordered;
  if (active_extra & FE_CYCLIC_TIME_FIRST_ORDERED)             out["cyclic_time_first_ordered"]             = cyclic_time_first_ordered;
  if (active_extra & FE_CYCLIC_EXP_DECAY_ORDERED)              out["cyclic_exp_decay_ordered"]              = cyclic_exp_decay_ordered;
  if (active_extra & FE_SENDING_BALANCE_TIME_RECENT_ORDERED)   out["sending_balance_time_recent_ordered"]   = sending_balance_time_recent_ordered;
  if (active_extra & FE_SENDING_BALANCE_TIME_FIRST_ORDERED)    out["sending_balance_time_first_ordered"]    = sending_balance_time_first_ordered;
  if (active_extra & FE_SENDING_BALANCE_EXP_DECAY_ORDERED)     out["sending_balance_exp_decay_ordered"]     = sending_balance_exp_decay_ordered;
  if (active_extra & FE_RECEIVING_BALANCE_TIME_RECENT_ORDERED) out["receiving_balance_time_recent_ordered"] = receiving_balance_time_recent_ordered;
  if (active_extra & FE_RECEIVING_BALANCE_TIME_FIRST_ORDERED)  out["receiving_balance_time_first_ordered"]  = receiving_balance_time_first_ordered;
  if (active_extra & FE_RECEIVING_BALANCE_EXP_DECAY_ORDERED)   out["receiving_balance_exp_decay_ordered"]   = receiving_balance_exp_decay_ordered;
  return out;
}

// [[Rcpp::export(rng = false)]]
CharacterVector cpp_supported_stats() {
  CharacterVector v(SUPPORTED_STATS.size());
  for (size_t i = 0; i < SUPPORTED_STATS.size(); ++i) v[i] = SUPPORTED_STATS[i];
  return v;
}
