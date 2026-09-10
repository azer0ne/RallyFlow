//
//  ScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated protocol ScoringEngine: Sendable {
    func apply(
        event: ScoreEvent,
        to state: MatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> MatchScoreState
}
