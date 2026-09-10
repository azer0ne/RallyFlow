//
//  FixedTotalScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct FixedTotalScoringEngine: ScoringEngine {
    func apply(event: ScoreEvent, to state: MatchScoreState,
               configuration: ScoringConfiguration) throws -> MatchScoreState {
        let progress = try progress(for: state, configuration: configuration)
        guard case .rally(var score) = state else { throw ScoringEngineError.incompatibleScoreState }
        guard !score.isMatchComplete, progress.pointsRemaining > 0 else {
            throw ScoringEngineError.matchAlreadyCompleted
        }
        switch event {
        case .teamAWonRally: score.currentGame.teamAPoints += 1
        case .teamBWonRally: score.currentGame.teamBPoints += 1
        case .undo: throw ScoringEngineError.unsupportedEvent
        }
        score.isMatchComplete = progress.pointsRemaining == 1
        return .rally(score)
    }
    
    func progress(for state: MatchScoreState, configuration: ScoringConfiguration) throws -> FixedTotalProgress {
        guard configuration.pointSystem == .rally else { throw ScoringEngineError.incompatiblePointSystem }
        guard case .fixedTotalPoints(let total) = configuration.matchStructure else {
            throw ScoringEngineError.unsupportedMatchStructure
        }
        guard case .rally(let score) = state else { throw ScoringEngineError.incompatibleScoreState }
        let a = score.currentGame.teamAPoints
        let b = score.currentGame.teamBPoints
        guard a >= 0, b >= 0, a <= total, b <= total - a,
              score.completedGames.isEmpty, score.teamAGames == 0, score.teamBGames == 0 else {
            throw ScoringEngineError.invalidMatchState
        }
        guard !score.isMatchComplete || a + b == total else { throw ScoringEngineError.invalidMatchState }
        return FixedTotalProgress(pointsPlayed: a + b, pointsRemaining: total - a - b)
    }
    
    func result(for state: MatchScoreState, configuration: ScoringConfiguration) throws -> MatchResult? {
        let progress = try progress(for: state, configuration: configuration)
        guard progress.pointsRemaining == 0, case .rally(let score) = state, score.isMatchComplete else { return nil }
        let a = score.currentGame.teamAPoints
        let b = score.currentGame.teamBPoints
        return MatchResult(outcome: a == b ? .draw : a > b ? .teamAWin : .teamBWin, finalScore: state)
    }
}
