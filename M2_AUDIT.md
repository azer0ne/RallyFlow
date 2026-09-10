# M2 scoring audit

Date: 2026-09-10
Branch: feature/m2-scoring-engine
Verdict: PASS

## Gates

Every milestone passed its normal Xcode build and the entire RallyFlowTests
Swift Testing target before implementation of the next milestone began.

| Gate | Test declarations | Executions including parameter cases | Failures | Skips | Build |
| --- | ---: | ---: | ---: | ---: | --- |
| M2.7 | 106 | 117 | 0 | 0 | Passed |
| M2.8 | 114 | 139 | 0 | 0 | Passed |
| M2.9 | 119 | 153 | 0 | 0 | Passed |
| M2.10 | 124 | 174 | 0 | 0 | Passed |
| M2.11 | 130 | 184 | 0 | 0 | Passed |

M2.9 initially had a missing inner try in a throwing Swift Testing assertion.
That test compilation error was corrected before its gate passed.

Result bundles:

- /tmp/RallyFlow-M27-0909.xcresult
- /tmp/RallyFlow-M28-0909.xcresult
- /tmp/RallyFlow-M29b-0909.xcresult
- /tmp/RallyFlow-M210-0909.xcresult
- /tmp/RallyFlow-M211-0910.xcresult

Normal builds used the RallyFlow scheme, Debug configuration, and generic iOS
Simulator destination with no source exclusions or signing overrides.
Tests ran on iPhone 17 Pro, iOS 26.4, arm64, with the complete RallyFlowTests target.
The final additional build with SWIFT_STRICT_CONCURRENCY=complete also passed.
The project's existing Swift language-mode settings were preserved.
No source or concurrency warnings were reported. Xcode's supported-platform
scheme metadata notice is environmental, not a source warning.

## Implementation inventory

All production paths below are relative to RallyFlow/Core/Scoring.

### M2.7

Created:

- Engines/TennisPointEngine.swift
- Engines/OneServeEachEngine.swift
- Models/ServicePlayer.swift
- Models/DoublesServiceOrder.swift
- Models/OneServeEachPhase.swift
- Models/OneServeEachScoreState.swift
- RallyFlowTests/OneServeEachTests.swift (test-target path)

Modified TennisScoringEngine, MatchScoreState, ScoringConfiguration,
ScoringConfigurationError, and ScoringEngineError.

The existing point transition functions were extracted unchanged so both set
tennis and four-game tennis use the same rules. One Serve Each has a distinct
state variant and never calls the best-of-set evaluator.
The service order validates four unique player IDs on alternating sides,
including during decoding. Its first entry selects the starting player.
Completed game winners determine service position and game totals.
There is no fifth service game, including when a deciding tiebreak is pending.
A deciding tiebreak starts with the first service-order entry's team and uses
team-level tiebreak serving; per-player tiebreak service is not implemented.
Final service-game totals stay 2–2 when a tiebreak resolves the match, and the
completed phase retains both the outcome and final tiebreak points.

### M2.8

Created Engines/RallyScoringEngine.swift and RallyFlowTests/RallyScoringEngineTests.swift.
Modified ScoringConfiguration and ScoringConfigurationError to enforce positive,
odd best-of-game counts.

Point races honor target and margin. Reaching the cap wins regardless of margin.
Best-of-games preserves each completed numeric score, resets current points,
and completes at count / 2 + 1 game wins. Stored game-win totals are checked
against the completed games before scoring.

### M2.9

Created Engines/FixedTotalScoringEngine.swift, Models/FixedTotalProgress.swift,
and RallyFlowTests/FixedTotalScoringEngineTests.swift.

Fixed total uses the existing rally score variant. It completes at the combined
point total and supports draws. Played and remaining points are derived from
configuration and score. Negative scores, overshoots, and further scoring after
completion are rejected.

### M2.10

Created Engines/MatchScoringEngine.swift, ScoringHistory.swift, and
RallyFlowTests/ScoringHistoryTests.swift. Added the emptyHistory engine error.

The dispatcher selects an existing engine from configuration. It contains no
point, service, game, or match-winning formulas.
ScoringHistory owns one immutable configuration and initial state. A successful
rally saves the previous value snapshot and appends the effective event.
Undo restores that snapshot and removes the event. Failed events change neither
state nor history; undo is never recorded as a rally.
History copies are independent. Undo can reopen completed games, sets,
tiebreaks, and matches, including restoring the service position.
Raw stateless engines still reject undo; callers needing undo use
ScoringHistory.apply(event: .undo).
Snapshots consume memory proportional to retained scoring history. Redo,
history persistence, and session-level history are outside M2.

## Architecture findings

MVVM fit: the SwiftUI shell only renders a placeholder; future ViewModels can own
a ScoringHistory and forward events. All scoring decisions and results stay in Core.

- No SwiftUI, UIKit, or SwiftData imports in Core.
- No MainActor requirements, unchecked Sendable conformances, shared mutable
  scoring globals, service locators, singletons, or third-party dependencies.
- Scoring types use value semantics and nonisolated/Sendable boundaries.
- Engines are synchronous and deterministic; there are no async effects needing
  cancellation or task ownership.
- Point, set, tiebreak, match, four-service-game, numeric, fixed-total, dispatch,
  and history responsibilities remain separate. No monolithic engine was found.
- Existing M2.1–M2.6 tests remain intact and passing.
- Comment review retained rule, boundary, and complexity explanations without
  adding decorative separators or step-by-step narration.

## Domain and correctness findings

Supported: Advantage, No-Ad, standard and short sets, advantage sets, configurable
tiebreaks and serving sides, best-of-sets, four-player service order, draw or
deciding tiebreak at 2–2, numeric races, caps, best-of-games, arbitrary fixed totals,
and undo across all supported scoring boundaries.

The audit identified and fixed small earlier input-validation gaps:

- TennisScoringEngine now rejects unsupported structures before the first point.
- Required/active tiebreak scoring now checks the configured tied game score
  before awarding a point.
- TennisTiebreakEngine rejects negative or unrepresentable combined point state
  before arithmetic.

Regression tests were added in RallyFlowTests/M2AuditTests.swift.
Final normal build and all tests passed after these changes.

## Validation and test findings

Tests cover nonpositive targets/margins, caps below targets, odd best-of counts,
incomplete tiebreak configuration, invalid fixed totals, incorrect service-order
length, duplicate identities, and nonalternating sides. Configuration decoding
cannot bypass best-of validation; service-order decoding also revalidates.

New coverage adds 30 declarations and 80 executions to the M2.6 baseline.
Coverage exercises observable transitions and results, including 17 undo
boundary scenarios and replay agreement through a full tennis match.
Generated-ID tests remain part of the full suite but are not counted as evidence
of scoring correctness. No required supported-flow coverage gap was found.

The final headless scenario test runs each scenario from an initial score,
checks its expected outcome, round-trips MatchResult through Codable, replays all
events, then undoes the final rally and verifies exact restoration:

| Scenario | Verified result |
| --- | --- |
| A: Best of 3, Advantage, 6-game sets, 6–6 tiebreak | 7–6 (9–7 tiebreak), 0–6, 6–0; Team A |
| B: One Serve Each, No-Ad, draw | 2–2 draw |
| C: One Serve Each, Advantage, deciding tiebreak | 2–2 service games, Team B wins tiebreak |
| D: Numeric race to 21, win by 2 | 20–22; Team B |
| E: Fixed total 24 | 15–9; Team A |
| F: Undo final rally in A–E | Exact prior state restored; match reopened |

Scenarios A–C use side-based scoring; individual players are required only for
One Serve Each service order. Sport compatibility is deliberately outside Core
scoring behavior.

## Priorities and readiness

- P0: None.
- P1: None unresolved. The small validation findings above were fixed and verified.
- P2: Before accepting externally restored snapshots, add validation at the
  restoration boundary. Existing mutable tennis/rally models permit arbitrary
  manually constructed state; this audit does not claim exhaustive validation
  of untrusted serialized score data. Current scoring/history flows do not ingest
  external data.

M2 can be marked complete. Matchmaking, sessions, standings, persistence, scoring
UI, ViewModels, sport compatibility, pickleball side-out, timed scoring, and
networking remain outside this implementation. No M3 work, commit, or push was performed.
