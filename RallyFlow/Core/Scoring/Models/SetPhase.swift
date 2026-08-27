//
//  SetPhase.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The scoring phase of the current tennis set.
nonisolated enum SetPhase: Codable, Hashable, Sendable {
    /// The set is accepting regular tennis-game scoring.
    case regularGame

    /// The configured tied game score has been reached and requires a tiebreak.
    case tiebreakRequired

    /// A tiebreak is actively being scored.
    case tiebreak(TiebreakScore)
}
