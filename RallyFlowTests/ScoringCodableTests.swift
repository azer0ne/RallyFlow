//
//  ScoringCodableTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Foundation
import Testing
@testable import RallyFlow

struct ScoringCodableTests {

    @Test
    func roundTripsScoringConfiguration() throws {
        let original = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 1,
                setRules: SetRules(
                    gamesToWin: 6,
                    winByGames: 2,
                    tiebreakAt: 6,
                    tiebreakTarget: 7,
                    tiebreakWinBy: 2
                )
            ),
            deuceRule: .advantage,
            tieRule: .tiebreak(target: 7, winBy: 2),
            servingRule: .standard
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScoringConfiguration.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func roundTripsTennisScoreState() throws {
        let original = MatchScoreState.tennis(
            TennisMatchScoreState(
                currentGame: .advantage(.teamB),
                teamAGames: 4,
                teamBGames: 5,
                completedSets: [SetScore(teamAGames: 6, teamBGames: 3)],
                currentGameIndex: 9,
                currentSetIndex: 1
            )
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatchScoreState.self, from: data)

        #expect(decoded == original)
    }
}
