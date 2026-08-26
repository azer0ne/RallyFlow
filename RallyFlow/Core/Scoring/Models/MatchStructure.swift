//
//  MatchStructure.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The structure that determines when a match is complete.
nonisolated enum MatchStructure: Codable, Hashable, Sendable {
    /// A match containing exactly the specified number of games.
    case fixedGames(count: Int)

    /// A match won by the first team to reach the game target.
    case raceToGames(target: Int)

    /// A match won by taking a majority of games played to a point target.
    case bestOfGames(count: Int, pointsPerGame: Int, winBy: Int, cap: Int?)

    /// A match won by taking a majority of sets governed by the supplied rules.
    case bestOfSets(count: Int, setRules: SetRules)

    /// A match won by reaching a point target with the required lead.
    case raceToPoints(target: Int, winBy: Int, cap: Int?)

    /// A match that ends after the teams have played a fixed combined point total.
    case fixedTotalPoints(total: Int)

    /// A match that ends after the specified duration.
    case timed(durationSeconds: Int)
}
