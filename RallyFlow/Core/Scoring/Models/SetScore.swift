//
//  SetScore.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The number of games won by each team in a set.
nonisolated struct SetScore: Codable, Hashable, Sendable {
    /// The number of games won by Team A.
    var teamAGames: Int

    /// The number of games won by Team B.
    var teamBGames: Int

    /// The final tiebreak score when the set was decided by a tiebreak.
    var tiebreakScore: TiebreakScore?

    /// Creates a set score, initially zero-zero by default.
    ///
    /// - Parameters:
    ///   - teamAGames: The number of games won by Team A.
    ///   - teamBGames: The number of games won by Team B.
    ///   - tiebreakScore: The final tiebreak score, when applicable.
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
