//
//  TennisScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A deterministic engine for tennis point, game, set, and match progression.
nonisolated struct TennisScoringEngine: ScoringEngine {
    /// Creates a stateless tennis scoring engine.
    init() {}

    /// Returns the tennis state produced by awarding one rally to a team.
    ///
    /// A rally that completes a regular game is passed directly to the set engine,
    /// so callers receive state prepared for the next game, set, tiebreak, or
    /// completed match.
    ///
    /// - Parameters:
    ///   - event: The rally-winning event to process.
    ///   - state: The tennis score state before the event.
    ///   - configuration: A tennis configuration containing a deuce rule.
    /// - Returns: A new score state with the event applied.
    /// - Throws: ``ScoringEngineError`` when the inputs are incompatible or unsupported.
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
    /// Applies one rally using regular tennis-game point notation.
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
            updatedState.currentGame = try score(
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

    /// Applies one rally to a required or active tiebreak.
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

    /// Returns the game score after one team wins a rally.
    nonisolated func score(
        afterRallyWonBy rallyWinner: TeamSide,
        currentScore: TennisGameScore,
        deuceRule: DeuceRule
    ) throws -> TennisGameScore {
        switch currentScore {
        case let .points(teamAPoint, teamBPoint):
            return scoreFromPoints(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                rallyWinner: rallyWinner,
                deuceRule: deuceRule
            )

        case .deuce:
            switch deuceRule {
            case .advantage:
                return .advantage(rallyWinner)
            case .noAd:
                return .game(rallyWinner)
            }

        case .advantage(let advantageSide):
            if advantageSide == rallyWinner {
                return .game(rallyWinner)
            }
            return .deuce

        case .game:
            throw ScoringEngineError.gameAlreadyComplete
        }
    }

    /// Returns the score after a rally from ordinary tennis point values.
    nonisolated func scoreFromPoints(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        rallyWinner: TeamSide,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch rallyWinner {
        case .teamA:
            return scoreAfterTeamAWins(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                deuceRule: deuceRule
            )
        case .teamB:
            return scoreAfterTeamBWins(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                deuceRule: deuceRule
            )
        }
    }

    /// Returns the score after Team A wins from ordinary point values.
    nonisolated func scoreAfterTeamAWins(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch teamAPoint {
        case .love:
            return .points(teamA: .fifteen, teamB: teamBPoint)
        case .fifteen:
            return .points(teamA: .thirty, teamB: teamBPoint)
        case .thirty:
            if teamBPoint == .forty {
                return .deuce
            }
            return .points(teamA: .forty, teamB: teamBPoint)
        case .forty:
            if teamBPoint == .forty {
                return deuceRule == .advantage ? .advantage(.teamA) : .game(.teamA)
            }
            return .game(.teamA)
        }
    }

    /// Returns the score after Team B wins from ordinary point values.
    nonisolated func scoreAfterTeamBWins(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch teamBPoint {
        case .love:
            return .points(teamA: teamAPoint, teamB: .fifteen)
        case .fifteen:
            return .points(teamA: teamAPoint, teamB: .thirty)
        case .thirty:
            if teamAPoint == .forty {
                return .deuce
            }
            return .points(teamA: teamAPoint, teamB: .forty)
        case .forty:
            if teamAPoint == .forty {
                return deuceRule == .advantage ? .advantage(.teamB) : .game(.teamB)
            }
            return .game(.teamB)
        }
    }
}
