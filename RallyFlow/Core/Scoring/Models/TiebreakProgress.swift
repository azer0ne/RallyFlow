//
//  TiebreakProgress.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated enum TiebreakProgress: Codable, Hashable, Sendable {
    case inProgress(TiebreakScore)
    case completed(score: TiebreakScore, winner: TeamSide)
}
