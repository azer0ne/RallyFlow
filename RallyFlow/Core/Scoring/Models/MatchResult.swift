//
//  MatchResult.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The outcome of a completed match.
nonisolated enum MatchOutcome: String, Codable, Hashable, Sendable {
    /// Team A won the match.
    case teamAWin

    /// Team B won the match.
    case teamBWin

    /// The match finished as a draw.
    case draw
}

/// An immutable result containing the outcome and final score snapshot.
nonisolated struct MatchResult: Codable, Hashable, Sendable {
    /// The match outcome.
    let outcome: MatchOutcome

    /// The final score snapshot.
    let finalScore: MatchScoreState

    /// Creates a completed match result.
    ///
    /// - Parameters:
    ///   - outcome: The match outcome.
    ///   - finalScore: The final score snapshot.
    init(outcome: MatchOutcome, finalScore: MatchScoreState) {
        self.outcome = outcome
        self.finalScore = finalScore
    }
}
