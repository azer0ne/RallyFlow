//
//  TennisScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A deterministic engine for tennis point, game, and set progression.
nonisolated struct TennisScoringEngine: ScoringEngine {
    /// Creates a stateless tennis scoring engine.
    init() {}

    /// Returns the tennis state produced by awarding one rally to a team.
    ///
    /// A rally that completes a regular game is passed directly to the set engine,
    /// so callers receive state prepared for the next game, set, or tiebreak.
    /// Overall match completion remains unchanged.
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
        guard case .tennis(var tennisState) = state else {
            throw ScoringEngineError.incompatibleScoreState
        }
        guard tennisState.setPhase == .regularGame else {
            throw ScoringEngineError.tiebreakScoringRequired
        }
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

        guard case .game = tennisState.currentGame else {
            let updatedGame = try score(
                afterRallyWonBy: rallyWinner,
                currentScore: tennisState.currentGame,
                deuceRule: deuceRule
            )
            tennisState.currentGame = updatedGame

            if case .game = updatedGame {
                tennisState = try TennisSetEngine().advanceAfterCompletedGame(
                    in: tennisState,
                    configuration: configuration
                )
            }

            return .tennis(tennisState)
        }

        throw ScoringEngineError.gameAlreadyComplete
    }
}

private extension TennisScoringEngine {
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
