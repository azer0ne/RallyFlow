//
//  TennisScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated struct TennisScoringEngine: ScoringEngine {
    init() {}
    
    nonisolated func apply(
        event: ScoreEvent,
        to state: MatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> MatchScoreState {
        guard configuration.pointSystem == .tennis else {
            throw ScoringEngineError.incompatiblePointSystem
        }
        guard case .tennis(let tennisState) = state else {
            throw ScoringEngineError.incompatibleScoreState
        }
        guard !tennisState.isMatchComplete else {
            throw ScoringEngineError.matchAlreadyCompleted
        }
        guard case .bestOfSets = configuration.matchStructure else {
            throw ScoringEngineError.missingSetRules
        }
        
        switch tennisState.setPhase {
        case .regularGame:
            return .tennis(
                try applyRegularGame(
                    event: event,
                    to: tennisState,
                    configuration: configuration
                )
            )
        case .tiebreakRequired:
            let initialScore = TiebreakScore(
                startingServer: tennisState.tiebreakStartingServer
            )
            return .tennis(
                try applyTiebreak(
                    event: event,
                    score: initialScore,
                    to: tennisState,
                    configuration: configuration
                )
            )
        case .tiebreak(let score):
            return .tennis(
                try applyTiebreak(
                    event: event,
                    score: score,
                    to: tennisState,
                    configuration: configuration
                )
            )
        }
    }
}

private extension TennisScoringEngine {
    nonisolated func applyRegularGame(
        event: ScoreEvent,
        to state: TennisMatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> TennisMatchScoreState {
        guard let deuceRule = configuration.deuceRule else {
            throw ScoringEngineError.missingDeuceRule
        }
        
        let rallyWinner: TeamSide
        switch event {
        case .teamAWonRally:
            rallyWinner = .teamA
        case .teamBWonRally:
            rallyWinner = .teamB
        case .undo:
            throw ScoringEngineError.unsupportedEvent
        }
        
        guard case .game = state.currentGame else {
            var updatedState = state
            updatedState.currentGame = try TennisPointEngine().score(
                afterRallyWonBy: rallyWinner,
                currentScore: state.currentGame,
                deuceRule: deuceRule
            )
            
            if case .game = updatedState.currentGame {
                let completedSetCount = updatedState.completedSets.count
                updatedState = try TennisSetEngine().advanceAfterCompletedGame(
                    in: updatedState,
                    configuration: configuration
                )
                if updatedState.completedSets.count > completedSetCount {
                    updatedState = try TennisMatchEngine().evaluateAfterCompletedSet(
                        in: updatedState,
                        configuration: configuration
                    )
                }
            }
            
            return updatedState
        }
        
        throw ScoringEngineError.gameAlreadyComplete
    }
    
    nonisolated func applyTiebreak(
        event: ScoreEvent,
        score: TiebreakScore,
        to state: TennisMatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> TennisMatchScoreState {
        guard case .bestOfSets(_, let setRules) = configuration.matchStructure,
              let target = setRules.tiebreakTarget,
              let winBy = setRules.tiebreakWinBy else {
            throw ScoringEngineError.invalidTiebreakConfiguration
        }
        guard let trigger = setRules.tiebreakAt,
              state.teamAGames == trigger, state.teamBGames == trigger else {
            throw ScoringEngineError.invalidTiebreakState
        }
        
        let progress = try TennisTiebreakEngine().apply(
            event: event,
            to: score,
            target: target,
            winBy: winBy
        )
        
        var updatedState = state
        switch progress {
        case .inProgress(let updatedScore):
            updatedState.setPhase = .tiebreak(updatedScore)
            return updatedState
            
        case .completed(let finalScore, _):
            updatedState.setPhase = .tiebreak(finalScore)
            updatedState = try TennisSetEngine().advanceAfterCompletedTiebreak(
                in: updatedState,
                progress: progress,
                configuration: configuration
            )
            return try TennisMatchEngine().evaluateAfterCompletedSet(
                in: updatedState,
                configuration: configuration
            )
        }
    }
    
}
