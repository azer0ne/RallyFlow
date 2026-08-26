//
//  MatchScoreStateTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

struct MatchStructureTests {

    @Test
    func representsPointRaces() {
        let raceTo11 = MatchStructure.raceToPoints(target: 11, winBy: 2, cap: nil)
        let raceTo15 = MatchStructure.raceToPoints(target: 15, winBy: 2, cap: nil)
        let raceTo21 = MatchStructure.raceToPoints(target: 21, winBy: 2, cap: nil)

        #expect(raceTo11 == .raceToPoints(target: 11, winBy: 2, cap: nil))
        #expect(raceTo15 == .raceToPoints(target: 15, winBy: 2, cap: nil))
        #expect(raceTo21 == .raceToPoints(target: 21, winBy: 2, cap: nil))
    }

    @Test
    func representsFixedGamesAndPoints() {
        #expect(MatchStructure.fixedGames(count: 4) == .fixedGames(count: 4))
        #expect(MatchStructure.fixedTotalPoints(total: 24) == .fixedTotalPoints(total: 24))
    }

    @Test
    func representsBestOfThreeGames() {
        let structure = MatchStructure.bestOfGames(
            count: 3,
            pointsPerGame: 15,
            winBy: 2,
            cap: nil
        )

        #expect(
            structure == .bestOfGames(
                count: 3,
                pointsPerGame: 15,
                winBy: 2,
                cap: nil
            )
        )
    }

    @Test
    func representsTimedMatch() {
        #expect(MatchStructure.timed(durationSeconds: 900) == .timed(durationSeconds: 900))
    }
}
