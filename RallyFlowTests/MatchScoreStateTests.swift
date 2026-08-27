//
//  MatchScoreStateTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

struct MatchScoreStateTests {

    @Test
    func createsInitialTennisState() {
        let state = MatchScoreState.tennis(TennisMatchScoreState())

        guard case let .tennis(tennisState) = state else {
            Issue.record("Expected tennis score state")
            return
        }

        #expect(tennisState.currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState.teamAGames == 0)
        #expect(tennisState.teamBGames == 0)
        #expect(tennisState.completedSets.isEmpty)
        #expect(tennisState.currentGameIndex == 0)
        #expect(tennisState.currentSetIndex == 0)
        #expect(tennisState.setPhase == .regularGame)
        #expect(tennisState.tiebreakStartingServer == .teamA)
        #expect(!tennisState.isMatchComplete)
    }

    @Test
    func representsDeuceAndAdvantageWithoutDisplayStrings() {
        #expect(TennisGameScore.deuce == .deuce)
        #expect(TennisGameScore.advantage(.teamA) == .advantage(.teamA))
        #expect(TennisGameScore.advantage(.teamB) == .advantage(.teamB))
    }

    @Test
    func createsInitialRallyState() {
        let state = MatchScoreState.rally(RallyMatchScoreState())

        guard case let .rally(rallyState) = state else {
            Issue.record("Expected rally score state")
            return
        }

        #expect(rallyState.currentGame == GameScore())
        #expect(rallyState.completedGames.isEmpty)
        #expect(rallyState.teamAGames == 0)
        #expect(rallyState.teamBGames == 0)
        #expect(rallyState.currentGameIndex == 0)
        #expect(!rallyState.isMatchComplete)
    }
}
