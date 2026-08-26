//
//  PlayerTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Foundation
import Testing
@testable import RallyFlow

struct PlayerTests {

    @Test
    func defaultInitializerGeneratesIDAndPreservesName() {
        let player = Player(name: "Arez")
        let zeroID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        #expect(player.id != zeroID)
        #expect(player.name == "Arez")
    }
}
