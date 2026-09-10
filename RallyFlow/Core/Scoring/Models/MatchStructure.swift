//
//  MatchStructure.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum MatchStructure: Codable, Hashable, Sendable {
    case fixedGames(count: Int)
    case raceToGames(target: Int)
    case bestOfGames(count: Int, pointsPerGame: Int, winBy: Int, cap: Int?)
    case bestOfSets(count: Int, setRules: SetRules)
    case raceToPoints(target: Int, winBy: Int, cap: Int?)
    case fixedTotalPoints(total: Int)
    case timed(durationSeconds: Int)
}
