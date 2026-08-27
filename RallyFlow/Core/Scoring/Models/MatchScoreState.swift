//
//  MatchScoreState.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The live score state for a match, separated by point-counting system.
nonisolated enum MatchScoreState: Codable, Hashable, Sendable {
    /// Tennis point, game, and set state.
    case tennis(TennisMatchScoreState)

    /// Rally-scored point and game state.
    case rally(RallyMatchScoreState)

    /// Pickleball side-out point state.
    case pickleballSideOut(PickleballMatchScoreState)
}

/// The live score of a tennis match.
nonisolated struct TennisMatchScoreState: Codable, Hashable, Sendable {
    /// The point state of the current game.
    var currentGame: TennisGameScore

    /// The number of games won by Team A in the current set or match structure.
    var teamAGames: Int

    /// The number of games won by Team B in the current set or match structure.
    var teamBGames: Int

    /// The scores of completed sets.
    var completedSets: [SetScore]

    /// The zero-based index of the current game.
    var currentGameIndex: Int

    /// The zero-based index of the current set.
    var currentSetIndex: Int

    /// The scoring phase of the current set.
    var setPhase: SetPhase

    /// The team configured to serve the first point of the next tiebreak.
    ///
    /// This focused value is used until general match server tracking is introduced.
    var tiebreakStartingServer: TeamSide

    /// Whether the match has reached its configured ending condition.
    var isMatchComplete: Bool

    /// Creates a tennis score state at the beginning of a match by default.
    init(
        currentGame: TennisGameScore = .points(teamA: .love, teamB: .love),
        teamAGames: Int = 0,
        teamBGames: Int = 0,
        completedSets: [SetScore] = [],
        currentGameIndex: Int = 0,
        currentSetIndex: Int = 0,
        setPhase: SetPhase = .regularGame,
        tiebreakStartingServer: TeamSide = .teamA,
        isMatchComplete: Bool = false
    ) {
        self.currentGame = currentGame
        self.teamAGames = teamAGames
        self.teamBGames = teamBGames
        self.completedSets = completedSets
        self.currentGameIndex = currentGameIndex
        self.currentSetIndex = currentSetIndex
        self.setPhase = setPhase
        self.tiebreakStartingServer = tiebreakStartingServer
        self.isMatchComplete = isMatchComplete
    }
}

/// The live score of a rally-scored match.
nonisolated struct RallyMatchScoreState: Codable, Hashable, Sendable {
    /// The score of the current game or point race.
    var currentGame: GameScore

    /// The scores of completed games in a multi-game structure.
    var completedGames: [GameScore]

    /// The number of games won by Team A.
    var teamAGames: Int

    /// The number of games won by Team B.
    var teamBGames: Int

    /// The zero-based index of the current game.
    var currentGameIndex: Int

    /// Whether the match has reached its configured ending condition.
    var isMatchComplete: Bool

    /// Creates a rally score state at the beginning of a match by default.
    init(
        currentGame: GameScore = GameScore(),
        completedGames: [GameScore] = [],
        teamAGames: Int = 0,
        teamBGames: Int = 0,
        currentGameIndex: Int = 0,
        isMatchComplete: Bool = false
    ) {
        self.currentGame = currentGame
        self.completedGames = completedGames
        self.teamAGames = teamAGames
        self.teamBGames = teamBGames
        self.currentGameIndex = currentGameIndex
        self.isMatchComplete = isMatchComplete
    }
}

/// The live numeric score of a pickleball side-out match.
///
/// Serving-team and server-position state will be added with side-out engine behavior.
nonisolated struct PickleballMatchScoreState: Codable, Hashable, Sendable {
    /// The current numeric score.
    var score: GameScore

    /// Whether the match has reached its configured ending condition.
    var isMatchComplete: Bool

    /// Creates a pickleball score state at the beginning of a match by default.
    init(score: GameScore = GameScore(), isMatchComplete: Bool = false) {
        self.score = score
        self.isMatchComplete = isMatchComplete
    }
}
