# Bipartite support for closure-family endogenous stats — design notes

## Status quo

The simulator enforces `identical(senders, receivers)` whenever any
closure-family endogenous statistic is requested. Internally:

- `adj_state` is `S × S` (= `S × R` because `senders == receivers`).
- Reciprocity update writes `adj_state[r_idx, s_idx]` (swap).
- Transitivity / cyclic / sending_balance / receiving_balance use
  the same `S × S` `adj_state` and the same swap convention.

Per-actor statistics (`recency`, `sender_outdegree`,
`receiver_indegree`) already work in bipartite settings because they
don't use a swap or a closure intermediary.

## Goal

Allow `senders = A`, `receivers = B` with any overlap pattern (from
pure bipartite, `A ∩ B = ∅`, to full one-mode, `A = B`). All
closure stats should evaluate correctly, with the natural zero
behaviour when a configuration is structurally impossible (e.g.
reciprocity at `(s, r)` requires `r ∈ A` and `s ∈ B`).

## Design

Use a unified actor universe `U = unique(c(senders, receivers))`
with stable ordering. Define:

- `S_pos[s_i]` = position of sender `s_i` in `U`.
- `R_pos[r_j]` = position of receiver `r_j` in `U`.
- `adj_state` and every closure-family state matrix become `|U| × |U|`.

On event `(s_i, r_j)` firing, the unified positions are
`(S_pos[s_i], R_pos[r_j])`. All state updates index into the
`|U| × |U|` matrices using these positions.

For the rate computation at dyads `(s, r) ∈ S × R`:

- Build the per-dyad rate matrix `W` over `S × R` (unchanged).
- For closure stats, evaluate per `(s, r)` by indexing into the
  `|U| × |U|` state matrices at `(S_pos[s], R_pos[r])`.

### Per-family update rules in unified coordinates

For event `(s, r)` with unified positions `i = S_pos[s]`,
`j = R_pos[r]`:

- `reciprocity_count`: `state[j, i] += 1` (writes to the reverse
  cell in `U × U` space). If `r ∉ A` or `s ∉ B`, this cell is
  never read by the rate computation — harmless.
- `transitivity_count` (at `(s, r)`): unchanged semantics in
  unified space (count `k ∈ U` such that `adj[i, k] = 1` and
  `adj[k, j] = 1`).
- `cyclic_count`, `sending_balance_count`,
  `receiving_balance_count`: analogous, all evaluated in
  unified `U × U` adjacency.

### Memory & cost

- Worst case `|U| = |S| + |R|` (pure bipartite). State matrices
  grow from `S × R` to `|U|² ≤ (S + R)²`.
- Matrix products `AA`, `AAt`, `AtA` go from `S × S` (one-mode) /
  `S × R` (mixed) to `|U|²`. Per-event recomputation cost
  scales as `|U|³` in the worst case.
- The simulator extracts the relevant `S × R` sub-block from
  the resulting `|U| × |U|` count matrices for the rate matrix.

In practice the one-mode case stays cheap because `|U| = S`
exactly. The new cost lands only on workloads that genuinely
need bipartite closure stats.

### Validation strategy

Three test layers:

1. One-mode regression: with `senders == receivers`, every
   existing test must still pass. The refactor should be a
   semantically identity-preserving rewrite at the API boundary.
2. Bipartite synthetic: hand-crafted small bipartite logs with
   computed-by-hand closure-count expectations.
3. Cross-implementation parity:
   `compute_endogenous_features()` must reach parity with the
   simulator in the new bipartite mode too — extends the existing
   parity suite to bipartite seeds.

### Phases / proposed PRs

- **Phase 1**: refactor the simulator's state machinery to `U × U`
  while keeping the existing one-mode constraint check active.
  All existing tests pass; no API change. Internal-only.
- **Phase 2**: relax the one-mode constraint check, add bipartite
  unit tests for each closure-family update path.
- **Phase 3**: mirror the change in the post-hoc engine; extend
  the parity suite to bipartite seeds.
- **Phase 4**: update docs / vignettes / whitepaper Limitations
  bullet.

## Out of scope (for now)

- The `_interrupted` variants in bipartite. Each interrupted
  family asks "did the closure event fire?". In bipartite the
  closure event is the same `(s, r)` firing as in one-mode —
  semantics should carry over, but we should add bipartite tests
  to confirm.
- Bipartite-specific stats (e.g. 4-cycle counts in two-mode
  networks). Out of scope; these are new statistics, not
  bipartite generalisations of the existing ones.
