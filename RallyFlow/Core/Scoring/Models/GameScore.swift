//
//  GameScore.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum TennisPoint: Int, Codable, Hashable, Sendable {
    case love
    case fifteen
    case thirty
    case forty
}

nonisolated enum TeamSide: String, Codable, Hashable, Sendable {
    case teamA
    case teamB
}

nonisolated enum TennisGameScore: Codable, Hashable, Sendable {
    case points(teamA: TennisPoint, teamB: TennisPoint)
    case deuce
    case advantage(TeamSide)
    case game(TeamSide)
}

nonisolated struct GameScore: Codable, Hashable, Sendable {
    var teamAPoints: Int
    var teamBPoints: Int
    
    init(teamAPoints: Int = 0, teamBPoints: Int = 0) {
        self.teamAPoints = teamAPoints
        self.teamBPoints = teamBPoints
    }
}
