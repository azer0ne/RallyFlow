//
//  TieRule.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum TieRule: Codable, Hashable, Sendable {
    case draw
    case decidingGame
    case tiebreak(target: Int, winBy: Int)
    case continueUntilLead(by: Int)
}
