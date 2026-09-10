//
//  MatchScoringEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct MatchScoringEngine: ScoringEngine {
    func apply(event: ScoreEvent, to state: MatchScoreState,
               configuration: ScoringConfiguration) throws -> MatchScoreState {
        try engine(for: configuration).apply(event: event, to: state, configuration: configuration)
    }

    func result(for state: MatchScoreState, configuration: ScoringConfiguration) throws -> MatchResult? {
        switch configuration.pointSystem {
        case .tennis:
            if configuration.servingRule == .eachDoublesPlayerServesOnce {
                guard case .oneServeEach(let score) = state else { throw ScoringEngineError.incompatibleScoreState }
                return score.result
            }
            return try TennisMatchEngine().result(for: state)
        case .rally:
            if case .fixedTotalPoints = configuration.matchStructure {
                return try FixedTotalScoringEngine().result(for: state, configuration: configuration)
            }
            return try RallyScoringEngine().result(for: state, configuration: configuration)
        case .pickleballSideOut:
            throw ScoringEngineError.incompatiblePointSystem
        }
    }

    private func engine(for configuration: ScoringConfiguration) throws -> any ScoringEngine {
        switch configuration.pointSystem {
        case .tennis:
            if configuration.servingRule == .eachDoublesPlayerServesOnce { return OneServeEachEngine() }
            return TennisScoringEngine()
        case .rally:
            if case .fixedTotalPoints = configuration.matchStructure { return FixedTotalScoringEngine() }
            return RallyScoringEngine()
        case .pickleballSideOut:
            throw ScoringEngineError.incompatiblePointSystem
        }
    }
}
