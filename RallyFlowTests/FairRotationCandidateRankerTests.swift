import Foundation
import Testing
@testable import RallyFlow

nonisolated struct FairRotationCandidateRankerTests {
    @Test
    func emptyCandidatesReturnEmptyWithoutCapacity() throws {
        let request = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: []
        )

        #expect(try FairRotationCandidateRanker().rank(candidates: [], request: request).isEmpty)
    }

    @Test
    func oneValidCandidateIsReturnedUnchanged() throws {
        let candidate = try singles(1, 2)
        let suggestions = try rank(
            [candidate],
            request: request(.singles, players: [1, 2])
        )

        #expect(suggestions.count == 1)
        #expect(suggestions[0].candidate == candidate)
    }

    @Test
    func equivalentCandidatesAppearOnlyOnce() throws {
        let candidate = try doubles([1, 2], [3, 4])
        let mirrored = try doubles([4, 3], [2, 1])

        let suggestions = try rank(
            [mirrored, candidate, mirrored],
            request: request(.doubles, players: [1, 2, 3, 4])
        )

        #expect(suggestions.count == 1)
        #expect(suggestions[0].candidate == candidate)
    }

    @Test
    func malformedRankingInputsFailPredictably() throws {
        let validSingles = try singles(1, 2)
        let noCapacity = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: participants([1, 2])
        )
        #expect(throws: FairRotationRankingError.missingCapacity) {
            try rank([validSingles], request: noCapacity)
        }

        let emptyPool = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: [],
            capacity: try MatchmakingCapacity(usableCourtCount: 1)
        )
        #expect(throws: FairRotationRankingError.emptyEligibleParticipantPool) {
            try rank([validSingles], request: emptyPool)
        }

        let duplicates = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: .immediate,
            participants: [participant(1), participant(1), participant(2)],
            capacity: try MatchmakingCapacity(usableCourtCount: 1)
        )
        #expect(throws: FairRotationRankingError.duplicateParticipant(id(1))) {
            try rank([validSingles], request: duplicates)
        }

        #expect(throws: FairRotationRankingError.candidateMatchTypeMismatch(
            expected: .singles,
            actual: .doubles
        )) {
            try rank(
                [try doubles([1, 2], [3, 4])],
                request: request(.singles, players: [1, 2, 3, 4])
            )
        }

        #expect(throws: FairRotationRankingError.unknownParticipant(id(9))) {
            try rank(
                [try singles(1, 9)],
                request: request(.singles, players: [1, 2])
            )
        }

        let unavailableRequest = try request(
            .singles,
            players: [1, 2],
            statuses: [2: .unavailable]
        )
        #expect(throws: FairRotationRankingError.ineligibleParticipant(id(2))) {
            try rank([validSingles], request: unavailableRequest)
        }
    }

    @Test
    func singlesRankingFavorsPlayerWithFewerCompletedMatches() throws {
        let history = try ParticipantMatchHistory(entries: [singlesEntry(0, 2, 3)])
        let lowerCountCandidate = try singles(1, 3)
        let higherCountCandidate = try singles(2, 3)

        let suggestions = try rank(
            [higherCountCandidate, lowerCountCandidate],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == lowerCountCandidate)
        #expect(suggestions[0].reasons.contains(.fewerMatchesPlayed))
    }

    @Test
    func doublesRankingFavorsPlayerWithFewerCompletedMatches() throws {
        let history = try ParticipantMatchHistory(entries: [
            doublesEntry(0, [2, 3], [4, 5])
        ])
        let lowerCountCandidate = try doubles([1, 3], [4, 5])
        let higherCountCandidate = try doubles([2, 3], [4, 5])

        let suggestions = try rank(
            [higherCountCandidate, lowerCountCandidate],
            request: request(.doubles, players: [1, 2, 3, 4, 5], history: history)
        )

        #expect(suggestions[0].candidate == lowerCountCandidate)
    }

    @Test
    func longerEligibleWaitIsPreferredWhenMatchCountsAreEqual() throws {
        let history = try ParticipantMatchHistory(entries: [
            singlesEntry(0, 8, 9, eligible: [1, 8, 9])
        ])
        let longerWaitingCandidate = try singles(1, 3)
        let otherCandidate = try singles(2, 3)

        let suggestions = try rank(
            [otherCandidate, longerWaitingCandidate],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == longerWaitingCandidate)
        #expect(suggestions[0].reasons.contains(.longerWaiting))
        #expect(suggestions[0].reasons.contains(.avoidsConsecutiveRest))
    }

    @Test
    func voluntaryAbsenceDoesNotCreateWaitingPriority() throws {
        let history = try ParticipantMatchHistory(entries: [
            singlesEntry(0, 8, 9, eligible: [1, 8, 9])
        ])

        #expect(history.statistics(for: id(1)).consecutiveRests == 1)
        #expect(history.statistics(for: id(2)).consecutiveRests == 0)

        let suggestions = try rank(
            [try singles(2, 3), try singles(1, 3)],
            request: request(.singles, players: [1, 2, 3], history: history)
        )
        #expect(suggestions[0].candidate.contains(playerID: id(1)))
    }

    @Test
    func severeWaitingCanOutweighOneMatchCountAdvantage() throws {
        let history = try ParticipantMatchHistory(entries: [
            singlesEntry(0, 2, 3),
            singlesEntry(1, 8, 9, eligible: [2, 8, 9]),
            singlesEntry(2, 8, 9, eligible: [2, 8, 9]),
            singlesEntry(3, 8, 9, eligible: [2, 8, 9])
        ])
        let improvesMatchBalance = try singles(1, 3)
        let preventsSevereWait = try singles(2, 3)

        let suggestions = try rank(
            [improvesMatchBalance, preventsSevereWait],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == preventsSevereWait)
        #expect(suggestions[0].reasons.contains(.longerWaiting))
    }

    @Test
    func severeMatchDeficitCanOutweighMinorWaitingExcess() throws {
        let history = try ParticipantMatchHistory(entries: [
            singlesEntry(0, 2, 3),
            singlesEntry(1, 2, 3),
            singlesEntry(2, 2, 3),
            singlesEntry(3, 1, 9, eligible: [1, 2, 9])
        ])
        let reducesMatchDeficit = try singles(1, 3)
        let preventsMinorWait = try singles(2, 3)

        let suggestions = try rank(
            [preventsMinorWait, reducesMatchDeficit],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == reducesMatchDeficit)
        #expect(suggestions[0].warnings.contains(.consecutivePlay))
    }

    @Test
    func consecutivePlayIsASoftTieBreaker() throws {
        let history = try ParticipantMatchHistory(entries: [
            singlesEntry(0, 2, 8),
            singlesEntry(1, 1, 9)
        ])
        let consecutiveCandidate = try singles(1, 3)
        let restedCandidate = try singles(2, 3)

        let suggestions = try rank(
            [consecutiveCandidate, restedCandidate],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == restedCandidate)
        #expect(suggestions[0].reasons.contains(.avoidsExcessiveConsecutivePlay))
        let repeatedSuggestion = try #require(
            suggestions.first { $0.candidate == consecutiveCandidate }
        )
        #expect(repeatedSuggestion.warnings.contains(.consecutivePlay))
    }

    @Test
    func newDoublesPartnershipBeatsRepeatedPartnershipAfterPrimaryTie() throws {
        let history = try ParticipantMatchHistory(entries: [
            doublesEntry(0, [1, 2], [3, 4])
        ])
        let repeated = try doubles([1, 2], [3, 4])
        let fresh = try doubles([1, 3], [2, 4])

        let suggestions = try rank(
            [repeated, fresh],
            request: request(.doubles, players: [1, 2, 3, 4], history: history)
        )

        #expect(suggestions[0].candidate == fresh)
        #expect(suggestions[0].reasons.contains(.newPartnerCombination))
        #expect(!suggestions[0].warnings.contains(.repeatedPartner))
        let repeatedSuggestion = try #require(suggestions.first { $0.candidate == repeated })
        #expect(repeatedSuggestion.warnings.contains(.repeatedPartner))
    }

    @Test
    func fewerRepeatedOpponentsBreaksEqualPartnershipTie() throws {
        let history = try ParticipantMatchHistory(entries: [singlesEntry(0, 1, 3)])
        let repeatedOpponents = try doubles([1, 2], [3, 4])
        let freshOpponents = try doubles([1, 3], [2, 4])

        let suggestions = try rank(
            [repeatedOpponents, freshOpponents],
            request: request(.doubles, players: [1, 2, 3, 4], history: history)
        )

        #expect(suggestions[0].candidate == freshOpponents)
        #expect(suggestions[0].reasons.contains(.reducedOpponentRepetition))
        let repeatedSuggestion = try #require(
            suggestions.first { $0.candidate == repeatedOpponents }
        )
        #expect(repeatedSuggestion.warnings.contains(.repeatedOpponent))
    }

    @Test
    func singlesIgnoreHistoricalPartnershipsButUseOpponentHistory() throws {
        let history = try ParticipantMatchHistory(entries: [
            doublesEntry(0, [1, 2], [3, 4])
        ])
        let formerPartners = try singles(1, 2)
        let formerOpponents = try singles(1, 3)

        let suggestions = try rank(
            [formerOpponents, formerPartners],
            request: request(.singles, players: [1, 2, 3], history: history)
        )

        #expect(suggestions[0].candidate == formerPartners)
        #expect(!suggestions[0].reasons.contains(.newPartnerCombination))
        #expect(!suggestions[0].reasons.contains(.reducedPartnerRepetition))
        #expect(!suggestions[0].warnings.contains(.repeatedPartner))
    }

    @Test
    func upcomingRankingAcceptsExplicitlyEligiblePlayingParticipant() throws {
        let statuses: [UInt8: ParticipantStatus] = [
            1: .playing, 2: .playing, 3: .playing, 4: .playing
        ]
        let futureCandidate = try doubles([5, 6], [7, 1])
        let upcomingRequest = try request(
            .doubles,
            players: [1, 2, 3, 4, 5, 6, 7],
            schedulingContext: .upcoming,
            statuses: statuses,
            explicitEligibility: [1, 2, 3, 4, 5, 6, 7]
        )

        let suggestions = try rank([futureCandidate], request: upcomingRequest)

        #expect(suggestions.count == 1)
        #expect(suggestions[0].candidate == futureCandidate)
        #expect(suggestions[0].warnings.contains(.consecutivePlay))
    }

    @Test
    func rankingIsIndependentOfCandidateEnumerationOrder() throws {
        let rankingRequest = try request(.doubles, players: [1, 2, 3, 4, 5, 6])
        let candidates = MatchCandidateGenerator().candidates(for: rankingRequest)
        let ranker = FairRotationCandidateRanker()

        let forward = try ranker.rank(candidates: candidates, request: rankingRequest)
        let reversed = try ranker.rank(candidates: candidates.reversed(), request: rankingRequest)

        #expect(forward == reversed)
        #expect(try ranker.rank(candidates: candidates, request: rankingRequest) == forward)
    }

    @Test
    func rankingDoesNotMutateHistoryParticipantsOrCandidates() throws {
        let history = try ParticipantMatchHistory(entries: [
            doublesEntry(0, [1, 2], [3, 4], eligible: [1, 2, 3, 4, 5])
        ])
        let rankingRequest = try request(
            .doubles,
            players: [1, 2, 3, 4, 5],
            history: history
        )
        let candidates = MatchCandidateGenerator().candidates(for: rankingRequest)
        let originalHistory = rankingRequest.history
        let originalParticipants = rankingRequest.participants
        let originalCandidates = candidates

        _ = try rank(candidates, request: rankingRequest)

        #expect(rankingRequest.history == originalHistory)
        #expect(rankingRequest.participants == originalParticipants)
        #expect(candidates == originalCandidates)
    }

    @Test
    func realisticDoublesCollectionRanksEveryUniqueCandidate() throws {
        let rankingRequest = try request(.doubles, players: Array(1...8))
        let candidates = MatchCandidateGenerator().candidates(for: rankingRequest)
        let ranker = FairRotationCandidateRanker()

        let first = try ranker.rank(candidates: candidates, request: rankingRequest)
        let second = try ranker.rank(candidates: candidates, request: rankingRequest)

        #expect(first.count == 210)
        #expect(Set(first.map(\.candidate)).count == 210)
        #expect(first == second)
    }

    @Test
    func capacityRoundTripsThroughCodableWithRequest() throws {
        let value = try request(.singles, players: [1, 2], courts: 2)
        let data = try JSONEncoder().encode(value)

        let decoded = try JSONDecoder().decode(MatchmakingRequest.self, from: data)

        #expect(decoded == value)
        #expect(decoded.capacity?.usableCourtCount == 2)
    }
}

nonisolated private extension FairRotationCandidateRankerTests {
    func rank(
        _ candidates: [MatchCandidate],
        request: MatchmakingRequest
    ) throws -> [MatchSuggestion] {
        try FairRotationCandidateRanker().rank(candidates: candidates, request: request)
    }

    func request(
        _ matchType: MatchType,
        players: [UInt8],
        history: ParticipantMatchHistory = ParticipantMatchHistory(),
        schedulingContext: SchedulingContext = .immediate,
        statuses: [UInt8: ParticipantStatus] = [:],
        explicitEligibility: [UInt8]? = nil,
        courts: Int = 1
    ) throws -> MatchmakingRequest {
        MatchmakingRequest(
            matchType: matchType,
            schedulingContext: schedulingContext,
            participants: players.map {
                participant($0, status: statuses[$0] ?? .ready)
            },
            eligibility: explicitEligibility.map {
                .explicit(playerIDs: Set($0.map(id)))
            } ?? .readyParticipants,
            history: history,
            capacity: try MatchmakingCapacity(usableCourtCount: courts)
        )
    }

    func participants(_ values: [UInt8]) -> [SessionParticipant] {
        values.map { participant($0) }
    }

    func participant(
        _ value: UInt8,
        status: ParticipantStatus = .ready
    ) -> SessionParticipant {
        SessionParticipant(
            id: id(value &+ 100),
            playerID: id(value),
            status: status
        )
    }

    func singlesEntry(
        _ sequence: Int,
        _ first: UInt8,
        _ second: UInt8,
        eligible: [UInt8]? = nil
    ) throws -> MatchHistoryEntry {
        try MatchHistoryEntry(
            sequence: sequence,
            candidate: singles(first, second),
            eligiblePlayerIDs: eligible.map { Set($0.map(id)) }
        )
    }

    func doublesEntry(
        _ sequence: Int,
        _ teamA: [UInt8],
        _ teamB: [UInt8],
        eligible: [UInt8]? = nil
    ) throws -> MatchHistoryEntry {
        try MatchHistoryEntry(
            sequence: sequence,
            candidate: doubles(teamA, teamB),
            eligiblePlayerIDs: eligible.map { Set($0.map(id)) }
        )
    }

    func singles(_ first: UInt8, _ second: UInt8) throws -> MatchCandidate {
        try MatchCandidate(
            matchType: .singles,
            teamA: Team(id: id(first &+ 150), playerIDs: [id(first)]),
            teamB: Team(id: id(second &+ 150), playerIDs: [id(second)])
        )
    }

    func doubles(_ teamA: [UInt8], _ teamB: [UInt8]) throws -> MatchCandidate {
        try MatchCandidate(
            matchType: .doubles,
            teamA: Team(id: teamID(teamA), playerIDs: teamA.map(id)),
            teamB: Team(id: teamID(teamB), playerIDs: teamB.map(id))
        )
    }

    func teamID(_ values: [UInt8]) -> UUID {
        id(values.reduce(200, &+))
    }

    func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
