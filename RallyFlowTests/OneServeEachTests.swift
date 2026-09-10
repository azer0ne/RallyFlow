//
//  OneServeEachTests.swift
//  RallyFlowTests
//
//  Created by Arez on 09/09/26.
//

import Foundation
import Testing
@testable import RallyFlow

nonisolated struct OneServeEachTests {
    @Test(arguments: [TeamSide.teamA, .teamB])
    func allFourPlayersServeOnce(startingSide: TeamSide) throws {
        var state = try initial(startingSide: startingSide)
        let expected = state.serviceOrder.players
        for index in 0..<4 {
            #expect(state.currentGameNumber == index + 1)
            #expect(state.currentServer == expected[index])
            #expect(state.nextServer == (index < 3 ? expected[index + 1] : nil))
            state = try winGame(.teamAWonRally, in: state)
        }
        #expect(state.currentServer == nil)
        #expect(state.nextServer == nil)
        #expect(state.currentGameNumber == nil)
        #expect(state.isMatchComplete)
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func fourGamesDetermineOutcome(teamAWins: Int) throws {
        var state = try initial()
        for index in 0..<4 {
            state = try winGame(index < teamAWins ? .teamAWonRally : .teamBWonRally, in: state)
        }
        #expect(state.teamAGames == teamAWins)
        #expect(state.teamBGames == 4 - teamAWins)
        #expect(state.result?.outcome == (teamAWins == 2 ? .draw : teamAWins > 2 ? .teamAWin : .teamBWin))
        for event in [ScoreEvent.teamAWonRally, .teamBWonRally] {
            #expect(throws: ScoringEngineError.matchAlreadyCompleted) {
                try apply(event, to: state)
            }
        }
    }

    @Test(arguments: [ScoreEvent.teamAWonRally, .teamBWonRally])
    func decidingTiebreakPreservesResult(event: ScoreEvent) throws {
        let configuration = try configuration(tieRule: .tiebreak(target: 10, winBy: 2))
        var state = try initial()
        for rally in [ScoreEvent.teamAWonRally, .teamBWonRally, .teamAWonRally, .teamBWonRally] {
            state = try winGame(rally, in: state, configuration: configuration)
        }
        #expect(!state.isMatchComplete)
        #expect(state.currentServer == nil)
        for _ in 0..<10 { state = try apply(event, to: state, configuration: configuration) }
        #expect(state.completedGames.count == 4)
        guard case .completed(let outcome, let detail) = state.phase else {
            Issue.record("Expected match-deciding tiebreak result"); return
        }
        #expect(outcome == (event == .teamAWonRally ? .teamAWin : .teamBWin))
        #expect(detail?.teamAPoints == (event == .teamAWonRally ? 10 : 0))
        #expect(detail?.teamBPoints == (event == .teamBWonRally ? 10 : 0))
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(OneServeEachScoreState.self, from: data) == state)
    }

    @Test(arguments: [DeuceRule.advantage, .noAd])
    func usesConfiguredDeuceRule(rule: DeuceRule) throws {
        let configuration = try configuration(deuceRule: rule)
        var state = try initial()
        state.phase = .serviceGame(.deuce)
        state = try apply(.teamAWonRally, to: state, configuration: configuration)
        if rule == .advantage {
            #expect(state.phase == .serviceGame(.advantage(.teamA)))
            state = try apply(.teamAWonRally, to: state, configuration: configuration)
        }
        #expect(state.completedGames == [.teamA])
        #expect(state.currentServer == state.serviceOrder.players[1])
        #expect(state.phase == .serviceGame(.points(teamA: .love, teamB: .love)))
    }

    @Test
    func rejectsInvalidOrdersIncludingDecodedDuplicates() throws {
        let players = try initial().serviceOrder.players
        for invalid in [Array(players.prefix(3)), [players[0], players[1], players[0], players[3]],
                        [players[0], players[2], players[1], players[3]]] {
            #expect(throws: ScoringConfigurationError.invalidServiceOrder) {
                try DoublesServiceOrder(players: invalid)
            }
        }
        let data = try JSONEncoder().encode(["players": [players[0], players[1], players[0], players[3]]])
        #expect(throws: ScoringConfigurationError.invalidServiceOrder) {
            try JSONDecoder().decode(DoublesServiceOrder.self, from: data)
        }
    }

    @Test
    func rejectsUnsupportedTieRulesAndStructures() {
        for tieRule in [TieRule.decidingGame, .continueUntilLead(by: 2)] {
            #expect(throws: ScoringConfigurationError.invalidOneServeEachRules) {
                try configuration(tieRule: tieRule)
            }
        }
        #expect(throws: ScoringConfigurationError.invalidOneServeEachRules) {
            try ScoringConfiguration(style: .tennis, pointSystem: .tennis,
                matchStructure: .fixedGames(count: 5), deuceRule: .noAd,
                tieRule: .draw, servingRule: .eachDoublesPlayerServesOnce)
        }
    }

    func initial(startingSide: TeamSide = .teamA) throws -> OneServeEachScoreState {
        let opposite: TeamSide = startingSide == .teamA ? .teamB : .teamA
        let order = try DoublesServiceOrder(players: [startingSide, opposite, startingSide, opposite].map {
            ServicePlayer(playerID: UUID(), side: $0)
        })
        return OneServeEachScoreState(serviceOrder: order)
    }

    func configuration(deuceRule: DeuceRule = .noAd, tieRule: TieRule = .draw) throws -> ScoringConfiguration {
        try ScoringConfiguration(style: .tennis, pointSystem: .tennis,
            matchStructure: .fixedGames(count: 4), deuceRule: deuceRule,
            tieRule: tieRule, servingRule: .eachDoublesPlayerServesOnce)
    }

    func apply(_ event: ScoreEvent, to state: OneServeEachScoreState,
               configuration: ScoringConfiguration? = nil) throws -> OneServeEachScoreState {
        let updated = try OneServeEachEngine().apply(event: event, to: .oneServeEach(state),
            configuration: configuration ?? self.configuration())
        guard case .oneServeEach(let result) = updated else { throw ScoringEngineError.incompatibleScoreState }
        return result
    }

    func winGame(_ event: ScoreEvent, in state: OneServeEachScoreState,
                 configuration: ScoringConfiguration? = nil) throws -> OneServeEachScoreState {
        var updated = state
        for _ in 0..<4 { updated = try apply(event, to: updated, configuration: configuration) }
        return updated
    }
}
