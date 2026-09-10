//
//  SetPhase.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum SetPhase: Codable, Hashable, Sendable {
    case regularGame
    case tiebreakRequired
    case tiebreak(TiebreakScore)
}
