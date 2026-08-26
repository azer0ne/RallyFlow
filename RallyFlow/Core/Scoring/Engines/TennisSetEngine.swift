//
//  TennisSetEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A deterministic engine for progressing games within a configured tennis set.
nonisolated struct TennisSetEngine: Sendable {
    /// Creates a stateless tennis set engine.
    init() {}

    /// Advances set state after the current game has completed.
    ///
    /// - Parameters:
    ///   - state: Tennis state whose current game contains a winner.
    ///   - configuration: A tennis configuration containing set rules.
    /// - Returns: State prepared for the next regular game, next set, or tiebreak.
    /// - Throws: ``ScoringEngineError`` when the state or configuration is incompatible.
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
            throw ScoringEngineError.tiebreakScoringRequired
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
}

private extension TennisSetEngine {
    /// Returns whether the current set score has reached its configured tiebreak score.
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

    /// Returns whether either team has won the current set.
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
