# M3.7 Multi-court Fair Social scheduling

## Inputs and ownership

`MatchmakingSlot` identifies one caller-supplied schedulable court using `Court.ID`.
Slots are interchangeable for this batch: every authorized participant must be expected
to be available for every supplied slot. The caller chooses the scheduling moment and
subset of courts; heterogeneous future completion times require separate calls.
For nonempty slot lists, explicit usable capacity must equal the number of supplied slots.
An empty slot list returns an empty batch after input validation, with positive capacity
still required by the existing request contract. Duplicate slots are errors.

`MatchmakingBatchSuggestion` captures context, match type, and court-linked assignments.
Each assignment preserves `MatchSuggestion` plus captured active-player markers. Exclusivity
exists only inside this result. No session reservations, locks, status changes, or history
writes occur. M4 must atomically revalidate and accept a batch against live reservations.

## Reuse and global comparison

Upcoming preparation is shared with M3.6, including explicit leaving-soon permission,
overlapping/unknown snapshot rejection, and one transient current-opportunity projection.
Immediate requests use existing ready-only eligibility and reject active snapshots rather
than silently projecting them. Completed snapshots must be removed by the caller when their
completion enters history. Without lifecycle IDs, repeated historical groupings cannot prove
that a supplied active snapshot is stale; no completion reconciliation is inferred.

The ranker builds one reusable assessment containing history inputs, candidate evaluations,
and their semantic explanations. Its existing participation calculation is reused for the
union of players in a batch. Selected players gain one projected match; unselected eligible
players miss one opportunity, not one per slot. Maximum feasible assignment count comes first.
Equal-cardinality batches minimize the unchanged M3.4 tuple:

1. worst match-count deficit or excessive-wait deficit;
2. number of participants at that worst deficit;
3. aggregate match deficits plus waiting excess;
4. summed partner repetition, then opponent repetition, then consecutive-play count;
5. sorted canonical candidate keys.

No individual ranks are summed. Per-match reasons retain their original candidate-pool
meaning, not a claim that each match independently won. No numerical product score is exposed.

## Exact search

Generate all candidates with M3.2 and assess them with M3.4. Pairings with the same player set
have identical participation effects and overlap constraints. Retain the pairing with the
best lexicographic secondary tuple and canonical key for each set. This is exact dominance
pruning because secondary costs add independently and slots have no per-court constraints.

Backtrack on the smallest remaining player: either choose a retained group containing that
player, or leave them unassigned when surplus players permit. Reject overlapping groups and
branches with insufficient remaining players. Stop at `min(slotCount, eligibleCount / P)`
assignments. This visits each unordered partition once, without slot permutations. Cache the
primary evaluation for repeated selected-player sets. Map sorted winning candidates onto
UUID-sorted slots, using the earliest slots when capacity cannot be filled.

Search remains combinatorial: for N players, P per match, and M assignments the number of
group partitions is N! / ((N-MP)! (P!)^M M!). Doubles pairing dominance removes a factor of
3^M. Twelve doubles players on three courts have 5,775 retained partitions, versus 155,925
pairing combinations. There is no heuristic cutoff or silent fallback. Larger rosters need
measurement before product support is expanded.

## Revalidation

Validation checks legality and exclusivity, not continued optimality or maximum occupancy.
It identifies the first invalid assignment in canonical court order: missing slot, duplicate
slot/player, changed type, missing participant, or lost eligibility. Context changes invalidate
the batch. Expected still-playing participants remain valid. Metadata is captured at generation
time; regenerate to refresh it. Malformed request/snapshot/capacity data throws focused errors.
No partial repair is performed. Slot additions are compatible; loss of a referenced slot is not.
