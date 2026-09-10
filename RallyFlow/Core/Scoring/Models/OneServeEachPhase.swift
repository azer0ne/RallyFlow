//
//  OneServeEachPhase.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated enum OneServeEachPhase: Codable, Hashable, Sendable {
    case serviceGame(TennisGameScore)
    case tiebreak(TiebreakScore)
    case completed(MatchOutcome, tiebreak: TiebreakScore?)
}
