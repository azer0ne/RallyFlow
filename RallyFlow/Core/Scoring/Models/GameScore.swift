//
//  GameScore.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A tennis point value before deuce or advantage.
nonisolated enum TennisPoint: Int, Codable, Hashable, Sendable {
    /// Zero points.
    case love

    /// One point.
    case fifteen

    /// Two points.
    case thirty

    /// Three points.
    case forty
}

/// A team side within a match.
nonisolated enum TeamSide: String, Codable, Hashable, Sendable {
    /// Team A.
    case teamA

    /// Team B.
    case teamB
}

/// The point state of an individual tennis game.
nonisolated enum TennisGameScore: Codable, Hashable, Sendable {
    /// Ordinary tennis point values before deuce.
    case points(teamA: TennisPoint, teamB: TennisPoint)

    /// Both teams are tied at deuce.
    case deuce

    /// The specified team holds advantage.
    case advantage(TeamSide)

    /// The game is complete and was won by the specified team.
    case game(TeamSide)
}

/// A numeric score for an individual rally-scored game.
nonisolated struct GameScore: Codable, Hashable, Sendable {
    /// Team A's points in the game.
    var teamAPoints: Int

    /// Team B's points in the game.
    var teamBPoints: Int

    /// Creates a numeric game score, initially zero-zero by default.
    ///
    /// - Parameters:
    ///   - teamAPoints: Team A's current points.
    ///   - teamBPoints: Team B's current points.
    init(teamAPoints: Int = 0, teamBPoints: Int = 0) {
        self.teamAPoints = teamAPoints
        self.teamBPoints = teamBPoints
    }
}
