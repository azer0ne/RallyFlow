# Matchmaking simulation contract

The harness uses production immediate, upcoming, and batch schedulers. The seeded baseline
only selects from production-generated legal candidates and removes overlaps. It is random
sequential packing, not uniform sampling of all complete batches. SplitMix64 and rejection
sampling make its choices repeatable without system randomness.

One step is one caller-defined synchronous scheduling opportunity. All matches in a batch
complete together. Independent trace metrics count a selected player once and an eligible
unselected player once per step. Voluntary absence resets streaks without adding waiting.
The same opportunity must be represented faithfully in completed history; serializing a batch
as unrelated matches would count other courts as missed opportunities and bias the next call.

Upcoming runs bootstrap with an immediate decision, generate the next batch before recording
the current completion, then replace the active snapshots. A current match is never in history
while being projected. The final step completes its active matches without generating unused
future work. Availability perturbations are immediate-only to avoid inventing mid-match exits.

Stable runs cover 40-50 one-court matches and 50-54 multi-court matches. Longer diagnostic runs
are opt-in through the command-line runner's step multiplier. Normal tests use bounded runs.

Engineering alarms (not production guarantees):

- Match-count spread at every prefix <= 2, allowing one opportunity of imbalance plus one
  joint-objective tradeoff. Saturated courts should have spread zero.
- Waiting <= two complete coverage cycles minus one, where a cycle is ceil(N / actual playable
  capacity). This deliberately allows more than the adaptive baseline; no hard rest cap is implied.
- Starvation means missing at least two coverage cycles AND trailing an eligible peer by at
  least two completed matches at the same prefix. Short runs cannot prove absence of starvation.
- When rest is possible, consecutive play <= twice ceil(capacity / resting places), allowing
  twice the evenly distributed minimum longest play run. Saturated capacity has no possible rest.
- After these runs, doubles players should have met at least half their possible partners and
  opponents. Maximum pair frequency <= three times ceil(total relationship events / possible
  pairs) is a loose concentration alarm, not an optimization target.

No weights or tie-break rules are tuned to these fixtures. Report actual per-ID distributions,
repetition concentration, and baseline tradeoffs even when the alarms pass. Repetition totals
count uses after the first per unordered relationship and inevitably rise with session length.

Diagnostic runtime is measured with monotonic uptime around actual scheduler calls only.
Timing is excluded from deterministic equality and never gates tests. Candidate counts are
measured by generation; partition counts in the report are combinatorial bounds, not telemetry.

Run `bash scripts/run-matchmaking-simulations.sh` from the repository for optimized local JSONL
diagnostics. An optional integer multiplier (1-20) scales the session lengths; it is not part of
normal CI. The script creates an isolated temporary compiler directory and leaves it available
for inspection. It does not rewrite source or require a simulator. Xcode Swift Testing remains
the verification gate for the application and test target.

Known diagnostic witness: exactly two full player groups on one court can alternate forever.
Match counts and waiting pass their alarms while the relationship graph stays disconnected.
The witness test documents this limitation; it does not certify social variety as acceptable.
