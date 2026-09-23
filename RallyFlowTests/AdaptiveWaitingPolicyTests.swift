import Testing
@testable import RallyFlow

nonisolated struct AdaptiveWaitingPolicyTests {
    @Test(arguments: [
        (eligible: 7, playersPerMatch: 4, courts: 1, capacity: 4, rests: 1),
        (eligible: 8, playersPerMatch: 4, courts: 2, capacity: 8, rests: 0),
        (eligible: 12, playersPerMatch: 4, courts: 1, capacity: 4, rests: 2),
        (eligible: 12, playersPerMatch: 4, courts: 2, capacity: 8, rests: 1),
        (eligible: 5, playersPerMatch: 2, courts: 1, capacity: 2, rests: 2)
    ])
    func thresholdTracksParticipantAndCourtCapacity(
        eligible: Int,
        playersPerMatch: Int,
        courts: Int,
        capacity: Int,
        rests: Int
    ) throws {
        let threshold = try AdaptiveWaitingPolicy().threshold(
            eligibleParticipantCount: eligible,
            playersPerMatch: playersPerMatch,
            usableCourtCount: courts
        )

        #expect(threshold.eligibleParticipantCount == eligible)
        #expect(threshold.simultaneousPlayerCapacity == capacity)
        #expect(threshold.expectedRestRounds == rests)
    }

    @Test
    func policyRejectsMissingOrInvalidCapacityInputs() {
        let policy = AdaptiveWaitingPolicy()

        #expect(throws: AdaptiveWaitingPolicyError.invalidEligibleParticipantCount(0)) {
            try policy.threshold(
                eligibleParticipantCount: 0,
                playersPerMatch: 4,
                usableCourtCount: 1
            )
        }
        #expect(throws: AdaptiveWaitingPolicyError.invalidPlayersPerMatch(0)) {
            try policy.threshold(
                eligibleParticipantCount: 7,
                playersPerMatch: 0,
                usableCourtCount: 1
            )
        }
        #expect(throws: AdaptiveWaitingPolicyError.invalidUsableCourtCount(0)) {
            try policy.threshold(
                eligibleParticipantCount: 7,
                playersPerMatch: 4,
                usableCourtCount: 0
            )
        }
    }

    @Test
    func matchmakingCapacityRejectsNonpositiveCourtCount() {
        #expect(throws: MatchmakingCapacityError.invalidUsableCourtCount(0)) {
            try MatchmakingCapacity(usableCourtCount: 0)
        }
        #expect(throws: MatchmakingCapacityError.invalidUsableCourtCount(-1)) {
            try MatchmakingCapacity(usableCourtCount: -1)
        }
    }
}
