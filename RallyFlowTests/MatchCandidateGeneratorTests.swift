import Foundation
import Testing
@testable import RallyFlow

nonisolated struct MatchCandidateGeneratorTests {
    @Test(arguments: [(2, 1), (3, 3), (4, 6), (5, 10)])
    func singlesCandidateCountMatchesCombinations(
        playerCount: Int,
        expectedCount: Int
    ) {
        let candidates = generatedCandidates(matchType: .singles, playerCount: playerCount)

        #expect(candidates.count == expectedCount)
        #expect(Set(candidates).count == candidates.count)
    }

    @Test
    func singlesOrderingUsesStableInputOrderWithoutMirrors() {
        let candidates = generatedCandidates(matchType: .singles, playerCount: 3)
        let pairings = candidates.map(orderedPlayerIDs)

        #expect(pairings == [[id(1), id(2)], [id(1), id(3)], [id(2), id(3)]])
    }

    @Test(arguments: [(4, 3), (5, 15), (6, 45), (7, 105), (8, 210)])
    func doublesCandidateCountMatchesCombinations(
        playerCount: Int,
        expectedCount: Int
    ) {
        let candidates = generatedCandidates(matchType: .doubles, playerCount: playerCount)

        #expect(candidates.count == expectedCount)
        #expect(Set(candidates).count == candidates.count)
    }

    @Test
    func fourPlayersProduceTheThreeCanonicalDoublesPartitions() {
        let candidates = generatedCandidates(matchType: .doubles, playerCount: 4)
        let teamPartitions = candidates.map { candidate in
            [candidate.teamA.playerIDs, candidate.teamB.playerIDs]
        }

        #expect(teamPartitions == [
            [[id(1), id(2)], [id(3), id(4)]],
            [[id(1), id(3)], [id(2), id(4)]],
            [[id(1), id(4)], [id(2), id(3)]]
        ])
    }

    @Test
    func everyDoublesCandidateContainsFourUniquePlayers() {
        let candidates = generatedCandidates(matchType: .doubles, playerCount: 8)

        for candidate in candidates {
            #expect(candidate.teamA.playerIDs.count == 2)
            #expect(candidate.teamB.playerIDs.count == 2)
            #expect(Set(candidate.playerIDs).count == 4)
        }
    }

    @Test
    func immediateGenerationIncludesOnlyReadyParticipants() {
        let statuses: [ParticipantStatus] = [
            .ready, .ready, .playing, .resting, .unavailable, .leavingSoon, .left
        ]
        let participants = statuses.enumerated().map { index, status in
            SessionParticipant(playerID: id(UInt8(index + 1)), status: status)
        }
        let request = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: participants
        )

        let candidates = MatchCandidateGenerator().candidates(for: request)

        #expect(candidates.count == 1)
        #expect(Set(candidates[0].playerIDs) == [id(1), id(2)])
    }

    @Test
    func immediateExplicitEligibilityCannotIncludeNonreadyParticipant() {
        let participants = [
            SessionParticipant(playerID: id(1), status: .ready),
            SessionParticipant(playerID: id(2), status: .playing),
            SessionParticipant(playerID: id(3), status: .ready)
        ]
        let request = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: participants,
            eligibility: .explicit(playerIDs: [id(1), id(2)])
        )

        #expect(MatchCandidateGenerator().candidates(for: request).isEmpty)
    }

    @Test
    func upcomingExplicitEligibilityCanIncludePlayingParticipant() {
        let participants = [
            SessionParticipant(playerID: id(1), status: .ready),
            SessionParticipant(playerID: id(2), status: .playing),
            SessionParticipant(playerID: id(3), status: .resting)
        ]
        let request = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .upcoming,
            participants: participants,
            eligibility: .explicit(playerIDs: [id(1), id(2)])
        )

        let candidates = MatchCandidateGenerator().candidates(for: request)

        #expect(candidates.count == 1)
        #expect(Set(candidates[0].playerIDs) == [id(1), id(2)])
    }

    @Test
    func insufficientEligiblePlayersProduceNoCandidates() {
        #expect(generatedCandidates(matchType: .singles, playerCount: 1).isEmpty)
        #expect(generatedCandidates(matchType: .doubles, playerCount: 3).isEmpty)
    }

    @Test
    func duplicateParticipantRecordsDoNotDuplicatePlayersOrCandidates() {
        let participants = [
            participant(1), participant(2), participant(2), participant(3), participant(4)
        ]
        let request = MatchmakingRequest(
            matchType: .doubles,
            schedulingContext: .immediate,
            participants: participants
        )

        let candidates = MatchCandidateGenerator().candidates(for: request)

        #expect(candidates.count == 3)
        #expect(candidates.allSatisfy { Set($0.playerIDs).count == 4 })
    }

    @Test
    func repeatedGenerationProducesTheSameOrderedCandidates() {
        let request = MatchmakingRequest(
            matchType: .doubles,
            schedulingContext: .immediate,
            participants: (1...6).map { participant(UInt8($0)) }
        )
        let generator = MatchCandidateGenerator()

        #expect(generator.candidates(for: request) == generator.candidates(for: request))
    }

    private func generatedCandidates(
        matchType: MatchType,
        playerCount: Int
    ) -> [MatchCandidate] {
        let request = MatchmakingRequest(
            matchType: matchType,
            schedulingContext: .immediate,
            participants: (1...playerCount).map { participant(UInt8($0)) }
        )
        return MatchCandidateGenerator().candidates(for: request)
    }

    private func orderedPlayerIDs(_ candidate: MatchCandidate) -> [Player.ID] {
        candidate.teamA.playerIDs + candidate.teamB.playerIDs
    }

    private func participant(_ value: UInt8) -> SessionParticipant {
        SessionParticipant(playerID: id(value))
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
