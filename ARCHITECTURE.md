# RallyFlow Architecture

RallyFlow uses MVVM for UI-facing features:

```text
View -> ViewModel -> Domain / Services / Engines
```

## Views

Views render UI, bind to ViewModel state, and forward user interactions. They do not contain business rules.

## ViewModels

ViewModels own screen state, handle user intents, coordinate domain services, and map domain state into presentation-friendly state. Future modern SwiftUI ViewModels should prefer `@MainActor @Observable` where supported. Scoring formulas, matchmaking algorithms, and standings calculations do not belong in ViewModels.

## Core

Core owns reusable domain models, session behavior, scoring engines, matchmaking engines, and standings calculations. It remains independent from SwiftUI and other presentation concerns.

## Persistence

Persistence will be implemented later behind a boundary. Core domain models remain value types and are not SwiftData `@Model` types.

Feature folders should be split by actual complexity rather than boilerplate. A typical feature may contain its View, ViewModel, and focused Components without generic base ViewModel or base model types.

## Matchmaking history

`ParticipantMatchHistory` is the source of truth for completed-match facts used by matchmaking, including match counts, relationship counts, recency, and waiting derived from recorded rotation eligibility. The counters already present on `SessionParticipant` remain a current session-state snapshot for the future session engine; matchmaking history does not mutate or reconcile them.

A waiting round means the player was eligible for that rotation but was not selected. A player omitted from the entry's eligible set is treated as voluntarily or operationally unavailable: the absence adds no waiting round and breaks both consecutive-play and consecutive-rest streaks. These are factual inputs only; their future relative priority belongs to M3.4.

Simultaneous completions may carry an explicit `MatchHistoryEntry.opportunitySequence`.
Entries in that group must be contiguous in match-sequence order, share eligibility, and
have non-overlapping participants. History advances play/rest streaks once per group;
match counts, relationships, and last-played sequence remain per completed match. Ungrouped
entries retain one opportunity per match, including when decoding older history. Grouping
must come from the caller's known scheduling opportunity, never inferred from court count.

M3.8 simulation infrastructure lives in `RallyFlowTests/Simulation`. It independently checks
trace metrics against history after every completed opportunity. The optional diagnostic runner
compiles the same Core sources; it is not a separate matchmaking implementation.

## Immediate Fair Social generation

`ImmediateMatchGenerator.generate(request:)` requires `.immediate` context and explicit
`MatchmakingCapacity`, including for an empty participant pool. It delegates eligibility and
enumeration to `MatchCandidateGenerator`, passes the unchanged request and full candidate pool
to `FairRotationCandidateRanker`, and returns its first suggestion or `nil` when no candidates
exist. Ranking errors propagate unchanged; empty candidate pools retain the ranker's existing
validation short circuit after context and capacity presence have been checked.

Only ready participants can enter an immediate suggestion; explicit eligibility can narrow
that pool but cannot admit playing participants. Multiple usable courts affect the adaptive
waiting baseline, but one call returns at most one suggestion. Generation never reserves a
player or court, changes participant counters or statuses, or appends history. The request has
no format field; this engine specifically composes the Fair Social ranker.

## Upcoming Fair Social generation

`UpcomingMatchGenerator` resolves a future-eligible pool for one slot from the roster and
relevant `ActiveMatchSnapshot` values. Enumeration and ranking share request eligibility.
An optional ranker projection accounts for one current participation/wait opportunity without
writing completed history or cached counters. The unchanged Fair Social comparison ranks the
resulting candidates. Playing participants need explicit authorization; leaving-soon players
require an explicit whitelist even when present in an active snapshot.

`UpcomingMatchSuggestion` captures selected active-player markers, with no reservation or
`MatchStatus`. Pure revalidation checks current legality; regeneration refreshes ranking and
metadata separately. Callers must remove completed snapshots and supply only active matches
expected to finish before this slot. Multiple independent suggestions may overlap.

## Multi-court Fair Social generation

`MultiCourtMatchScheduler` selects an exact maximum-cardinality set of non-overlapping
suggestions for caller-supplied `Court.ID` slots. It reuses upcoming preparation and the
ranker's request-local assessment. Primary participation fairness is evaluated once for the
whole batch, followed by additive relationship costs and consecutive-play burden. Per-match
metadata remains attached. Slots and winning candidates use canonical ordering.

See `M3_7_DESIGN.md` for the exact partition search, dominance proof, capacity contract,
and common-availability-horizon assumption. Batch revalidation reports conflicts without
repairing state. Reservations are exclusive only inside the returned value; M4 must own
atomic acceptance, persistence, and reconciliation of active snapshots with completed history.
