//
//  M2AuditTests.swift
//  RallyFlowTests
//
//  Created by Arez on 10/09/26.
//

import Foundation
import Testing
@testable import RallyFlow

nonisolated struct M2AuditTests {
    enum Scenario: CaseIterable, Sendable {
        case traditional, oneServeDraw, oneServeTiebreak, rally, fixedTotal
    }

    @Test(arguments: Scenario.allCases)
    func headlessMVPScenarioSupportsResultReplayAndUndo(scenario: Scenario) throws {
        let fixture = try fixture(scenario)
        var history = ScoringHistory(initialState: fixture.state, configuration: fixture.configuration)
        var beforeFinal = history.state
        for event in fixture.events {
            beforeFinal = history.state
            try history.apply(event: event)
        }
        let result = try #require(try MatchScoringEngine().result(for: history.state, configuration: history.configuration))
        #expect(result.outcome == fixture.outcome)
        let encoded = try JSONEncoder().encode(result)
        #expect(try JSONDecoder().decode(MatchResult.self, from: encoded) == result)
        #expect(try history.replayedState() == history.state)
        switch scenario {
        case .traditional:
            guard case .tennis(let score) = history.state else { Issue.record("Expected tennis"); return }
            #expect(score.completedSets.map { [$0.teamAGames, $0.teamBGames] } == [[7, 6], [0, 6], [6, 0]])
            #expect(score.completedSets[0].tiebreakScore?.teamAPoints == 9)
            #expect(score.completedSets[0].tiebreakScore?.teamBPoints == 7)
        case .fixedTotal:
            guard case .rally(let score) = history.state else { Issue.record("Expected numeric score"); return }
            #expect(score.currentGame == GameScore(teamAPoints: 15, teamBPoints: 9))
        default: break
        }
        try history.apply(event: .undo)
        #expect(history.state == beforeFinal)
        #expect(try history.replayedState() == history.state)
        #expect(try MatchScoringEngine().result(for: history.state, configuration: history.configuration) == nil)
    }

    @Test
    func unsupportedTennisStructureFailsOnFirstRally() throws {
        let configuration = try ScoringConfiguration(style: .tennis, pointSystem: .tennis,
            matchStructure: .fixedGames(count: 4), deuceRule: .noAd, tieRule: .draw, servingRule: .standard)
        #expect(throws: ScoringEngineError.missingSetRules) {
            try TennisScoringEngine().apply(event: .teamAWonRally,
                to: .tennis(TennisMatchScoreState()), configuration: configuration)
        }
    }

    @Test
    func inconsistentTiebreakPhaseFailsBeforeScoring() throws {
        let configuration = try fixture(.traditional).configuration
        let state = TennisMatchScoreState(teamAGames: 5, teamBGames: 6, setPhase: .tiebreakRequired)
        #expect(throws: ScoringEngineError.invalidTiebreakState) {
            try TennisScoringEngine().apply(event: .teamAWonRally, to: .tennis(state), configuration: configuration)
        }
    }

    @Test
    func negativeTiebreakPointsFailPredictably() {
        #expect(throws: ScoringEngineError.invalidTiebreakState) {
            try TennisTiebreakEngine().apply(event: .teamAWonRally,
                to: TiebreakScore(teamAPoints: -1, startingServer: .teamA), target: 7, winBy: 2)
        }
    }

    @Test
    func invalidNumericAndIncompleteTiebreakRulesFailEarly() {
        let invalid: [MatchStructure] = [
            .raceToPoints(target: 11, winBy: 0, cap: nil),
            .raceToPoints(target: 11, winBy: 2, cap: -1),
            .bestOfSets(count: 3, setRules: SetRules(gamesToWin: 6, winByGames: 2, tiebreakAt: 6, tiebreakTarget: 7))
        ]
        for structure in invalid {
            #expect(throws: ScoringConfigurationError.self) {
                try ScoringConfiguration(style: .rally, pointSystem: .rally,
                    matchStructure: structure, servingRule: .standard)
            }
        }
    }

    @Test
    func decodingCannotBypassBestOfValidation() throws {
        let configuration = try fixture(.traditional).configuration
        let data = try JSONEncoder().encode(configuration)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var structure = try #require(object["matchStructure"] as? [String: Any])
        var sets = try #require(structure["bestOfSets"] as? [String: Any])
        sets["count"] = 2
        structure["bestOfSets"] = sets
        object["matchStructure"] = structure
        let invalid = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ScoringConfiguration.self, from: invalid) }
    }

    private func fixture(_ scenario: Scenario) throws -> (
        state: MatchScoreState, configuration: ScoringConfiguration, events: [ScoreEvent], outcome: MatchOutcome
    ) {
        switch scenario {
        case .traditional:
            let configuration = try ScoringConfiguration(style: .tennis, pointSystem: .tennis,
                matchStructure: .bestOfSets(count: 3, setRules: SetRules(gamesToWin: 6, winByGames: 2,
                    tiebreakAt: 6, tiebreakTarget: 7, tiebreakWinBy: 2)),
                deuceRule: .advantage, servingRule: .standard)
            var events: [ScoreEvent] = []
            for _ in 0..<6 {
                events += Array(repeating: .teamAWonRally, count: 4)
                events += Array(repeating: .teamBWonRally, count: 4)
            }
            for _ in 0..<7 { events += [.teamAWonRally, .teamBWonRally] }
            events += [.teamAWonRally, .teamAWonRally]
            events += Array(repeating: .teamBWonRally, count: 24)
            events += Array(repeating: .teamAWonRally, count: 24)
            return (.tennis(TennisMatchScoreState()), configuration, events, .teamAWin)
        case .oneServeDraw, .oneServeTiebreak:
            let deciding = scenario == .oneServeTiebreak
            let configuration = try OneServeEachTests().configuration(deuceRule: deciding ? .advantage : .noAd,
                tieRule: deciding ? .tiebreak(target: 7, winBy: 2) : .draw)
            var events: [ScoreEvent] = []
            for event in [ScoreEvent.teamAWonRally, .teamBWonRally, .teamAWonRally, .teamBWonRally] {
                events += Array(repeating: event, count: 4)
            }
            if deciding { events += Array(repeating: .teamBWonRally, count: 7) }
            return (.oneServeEach(try OneServeEachTests().initial()), configuration, events, deciding ? .teamBWin : .draw)
        case .rally:
            var events: [ScoreEvent] = []
            for _ in 0..<20 { events += [.teamAWonRally, .teamBWonRally] }
            events += [.teamBWonRally, .teamBWonRally]
            return (.rally(RallyMatchScoreState()), try RallyScoringEngineTests().configuration(), events, .teamBWin)
        case .fixedTotal:
            let events = Array(repeating: ScoreEvent.teamAWonRally, count: 15) + Array(repeating: ScoreEvent.teamBWonRally, count: 9)
            return (.rally(RallyMatchScoreState()), try FixedTotalScoringEngineTests().configuration(total: 24), events, .teamAWin)
        }
    }
}
