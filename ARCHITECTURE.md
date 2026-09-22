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
