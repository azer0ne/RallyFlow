//
//  MatchStatus.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// The lifecycle state of a match.
enum MatchStatus: String, Codable, Sendable {
    /// Generated as a possible match.
    case suggested

    /// Provisionally selected but still subject to change.
    case tentative

    /// Confirmed and no longer eligible for automatic changes.
    case locked

    /// Prepared to begin.
    case ready

    /// Currently in progress.
    case playing

    /// Finished successfully.
    case completed

    /// Stopped before completion.
    case cancelled
}
