//
//  MatchResult.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum MatchOutcome: String, Codable, Hashable, Sendable {
    case teamAWin
    case teamBWin
    case draw
}

nonisolated struct MatchResult: Codable, Hashable, Sendable {
    let outcome: MatchOutcome
    let finalScore: MatchScoreState
    
    init(outcome: MatchOutcome, finalScore: MatchScoreState) {
        self.outcome = outcome
        self.finalScore = finalScore
    }
}
