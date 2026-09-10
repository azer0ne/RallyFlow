//
//  OneServeEachEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct OneServeEachEngine: ScoringEngine {
    func apply(
        event: ScoreEvent,
        to state: MatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> MatchScoreState {
        guard configuration.pointSystem == .tennis else {
            throw ScoringEngineError.incompatiblePointSystem
        }
        guard configuration.servingRule == .eachDoublesPlayerServesOnce,
              configuration.matchStructure == .fixedGames(count: 4) else {
            throw ScoringEngineError.unsupportedMatchStructure
        }
        guard case .oneServeEach(var score) = state else {
            throw ScoringEngineError.incompatibleScoreState
        }
        guard !score.isMatchComplete else { throw ScoringEngineError.matchAlreadyCompleted }
        let winner: TeamSide
        switch event {
        case .teamAWonRally: winner = .teamA
        case .teamBWonRally: winner = .teamB
        case .undo: throw ScoringEngineError.unsupportedEvent
        }
        switch score.phase {
        case .serviceGame(let game):
            guard score.completedGames.count < 4 else { throw ScoringEngineError.invalidMatchState }
            guard let deuceRule = configuration.deuceRule else { throw ScoringEngineError.missingDeuceRule }
            let updatedGame = try TennisPointEngine().score(
                afterRallyWonBy: winner, currentScore: game, deuceRule: deuceRule
            )
            if case .game(let gameWinner) = updatedGame {
                score.completedGames.append(gameWinner)
                if score.completedGames.count < 4 {
                    score.phase = .serviceGame(.points(teamA: .love, teamB: .love))
                } else if score.teamAGames != score.teamBGames {
                    score.phase = .completed(score.teamAGames > score.teamBGames ? .teamAWin : .teamBWin, tiebreak: nil)
                } else {
                    switch configuration.tieRule {
                    case .draw?:
                        score.phase = .completed(.draw, tiebreak: nil)
                    case .tiebreak?:
                        score.phase = .tiebreak(TiebreakScore(startingServer: score.serviceOrder.players[0].side))
                    default:
                        throw ScoringEngineError.unsupportedMatchStructure
                    }
                }
            } else {
                score.phase = .serviceGame(updatedGame)
            }
        case .tiebreak(let tiebreak):
            guard score.teamAGames == 2, score.teamBGames == 2,
                  case .tiebreak(let target, let winBy)? = configuration.tieRule else {
                throw ScoringEngineError.invalidTiebreakState
            }
            switch try TennisTiebreakEngine().apply(event: event, to: tiebreak, target: target, winBy: winBy) {
            case .inProgress(let updated): score.phase = .tiebreak(updated)
            case .completed(let finalScore, let side):
                score.phase = .completed(side == .teamA ? .teamAWin : .teamBWin, tiebreak: finalScore)
            }
        case .completed:
            throw ScoringEngineError.matchAlreadyCompleted
        }
        return .oneServeEach(score)
    }
}
