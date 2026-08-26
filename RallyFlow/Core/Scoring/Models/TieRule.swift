//
//  TieRule.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The rule used to resolve a tied match or fixed structure.
nonisolated enum TieRule: Codable, Hashable, Sendable {
    /// The match finishes as a draw.
    case draw

    /// One additional game decides the match.
    case decidingGame

    /// A tiebreak is played to a target while requiring a specified lead.
    case tiebreak(target: Int, winBy: Int)

    /// Play continues until a team reaches the specified lead.
    case continueUntilLead(by: Int)
}
