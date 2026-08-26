//
//  ScoringEngineError.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// An error produced when a scoring engine cannot apply an event.
nonisolated enum ScoringEngineError: Error, Equatable, Sendable {
    /// The configuration uses a point system unsupported by the engine.
    case incompatiblePointSystem

    /// The score state is unsupported by the engine.
    case incompatibleScoreState

    /// A tennis configuration does not specify how deuce is resolved.
    case missingDeuceRule

    /// The requested event is not supported by the engine.
    case unsupportedEvent

    /// A scoring event was applied after the current game completed.
    case gameAlreadyComplete

    /// The match structure does not provide rules for progressing a tennis set.
    case missingSetRules

    /// Set progression was requested before the current game completed.
    case gameNotComplete

    /// The current set requires tiebreak scoring, which is not yet supported.
    case tiebreakScoringRequired
}
