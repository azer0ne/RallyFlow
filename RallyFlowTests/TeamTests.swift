//
//  TeamTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Foundation
import Testing
@testable import RallyFlow

struct TeamTests {

    @Test
    func initializerPreservesPlayerIDs() {
        let playerIDs = [UUID(), UUID()]
        let team = Team(playerIDs: playerIDs)

        #expect(team.playerIDs == playerIDs)
    }
}
