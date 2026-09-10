//
//  MatchScoreState.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum MatchScoreState: Codable, Hashable, Sendable {
    case oneServeEach(OneServeEachScoreState)
    case tennis(TennisMatchScoreState)
    case rally(RallyMatchScoreState)
    case pickleballSideOut(PickleballMatchScoreState)
}

nonisolated struct TennisMatchScoreState: Codable, Hashable, Sendable {
    var currentGame: TennisGameScore
    var teamAGames: Int
    var teamBGames: Int
    var completedSets: [SetScore]
    var currentGameIndex: Int
    var currentSetIndex: Int
    var setPhase: SetPhase
    var tiebreakStartingServer: TeamSide
    var isMatchComplete: Bool
    
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

nonisolated struct RallyMatchScoreState: Codable, Hashable, Sendable {
    var currentGame: GameScore
    var completedGames: [GameScore]
    var teamAGames: Int
    var teamBGames: Int
    var currentGameIndex: Int
    var isMatchComplete: Bool
    
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

nonisolated struct PickleballMatchScoreState: Codable, Hashable, Sendable {
    var score: GameScore
    var isMatchComplete: Bool
    
    init(score: GameScore = GameScore(), isMatchComplete: Bool = false) {
        self.score = score
        self.isMatchComplete = isMatchComplete
    }
}
