//
//  RallyScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct RallyScoringEngine: ScoringEngine {
    func apply(event: ScoreEvent, to state: MatchScoreState,
               configuration: ScoringConfiguration) throws -> MatchScoreState {
        guard configuration.pointSystem == .rally else { throw ScoringEngineError.incompatiblePointSystem }
        guard case .rally(var score) = state else { throw ScoringEngineError.incompatibleScoreState }
        let rules = try rules(for: configuration)
        guard !score.isMatchComplete else { throw ScoringEngineError.matchAlreadyCompleted }
        try validate(score, rules: rules)
        guard winner(of: score.currentGame, rules: rules) == nil else {
            throw ScoringEngineError.gameAlreadyComplete
        }
        switch event {
        case .teamAWonRally:
            guard score.currentGame.teamAPoints < Int.max else { throw ScoringEngineError.invalidMatchState }
            score.currentGame.teamAPoints += 1
        case .teamBWonRally:
            guard score.currentGame.teamBPoints < Int.max else { throw ScoringEngineError.invalidMatchState }
            score.currentGame.teamBPoints += 1
        case .undo: throw ScoringEngineError.unsupportedEvent
        }
        if let side = winner(of: score.currentGame, rules: rules) {
            if let count = rules.bestOf {
                score.completedGames.append(score.currentGame)
                if side == .teamA { score.teamAGames += 1 } else { score.teamBGames += 1 }
                score.isMatchComplete = max(score.teamAGames, score.teamBGames) >= count / 2 + 1
                score.currentGame = GameScore()
                if !score.isMatchComplete { score.currentGameIndex += 1 }
            } else {
                score.isMatchComplete = true
            }
        }
        return .rally(score)
    }

    /// Uses configuration to distinguish final point totals from best-of game totals.
    func result(for state: MatchScoreState, configuration: ScoringConfiguration) throws -> MatchResult? {
        guard configuration.pointSystem == .rally else { throw ScoringEngineError.incompatiblePointSystem }
        guard case .rally(let score) = state else { throw ScoringEngineError.incompatibleScoreState }
        let rules = try rules(for: configuration)
        guard score.isMatchComplete else { return nil }
        try validate(score, rules: rules)
        let side: TeamSide?
        if let count = rules.bestOf {
            if score.teamAGames >= count / 2 + 1 { side = .teamA }
            else if score.teamBGames >= count / 2 + 1 { side = .teamB }
            else { side = nil }
        } else {
            side = winner(of: score.currentGame, rules: rules)
        }
        guard let side else { throw ScoringEngineError.invalidMatchState }
        return MatchResult(outcome: side == .teamA ? .teamAWin : .teamBWin, finalScore: state)
    }

    private func rules(for configuration: ScoringConfiguration) throws -> (
        target: Int, winBy: Int, cap: Int?, bestOf: Int?
    ) {
        switch configuration.matchStructure {
        case .raceToPoints(let target, let winBy, let cap): return (target, winBy, cap, nil)
        case .bestOfGames(let count, let target, let winBy, let cap): return (target, winBy, cap, count)
        default: throw ScoringEngineError.unsupportedMatchStructure
        }
    }

    private func winner(of score: GameScore, rules: (target: Int, winBy: Int, cap: Int?, bestOf: Int?)) -> TeamSide? {
        let a = score.teamAPoints
        let b = score.teamBPoints
        if let cap = rules.cap {
            if a >= cap { return .teamA }
            if b >= cap { return .teamB }
        }
        if a >= rules.target, a - b >= rules.winBy { return .teamA }
        if b >= rules.target, b - a >= rules.winBy { return .teamB }
        return nil
    }

    private func validate(_ score: RallyMatchScoreState,
                          rules: (target: Int, winBy: Int, cap: Int?, bestOf: Int?)) throws {
        guard score.currentGame.teamAPoints >= 0, score.currentGame.teamBPoints >= 0 else {
            throw ScoringEngineError.invalidMatchState
        }
        if let cap = rules.cap {
            guard score.currentGame.teamAPoints <= cap, score.currentGame.teamBPoints <= cap,
                  !(score.currentGame.teamAPoints == cap && score.currentGame.teamBPoints == cap) else {
                throw ScoringEngineError.invalidMatchState
            }
        }
        var a = 0
        var b = 0
        for game in score.completedGames {
            guard game.teamAPoints >= 0, game.teamBPoints >= 0,
                  let side = winner(of: game, rules: rules), let count = rules.bestOf,
                  max(a, b) < count / 2 + 1 else { throw ScoringEngineError.invalidMatchState }
            if side == .teamA { a += 1 } else { b += 1 }
        }
        guard score.teamAGames == a, score.teamBGames == b else { throw ScoringEngineError.invalidMatchState }
        if let count = rules.bestOf, !score.isMatchComplete, max(a, b) >= count / 2 + 1 {
            throw ScoringEngineError.matchAlreadyCompleted
        }
    }
}
