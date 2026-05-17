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
#include <limits>

using namespace Rcpp;

// Bit flags identifying which stats the caller wants. Avoids
// per-event string comparisons in the inner loop.
enum StatFlag : unsigned int {
  F_RECIPROCITY        = 1u << 0,
  F_RECIPROCITY_BINARY = 1u << 1,
  F_RECIPROCITY_COUNT  = 1u << 2,
  F_TRANSITIVITY_BINARY = 1u << 3,
  F_TRANSITIVITY_COUNT  = 1u << 4,
  F_CYCLIC_BINARY       = 1u << 5,
  F_CYCLIC_COUNT        = 1u << 6,
  F_SENDING_BALANCE_BINARY = 1u << 7,
  F_SENDING_BALANCE_COUNT  = 1u << 8,
  F_RECEIVING_BALANCE_BINARY = 1u << 9,
  F_RECEIVING_BALANCE_COUNT  = 1u << 10,
  F_SENDER_OUTDEGREE  = 1u << 11,
  F_RECEIVER_INDEGREE = 1u << 12,
  F_RECENCY           = 1u << 13,
  F_TRANSITIVITY_TIME_RECENT      = 1u << 14,
  F_TRANSITIVITY_TIME_FIRST       = 1u << 15,
  F_CYCLIC_TIME_RECENT            = 1u << 16,
  F_CYCLIC_TIME_FIRST             = 1u << 17,
  F_SENDING_BALANCE_TIME_RECENT   = 1u << 18,
  F_SENDING_BALANCE_TIME_FIRST    = 1u << 19,
  F_RECEIVING_BALANCE_TIME_RECENT = 1u << 20,
  F_RECEIVING_BALANCE_TIME_FIRST  = 1u << 21,
  F_TRANSITIVITY_EXP_DECAY        = 1u << 22,
  F_CYCLIC_EXP_DECAY              = 1u << 23,
  F_SENDING_BALANCE_EXP_DECAY     = 1u << 24,
  F_RECEIVING_BALANCE_EXP_DECAY   = 1u << 25
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
  "sending_balance_exp_decay", "receiving_balance_exp_decay"
};

static unsigned int flag_for(const std::string& s) {
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
  return 0u;
}

static constexpr unsigned int F_ANY_EXP_DECAY =
  F_TRANSITIVITY_EXP_DECAY | F_CYCLIC_EXP_DECAY |
  F_SENDING_BALANCE_EXP_DECAY | F_RECEIVING_BALANCE_EXP_DECAY;

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

// Walk the intersection of two sorted ascending integer vectors,
// returning min/max of `formation_k = max(first[leg1_key(k)], first[leg2_key(k)])`
// over k in (a ∩ b) \ {excl_s, excl_r}. `n_found` counts validated k's.
// `leg1_key` / `leg2_key` build the dyad-key for the per-k formation lookup;
// they are family-specific (see callers below).
//
// When `need_exp` is true, also accumulates `exp_sum = sum over k of
// exp(-(t_now - formation_k) * decay_rate)` -- the per-event
// exp_decay statistic. Per the post-hoc reference in
// R/preprocess.R::compute_triadic.
template <typename L1, typename L2>
static void walk_intersect_formation(const std::vector<int>& a,
                                     const std::vector<int>& b,
                                     int excl_s, int excl_r,
                                     const std::unordered_map<long long, double>& first_map,
                                     L1 leg1_key, L2 leg2_key,
                                     int& n_found,
                                     double& form_min, double& form_max,
                                     bool need_exp,
                                     double t_now, double decay_rate,
                                     double& exp_sum) {
  int i = 0, j = 0;
  n_found = 0;
  form_min = std::numeric_limits<double>::infinity();
  form_max = -std::numeric_limits<double>::infinity();
  exp_sum = 0.0;
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
          if (form > form_max) form_max = form;
          if (form < form_min) form_min = form;
          if (need_exp) {
            exp_sum += std::exp(-(t_now - form) * decay_rate);
          }
          ++n_found;
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
                          double half_life = NA_REAL) {

  const R_xlen_t n = senders.size();
  if (n != receivers.size() || n != times.size()) {
    stop("senders, receivers, times must have the same length.");
  }

  unsigned int active = 0u;
  for (R_xlen_t i = 0; i < stat_names.size(); ++i) {
    unsigned int f = flag_for(as<std::string>(stat_names[i]));
    if (f == 0u) {
      stop("Stat not supported by the C++ inner loop: " +
           as<std::string>(stat_names[i]));
    }
    active |= f;
  }

  // exp_decay stats require a positive finite half-life. Mirrors the
  // pure-R caller's validation so the dispatch is transparent.
  double decay_rate = 0.0;
  if (active & F_ANY_EXP_DECAY) {
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
  const bool need_outdeg    = active & F_SENDER_OUTDEGREE;
  const bool need_indeg     = active & F_RECEIVER_INDEGREE;
  const bool need_recency   = active & F_RECENCY;
  const bool need_triadic_cnt  = need_trans_cnt || need_cyclic_cnt || need_sb_cnt || need_rb_cnt;
  const bool need_triadic_time = need_trans_time || need_cyclic_time || need_sb_time || need_rb_time;
  const bool need_triadic_exp  = need_trans_exp || need_cyclic_exp || need_sb_exp || need_rb_exp;
  const bool need_triadic   = need_triadic_cnt || need_triadic_time || need_triadic_exp;
  // need_X for the joint family walk: we share the intersection between
  // timing and exp_decay readers since both use first_dyad_time.
  const bool need_trans_form  = need_trans_time || need_trans_exp;
  const bool need_cyclic_form = need_cyclic_time || need_cyclic_exp;
  const bool need_sb_form     = need_sb_time     || need_sb_exp;
  const bool need_rb_form     = need_rb_time     || need_rb_exp;

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

  // 4. Main loop.
  for (R_xlen_t i = 0; i < n; ++i) {
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
      if (need_trans_form) {
        int nk; double fmin, fmax, esum;
        walk_intersect_formation(s_out, r_in, s, r, dyad_first_time,
          [s, A](int k) { return (long long)s * A + k; },
          [r, A](int k) { return (long long)k * A + r; },
          nk, fmin, fmax,
          need_trans_exp, ti, decay_rate, esum);
        if (nk > 0) {
          if (active & F_TRANSITIVITY_TIME_RECENT) transitivity_time_recent[i] = ti - fmax;
          if (active & F_TRANSITIVITY_TIME_FIRST)  transitivity_time_first[i]  = ti - fmin;
        }
        if (need_trans_exp) transitivity_exp_decay[i] = esum;
      }
      if (need_cyclic_form) {
        int nk; double fmin, fmax, esum;
        walk_intersect_formation(r_out, s_in, s, r, dyad_first_time,
          [r, A](int k) { return (long long)r * A + k; },
          [s, A](int k) { return (long long)k * A + s; },
          nk, fmin, fmax,
          need_cyclic_exp, ti, decay_rate, esum);
        if (nk > 0) {
          if (active & F_CYCLIC_TIME_RECENT) cyclic_time_recent[i] = ti - fmax;
          if (active & F_CYCLIC_TIME_FIRST)  cyclic_time_first[i]  = ti - fmin;
        }
        if (need_cyclic_exp) cyclic_exp_decay[i] = esum;
      }
      if (need_sb_form) {
        int nk; double fmin, fmax, esum;
        walk_intersect_formation(s_out, r_out, s, r, dyad_first_time,
          [s, A](int k) { return (long long)s * A + k; },
          [r, A](int k) { return (long long)r * A + k; },
          nk, fmin, fmax,
          need_sb_exp, ti, decay_rate, esum);
        if (nk > 0) {
          if (active & F_SENDING_BALANCE_TIME_RECENT) sending_balance_time_recent[i] = ti - fmax;
          if (active & F_SENDING_BALANCE_TIME_FIRST)  sending_balance_time_first[i]  = ti - fmin;
        }
        if (need_sb_exp) sending_balance_exp_decay[i] = esum;
      }
      if (need_rb_form) {
        int nk; double fmin, fmax, esum;
        walk_intersect_formation(s_in, r_in, s, r, dyad_first_time,
          [s, A](int k) { return (long long)k * A + s; },
          [r, A](int k) { return (long long)k * A + r; },
          nk, fmin, fmax,
          need_rb_exp, ti, decay_rate, esum);
        if (nk > 0) {
          if (active & F_RECEIVING_BALANCE_TIME_RECENT) receiving_balance_time_recent[i] = ti - fmax;
          if (active & F_RECEIVING_BALANCE_TIME_FIRST)  receiving_balance_time_first[i]  = ti - fmin;
        }
        if (need_rb_exp) receiving_balance_exp_decay[i] = esum;
      }
    }

    // --- state update (after stats are read) ---
    sender_count[s] += 1;
    receiver_count[r] += 1;
    dyad_event_count[key_sr] += 1;
    dyad_last_time[key_sr] = ti;
    {
      auto it = dyad_first_time.find(key_sr);
      if (it == dyad_first_time.end()) dyad_first_time.emplace(key_sr, ti);
    }
    if (need_triadic) {
      sorted_insert_unique(out_targets[s], r);
      sorted_insert_unique(in_sources[r], s);
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
  return out;
}

// [[Rcpp::export(rng = false)]]
CharacterVector cpp_supported_stats() {
  CharacterVector v(SUPPORTED_STATS.size());
  for (size_t i = 0; i < SUPPORTED_STATS.size(); ++i) v[i] = SUPPORTED_STATS[i];
  return v;
}
