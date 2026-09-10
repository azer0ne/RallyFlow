//
//  SetScore.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated struct SetScore: Codable, Hashable, Sendable {
    var teamAGames: Int
    var teamBGames: Int
    var tiebreakScore: TiebreakScore?
    
    init(
        teamAGames: Int = 0,
        teamBGames: Int = 0,
        tiebreakScore: TiebreakScore? = nil
    ) {
        self.teamAGames = teamAGames
        self.teamBGames = teamBGames
        self.tiebreakScore = tiebreakScore
    }
}
