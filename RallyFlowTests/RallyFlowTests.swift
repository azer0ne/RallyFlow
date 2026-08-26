//
//  RallyFlowTests.swift
//  RallyFlowTests
//
//  Created by Arez on 22/08/26.
//

import Testing
@testable import RallyFlow

struct MatchTypeTests {

    @Test
    func singlesRequiresTwoPlayers() {
        #expect(MatchType.singles.playersPerMatch == 2)
        #expect(MatchType.singles.playersPerTeam == 1)
    }

    @Test
    func doublesRequiresFourPlayers() {
        #expect(MatchType.doubles.playersPerMatch == 4)
        #expect(MatchType.doubles.playersPerTeam == 2)
    }
}
