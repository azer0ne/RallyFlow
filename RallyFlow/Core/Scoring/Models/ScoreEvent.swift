//
//  ScoreEvent.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A scoring action that can be processed by a scoring engine.
nonisolated enum ScoreEvent: Codable, Hashable, Sendable {
    /// Team A won the latest rally.
    case teamAWonRally

    /// Team B won the latest rally.
    case teamBWonRally

    /// Revert the most recently applied scoring event.
    case undo
}
