//
//  TennisSetEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated struct TennisSetEngine: Sendable {
    
    init() {}
    
    nonisolated func advanceAfterCompletedGame(
        in state: TennisMatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> TennisMatchScoreState {
        guard configuration.pointSystem == .tennis else {
            throw ScoringEngineError.incompatiblePointSystem
        }
        guard case .bestOfSets(_, let setRules) = configuration.matchStructure else {
            throw ScoringEngineError.missingSetRules
        }
        guard state.setPhase == .regularGame else {
            throw ScoringEngineError.invalidTiebreakState
        }
        guard case .game(let gameWinner) = state.currentGame else {
            throw ScoringEngineError.gameNotComplete
        }
        
        var updatedState = state
        switch gameWinner {
        case .teamA:
            updatedState.teamAGames += 1
        case .teamB:
            updatedState.teamBGames += 1
        }
        updatedState.currentGameIndex += 1
        updatedState.currentGame = .points(teamA: .love, teamB: .love)
        
        if requiresTiebreak(
            teamAGames: updatedState.teamAGames,
            teamBGames: updatedState.teamBGames,
            setRules: setRules
        ) {
            updatedState.setPhase = .tiebreakRequired
            return updatedState
        }
        
        if isSetComplete(
            teamAGames: updatedState.teamAGames,
            teamBGames: updatedState.teamBGames,
            setRules: setRules
        ) {
            updatedState.completedSets.append(
                SetScore(
                    teamAGames: updatedState.teamAGames,
                    teamBGames: updatedState.teamBGames
                )
            )
            updatedState.teamAGames = 0
            updatedState.teamBGames = 0
            updatedState.currentSetIndex += 1
            updatedState.setPhase = .regularGame
        }
        
        return updatedState
    }
    
    nonisolated func advanceAfterCompletedTiebreak(
        in state: TennisMatchScoreState,
        progress: TiebreakProgress,
        configuration: ScoringConfiguration
    ) throws -> TennisMatchScoreState {
        guard configuration.pointSystem == .tennis else {
            throw ScoringEngineError.incompatiblePointSystem
        }
        guard case .bestOfSets(_, let setRules) = configuration.matchStructure,
              let tiebreakAt = setRules.tiebreakAt,
              setRules.tiebreakTarget != nil,
              setRules.tiebreakWinBy != nil else {
            throw ScoringEngineError.invalidTiebreakConfiguration
        }
        guard case let .completed(finalScore, winner) = progress,
              case let .tiebreak(activeScore) = state.setPhase,
              activeScore == finalScore,
              state.teamAGames == tiebreakAt,
              state.teamBGames == tiebreakAt else {
            throw ScoringEngineError.invalidTiebreakState
        }
        
        let completedSet: SetScore
        switch winner {
        case .teamA:
            completedSet = SetScore(
                teamAGames: state.teamAGames + 1,
                teamBGames: state.teamBGames,
                tiebreakScore: finalScore
            )
        case .teamB:
            completedSet = SetScore(
                teamAGames: state.teamAGames,
                teamBGames: state.teamBGames + 1,
                tiebreakScore: finalScore
            )
        }
        
        var updatedState = state
        updatedState.completedSets.append(completedSet)
        updatedState.teamAGames = 0
        updatedState.teamBGames = 0
        updatedState.currentGame = .points(teamA: .love, teamB: .love)
        updatedState.currentSetIndex += 1
        updatedState.setPhase = .regularGame
        return updatedState
    }
}

private extension TennisSetEngine {
    nonisolated func requiresTiebreak(
        teamAGames: Int,
        teamBGames: Int,
        setRules: SetRules
    ) -> Bool {
        guard let tiebreakAt = setRules.tiebreakAt else {
            return false
        }
        return teamAGames == tiebreakAt && teamBGames == tiebreakAt
    }
    
    nonisolated func isSetComplete(
        teamAGames: Int,
        teamBGames: Int,
        setRules: SetRules
    ) -> Bool {
        let leadingGames = max(teamAGames, teamBGames)
        let gameLead = abs(teamAGames - teamBGames)
        return leadingGames >= setRules.gamesToWin && gameLead >= setRules.winByGames
    }
}
