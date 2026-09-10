//
//  TennisTiebreakEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct TennisTiebreakEngine: Sendable {
    
    init() {}
    
    nonisolated func apply(
        event: ScoreEvent,
        to score: TiebreakScore,
        target: Int,
        winBy: Int
    ) throws -> TiebreakProgress {
        guard target > 0, winBy > 0 else {
            throw ScoringEngineError.invalidTiebreakConfiguration
        }
        guard score.teamAPoints >= 0, score.teamBPoints >= 0,
              score.teamAPoints < Int.max - score.teamBPoints else {
            throw ScoringEngineError.invalidTiebreakState
        }
        guard winner(
            teamAPoints: score.teamAPoints,
            teamBPoints: score.teamBPoints,
            target: target,
            winBy: winBy
        ) == nil else {
            throw ScoringEngineError.tiebreakAlreadyComplete
        }
        
        var updatedScore = score
        switch event {
        case .teamAWonRally:
            updatedScore.teamAPoints += 1
        case .teamBWonRally:
            updatedScore.teamBPoints += 1
        case .undo:
            throw ScoringEngineError.unsupportedEvent
        }
        
        if let winner = winner(
            teamAPoints: updatedScore.teamAPoints,
            teamBPoints: updatedScore.teamBPoints,
            target: target,
            winBy: winBy
        ) {
            return .completed(score: updatedScore, winner: winner)
        }
        return .inProgress(updatedScore)
    }
}

private extension TennisTiebreakEngine {
    nonisolated func winner(
        teamAPoints: Int,
        teamBPoints: Int,
        target: Int,
        winBy: Int
    ) -> TeamSide? {
        let lead = teamAPoints - teamBPoints
        if teamAPoints >= target, lead >= winBy {
            return .teamA
        }
        if teamBPoints >= target, -lead >= winBy {
            return .teamB
        }
        return nil
    }
}
