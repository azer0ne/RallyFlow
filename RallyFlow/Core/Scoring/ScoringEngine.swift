//
//  ScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A domain service that applies scoring events to match score state.
nonisolated protocol ScoringEngine: Sendable {
    /// Returns the state produced by applying an event to an existing score.
    ///
    /// - Parameters:
    ///   - event: The scoring event to process.
    ///   - state: The score state before the event.
    ///   - configuration: The rules governing the match.
    /// - Returns: The updated score state.
    /// - Throws: An implementation-specific error when the event cannot be applied.
    func apply(
        event: ScoreEvent,
        to state: MatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> MatchScoreState
}
