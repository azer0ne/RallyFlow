//
//  SessionParticipantTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Foundation
import Testing
@testable import RallyFlow

struct SessionParticipantTests {

    @Test
    func initializerUsesSchedulingDefaults() {
        let playerID = UUID()
        let participant = SessionParticipant(playerID: playerID)

        #expect(participant.playerID == playerID)
        #expect(participant.status == .ready)
        #expect(participant.matchesPlayed == 0)
        #expect(participant.consecutiveMatches == 0)
        #expect(participant.consecutiveRests == 0)
    }
}
