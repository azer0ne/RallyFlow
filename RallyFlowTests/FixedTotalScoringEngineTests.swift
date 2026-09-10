//
//  FixedTotalScoringEngineTests.swift
//  RallyFlowTests
//
//  Created by Arez on 09/09/26.
//

import Testing
@testable import RallyFlow

nonisolated struct FixedTotalScoringEngineTests {
    @Test(arguments: [16, 24, 32, 7])
    func completesAtCombinedTotal(total: Int) throws {
        let configuration = try configuration(total: total)
        let engine = FixedTotalScoringEngine()
        var state = MatchScoreState.rally(RallyMatchScoreState())
        #expect(try engine.progress(for: state, configuration: configuration).pointsRemaining == total)
        for point in 0..<total {
            state = try engine.apply(event: point.isMultiple(of: 2) ? .teamAWonRally : .teamBWonRally,
                to: state, configuration: configuration)
            #expect(try engine.progress(for: state, configuration: configuration)
                == FixedTotalProgress(pointsPlayed: point + 1, pointsRemaining: total - point - 1))
            #expect((try engine.result(for: state, configuration: configuration) != nil) == (point + 1 == total))
        }
        for event in [ScoreEvent.teamAWonRally, .teamBWonRally] {
            #expect(throws: ScoringEngineError.matchAlreadyCompleted) {
                try engine.apply(event: event, to: state, configuration: configuration)
            }
        }
    }

    @Test(arguments: [0, 9, 12, 15, 20, 24])
    func finalOutcomeUsesPointComparison(teamAPoints: Int) throws {
        let configuration = try configuration(total: 24)
        let engine = FixedTotalScoringEngine()
        var state = MatchScoreState.rally(RallyMatchScoreState())
        for point in 0..<24 {
            state = try engine.apply(event: point < teamAPoints ? .teamAWonRally : .teamBWonRally,
                to: state, configuration: configuration)
        }
        let result = try #require(try engine.result(for: state, configuration: configuration))
        #expect(result.outcome == (teamAPoints == 12 ? .draw : teamAPoints > 12 ? .teamAWin : .teamBWin))
        guard case .rally(let score) = result.finalScore else { Issue.record("Expected numeric score"); return }
        #expect(score.currentGame == GameScore(teamAPoints: teamAPoints, teamBPoints: 24 - teamAPoints))
    }

    @Test
    func fifteenEightHasOnePointRemaining() throws {
        let engine = FixedTotalScoringEngine()
        let configuration = try configuration(total: 24)
        let before = MatchScoreState.rally(RallyMatchScoreState(currentGame: GameScore(teamAPoints: 15, teamBPoints: 8)))
        #expect(try engine.progress(for: before, configuration: configuration).pointsRemaining == 1)
        let after = try engine.apply(event: .teamBWonRally, to: before, configuration: configuration)
        #expect(try engine.result(for: after, configuration: configuration)?.outcome == .teamAWin)
    }

    @Test(arguments: [0, -24])
    func rejectsInvalidTotals(total: Int) {
        #expect(throws: ScoringConfigurationError.invalidTarget) { try configuration(total: total) }
    }

    @Test
    func rejectsOvershootAndIncompatibleStates() throws {
        let engine = FixedTotalScoringEngine()
        let configuration = try configuration(total: 24)
        #expect(throws: ScoringEngineError.invalidMatchState) {
            try engine.apply(event: .teamAWonRally,
                to: .rally(RallyMatchScoreState(currentGame: GameScore(teamAPoints: 20, teamBPoints: 5))),
                configuration: configuration)
        }
        #expect(throws: ScoringEngineError.incompatibleScoreState) {
            try engine.apply(event: .teamAWonRally, to: .tennis(TennisMatchScoreState()), configuration: configuration)
        }
    }

    func configuration(total: Int) throws -> ScoringConfiguration {
        try ScoringConfiguration(style: .rally, pointSystem: .rally,
            matchStructure: .fixedTotalPoints(total: total), servingRule: .standard)
    }
}
