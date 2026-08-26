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
