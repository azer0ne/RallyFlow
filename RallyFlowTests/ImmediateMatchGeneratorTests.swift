import Foundation
import Testing
@testable import RallyFlow

nonisolated struct ImmediateMatchGeneratorTests {
    @Test(arguments: [(MatchType.singles, 2, 1), (.singles, 3, 3),
                      (.doubles, 4, 3), (.doubles, 5, 15), (.doubles, 7, 105)])
    func returnsTopOfFullCandidatePool(type: MatchType, count: Int, expectedCount: Int) throws {
        let request = try request(type, count: count)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let expected = try #require(FairRotationCandidateRanker().rank(
            candidates: candidates, request: request
        ).first)
        let actual = try #require(try ImmediateMatchGenerator().generate(request: request))

        #expect(candidates.count == expectedCount)
        #expect(actual == expected)
        #expect(actual.reasons == expected.reasons)
        #expect(actual.warnings == expected.warnings)
    }

    @Test(arguments: [(MatchType.singles, 0), (.singles, 1),
                      (.doubles, 0), (.doubles, 1), (.doubles, 2), (.doubles, 3)])
    func insufficientReadyPlayersReturnNil(type: MatchType, count: Int) throws {
        #expect(try ImmediateMatchGenerator().generate(request: request(type, count: count)) == nil)
    }

    @Test
    func threeWaitingPlayersCannotBorrowAnActivePlayer() throws {
        let request = try request(.doubles, count: 7, statuses: [
            1: .playing, 2: .playing, 3: .playing, 4: .playing
        ], eligibility: .explicit(playerIDs: Set((1...7).map(id))))

        #expect(MatchCandidateGenerator().candidates(for: request).isEmpty)
        #expect(try ImmediateMatchGenerator().generate(request: request) == nil)
    }

    @Test(arguments: [ParticipantStatus.playing, .resting, .unavailable, .leavingSoon, .left])
    func nonreadyStatusIsExcludedEvenWhenExplicitlyEligible(_ status: ParticipantStatus) throws {
        let request = try request(.doubles, count: 5, statuses: [1: status],
                                  eligibility: .explicit(playerIDs: Set((1...5).map(id))))
        let suggestion = try #require(try ImmediateMatchGenerator().generate(request: request))

        #expect(Set(suggestion.candidate.playerIDs) == Set((2...5).map(id)))
    }

    @Test
    func explicitEligibilityCanRestrictReadyPlayers() throws {
        let request = try request(.singles, count: 3,
                                  eligibility: .explicit(playerIDs: [id(2), id(3)]))
        let suggestion = try #require(try ImmediateMatchGenerator().generate(request: request))
        #expect(Set(suggestion.candidate.playerIDs) == [id(2), id(3)])
    }

    @Test
    func completedHistoryChangesWinnerAndPreservesMetadata() throws {
        let emptyRequest = try request(.singles, count: 3)
        let original = try #require(try ImmediateMatchGenerator().generate(request: emptyRequest))
        #expect(Set(original.candidate.playerIDs) == [id(1), id(2)])

        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: original.candidate,
                              eligiblePlayerIDs: Set((1...3).map(id)))
        ])
        let request = try request(.singles, count: 3, history: history)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let expected = try #require(FairRotationCandidateRanker().rank(
            candidates: candidates, request: request
        ).first)
        let actual = try #require(try ImmediateMatchGenerator().generate(request: request))

        #expect(actual.candidate != candidates[0])
        #expect(actual.candidate != original.candidate)
        #expect(actual.candidate.contains(playerID: id(3)))
        #expect(actual == expected)
        #expect(!actual.reasons.isEmpty)
        #expect(actual.warnings.contains(.consecutivePlay))
    }

    @Test
    func sevenPlayerHistoryUsesAll105Candidates() throws {
        let completed = try MatchCandidate(matchType: .doubles,
            teamA: Team(playerIDs: [id(1), id(2)]),
            teamB: Team(playerIDs: [id(3), id(4)]))
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: completed,
                              eligiblePlayerIDs: Set((1...7).map(id)))
        ])
        let request = try request(.doubles, count: 7, history: history)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let expected = try #require(FairRotationCandidateRanker().rank(
            candidates: candidates, request: request
        ).first)
        let actual = try #require(try ImmediateMatchGenerator().generate(request: request))

        #expect(candidates.count == 105)
        #expect(actual == expected)
        #expect(Set(actual.candidate.playerIDs).isSuperset(of: [id(5), id(6), id(7)]))
    }

    @Test(arguments: [1, 2])
    func eightPlayerSmokeReturnsOneDeterministicSuggestionWithoutMutation(courts: Int) throws {
        let completed = try MatchCandidate(matchType: .doubles,
            teamA: Team(playerIDs: [id(1), id(2)]),
            teamB: Team(playerIDs: [id(3), id(4)]))
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: completed,
                              eligiblePlayerIDs: Set((1...8).map(id)))
        ])
        let request = try request(.doubles, count: 8, history: history, courts: courts)
        let original = request
        let encodedBefore = try encoded(request)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let generator = ImmediateMatchGenerator()
        let first = try #require(try generator.generate(request: request))

        #expect(candidates.count == 210)
        #expect(Set(candidates).count == 210)
        #expect(Set(first.candidate.playerIDs).count == 4)
        #expect(try generator.generate(request: request) == first)
        #expect(request == original)
        #expect(request.participants == original.participants)
        #expect(request.history == original.history)
        #expect(try encoded(request) == encodedBefore)
        #expect(request.participants.allSatisfy { $0.status == .ready && $0.matchesPlayed == 99 })
        #expect(try FairRotationCandidateRanker().rank(candidates: candidates, request: request).first == first)
    }

    @Test(arguments: [0, 4])
    func upcomingContextIsRejected(count: Int) throws {
        let request = try request(.doubles, count: count, context: .upcoming)
        #expect(throws: ImmediateMatchGenerationError.invalidSchedulingContext(.upcoming)) {
            try ImmediateMatchGenerator().generate(request: request)
        }
    }

    @Test(arguments: [0, 4])
    func missingCapacityIsInvalidEvenWithoutCandidates(count: Int) throws {
        let valid = try request(.doubles, count: count)
        let missing = MatchmakingRequest(matchType: .doubles, schedulingContext: .immediate,
                                        participants: valid.participants)
        #expect(throws: FairRotationRankingError.missingCapacity) {
            try ImmediateMatchGenerator().generate(request: missing)
        }
    }

    @Test
    func malformedCapacityCannotReachGeneration() throws {
        #expect(throws: MatchmakingCapacityError.invalidUsableCourtCount(0)) {
            try MatchmakingCapacity(usableCourtCount: 0)
        }
        let valid = try request(.doubles, count: 4)
        var object = try #require(JSONSerialization.jsonObject(with: encoded(valid)) as? [String: Any])
        object["capacity"] = ["usableCourtCount": 0]
        let malformed = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            let request = try JSONDecoder().decode(MatchmakingRequest.self, from: malformed)
            _ = try ImmediateMatchGenerator().generate(request: request)
        }
    }

    @Test
    func rankingValidationErrorsPropagate() throws {
        let valid = try request(.doubles, count: 4)
        let duplicate = MatchmakingRequest(matchType: .doubles, schedulingContext: .immediate,
            participants: valid.participants + [valid.participants[0]], capacity: valid.capacity)
        #expect(throws: FairRotationRankingError.duplicateParticipant(id(1))) {
            try ImmediateMatchGenerator().generate(request: duplicate)
        }
        let overflow = try request(.doubles, count: 4, courts: Int.max)
        #expect(throws: AdaptiveWaitingPolicyError.capacityOverflow) {
            try ImmediateMatchGenerator().generate(request: overflow)
        }
    }

    private func request(
        _ type: MatchType, count: Int, statuses: [Int: ParticipantStatus] = [:],
        eligibility: MatchmakingEligibility = .readyParticipants,
        history: ParticipantMatchHistory = ParticipantMatchHistory(),
        courts: Int = 1, context: SchedulingContext = .immediate
    ) throws -> MatchmakingRequest {
        MatchmakingRequest(matchType: type, schedulingContext: context,
            participants: (0..<count).map { index in
                SessionParticipant(playerID: id(index + 1), status: statuses[index + 1] ?? .ready,
                                   matchesPlayed: 99, consecutiveMatches: 7, consecutiveRests: 8)
            }, eligibility: eligibility, history: history,
            capacity: try MatchmakingCapacity(usableCourtCount: courts))
    }

    private func encoded(_ request: MatchmakingRequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(request)
    }

    private func id(_ value: Int) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(value)))
    }
}
