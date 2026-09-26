import Foundation
import Testing
@testable import RallyFlow

nonisolated struct MultiCourtMatchSchedulerTests {
    @Test(arguments: [(4, 2, 1), (6, 2, 1), (8, 2, 2), (10, 2, 2), (12, 3, 3)])
    func realisticDoublesPoolsFillMaximumCapacity(count: Int, courts: Int, expected: Int) throws {
        let request = try request(count: count, courts: courts)
        let scheduler = MultiCourtMatchScheduler()
        let result = try scheduler.generate(request: request, slots: slots(courts))
        #expect(result.assignments.count == expected)
        #expect(selected(result).count == expected * 4)
        #expect(result.assignments.map(\.slot) == Array(slots(courts).prefix(expected)))
        #expect(result.assignments.allSatisfy { $0.projectedPlayingPlayerIDs.isEmpty })
        #expect(try scheduler.generate(request: request, slots: slots(courts)) == result)
        #expect(try scheduler.validate(batch: result, request: request, slots: slots(courts)) == .valid)
    }

    @Test(arguments: [MatchType.singles, .doubles])
    func exhaustiveSmallPoolCardinalityAndNonOverlap(type: MatchType) throws {
        for count in 0...9 {
            let result = try MultiCourtMatchScheduler().generate(
                request: request(count: count, type: type), slots: slots(2)
            )
            let expected = min(2, count / type.playersPerMatch)
            let ids = result.assignments.flatMap { $0.suggestion.candidate.playerIDs }
            #expect(result.assignments.count == expected)
            #expect(ids.count == Set(ids).count)
            #expect(ids.count == expected * type.playersPerMatch)
        }
    }

    @Test
    func globalOpponentVarietyBeatsGreedyFirstMatch() throws {
        // Equal match counts and reset streaks isolate the global opponent tradeoff.
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [3], [4]), entry(1, [3], [4]), entry(2, [3], [4]),
            entry(3, [1], [20]), entry(4, [1], [20]), entry(5, [1], [20]),
            entry(6, [2], [21]), entry(7, [2], [21]), entry(8, [2], [21]),
            entry(9, [20], [21])
        ])
        let request = try request(count: 4, type: .singles, history: history)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let ranked = try FairRotationCandidateRanker().rank(candidates: candidates, request: request)
        let greedyFirst = try #require(ranked.first)
        #expect(greedyFirst.candidate == (try candidate([1], [2])))
        let greedySecond = try #require(ranked.first {
            Set($0.candidate.playerIDs).isDisjoint(with: greedyFirst.candidate.playerIDs)
        })
        #expect(greedySecond.candidate == (try candidate([3], [4])))

        let batch = try MultiCourtMatchScheduler().generate(request: request, slots: slots(2))
        #expect(batch.assignments.map(\.suggestion.candidate) == [try candidate([1], [3]), try candidate([2], [4])])
        #expect(opponentCost(batch.assignments.map(\.suggestion.candidate), history: history) == 0)
        #expect(opponentCost([greedyFirst.candidate, greedySecond.candidate], history: history) == 3)
        #expect(selected(batch).count == 4)
    }

    @Test
    func completedCountsChangeWhichTwoOfTenRemainUnassigned() throws {
        let scheduler = MultiCourtMatchScheduler()
        let baseline = try scheduler.generate(request: request(count: 10), slots: slots(2))
        #expect(selected(baseline) == Set((1...8).map(id)))
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]), entry(1, [5, 6], [7, 8])
        ])
        let changed = try scheduler.generate(request: request(count: 10, history: history), slots: slots(2))
        #expect(selected(changed).count == 8)
        #expect(selected(changed).isSuperset(of: [id(9), id(10)]))
        #expect(selected(changed) != selected(baseline))
    }

    @Test
    func severeWaitingWinsAPlaceInTheWholeBatch() throws {
        let history = try ParticipantMatchHistory(entries: (0..<4).map {
            try entry($0, [20, 21], [22, 23], eligible: [10, 20, 21, 22, 23])
        })
        let result = try MultiCourtMatchScheduler().generate(
            request: request(count: 10, history: history), slots: slots(2)
        )
        #expect(selected(result).contains(id(10)))
        #expect(result.assignments.contains { $0.suggestion.reasons.contains(.longerWaiting) })
        #expect(history.statistics(for: id(9)).consecutiveRests == 0)
        #expect(history.statistics(for: id(10)).consecutiveRests == 4)
    }

    @Test
    func doublesBatchMatchesExhaustiveUnprunedRelationshipOracle() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]), entry(1, [5, 6], [7, 8]),
            entry(2, [1, 3], [5, 7]), entry(3, [2, 4], [6, 8])
        ])
        let request = try request(count: 8, history: history)
        let candidates = MatchCandidateGenerator().candidates(for: request)
        let result = try MultiCourtMatchScheduler().generate(request: request, slots: slots(2))
        let chosen = result.assignments.map(\.suggestion.candidate)
        let actual = [partnerCost(chosen, history: history), opponentCost(chosen, history: history)]
        var examined = 0
        for first in candidates.indices {
            for second in candidates.indices where second > first {
                let pair = [candidates[first], candidates[second]]
                guard Set(pair[0].playerIDs).isDisjoint(with: pair[1].playerIDs) else { continue }
                examined += 1
                let alternative = [partnerCost(pair, history: history), opponentCost(pair, history: history)]
                #expect(!alternative.lexicographicallyPrecedes(actual))
            }
        }
        #expect(examined == 315)
        #expect(actual[0] == 0)
        #expect(result.assignments.allSatisfy { $0.suggestion.reasons.contains(.newPartnerCombination) })
        let ranked = try FairRotationCandidateRanker().rank(candidates: candidates, request: request)
        for assignment in result.assignments {
            #expect(ranked.contains(assignment.suggestion))
        }
    }

    @Test(arguments: [ParticipantStatus.playing, .resting, .unavailable, .leavingSoon, .left])
    func immediateExcludesEveryNonreadyStatus(status: ParticipantStatus) throws {
        let request = try request(count: 9, statuses: [1: status], explicit: Array(1...9))
        let result = try MultiCourtMatchScheduler().generate(request: request, slots: slots(2))
        #expect(selected(result) == Set((2...9).map(id)))
    }

    @Test
    func upcomingSingleSlotMatchesM36AndImmediateRemainsEmpty() throws {
        let statuses = Dictionary(uniqueKeysWithValues: (1...4).map { ($0, ParticipantStatus.playing) })
        let active = [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
        let upcoming = try request(count: 7, courts: 1, context: .upcoming, statuses: statuses)
        let single = try #require(try UpcomingMatchGenerator().generate(request: upcoming, activeMatches: active))
        let batch = try MultiCourtMatchScheduler().generate(request: upcoming, slots: slots(1), activeMatches: active)
        #expect(batch.assignments.count == 1)
        #expect(batch.assignments[0].suggestion == single.suggestion)
        #expect(batch.assignments[0].projectedPlayingPlayerIDs == single.projectedPlayingPlayerIDs)
        #expect(selected(batch) == Set([1, 5, 6, 7].map(id)))
        let immediate = try request(count: 7, courts: 1, statuses: statuses)
        #expect(try ImmediateMatchGenerator().generate(request: immediate) == nil)
        #expect(try MultiCourtMatchScheduler().generate(request: immediate, slots: slots(1)).assignments.isEmpty)
    }

    @Test
    func upcomingTwoCourtsIncludeWaitersAndExclusiveActivePlayersWithoutMutation() throws {
        let active = try [ActiveMatchSnapshot(candidate: candidate([1, 2], [3, 4])),
                          ActiveMatchSnapshot(candidate: candidate([5, 6], [7, 8]))]
        let statuses = Dictionary(uniqueKeysWithValues: (1...8).map { ($0, ParticipantStatus.playing) })
        let history = try ParticipantMatchHistory(entries: [entry(0, [1, 3], [5, 7])])
        let request = try request(count: 11, context: .upcoming, statuses: statuses, history: history)
        let before = request
        let activeBefore = active
        let courtSlots = slots(2)
        let scheduler = MultiCourtMatchScheduler()
        let batch = try scheduler.generate(request: request, slots: courtSlots, activeMatches: active)
        #expect(batch.assignments.count == 2)
        #expect(selected(batch).count == 8)
        #expect(selected(batch).isSuperset(of: Set([9, 10, 11].map(id))))
        #expect(batch.assignments.flatMap(\.projectedPlayingPlayerIDs).count == 5)
        #expect(try scheduler.validate(batch: batch, request: request, slots: courtSlots, activeMatches: active) == .valid)
        #expect(try scheduler.generate(request: request, slots: courtSlots.reversed(), activeMatches: active.reversed()) == batch)
        #expect(request == before)
        #expect(active == activeBefore)
        #expect(courtSlots == slots(2))
        #expect(request.history.matchesPlayed(for: id(1)) == 1)
        #expect(request.participants.allSatisfy { $0.matchesPlayed == 99 })
    }

    @Test
    func upcomingUnrelatedPlayersAndUnavailableStatusesStayExcluded() throws {
        let active = [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
        let statuses: [Int: ParticipantStatus] = [1: .playing, 2: .playing, 3: .playing, 4: .playing,
            5: .resting, 6: .unavailable, 7: .left, 8: .leavingSoon, 9: .playing]
        let request = try request(count: 10, context: .upcoming, statuses: statuses)
        let batch = try MultiCourtMatchScheduler().generate(request: request, slots: slots(2), activeMatches: active)
        #expect(selected(batch).isDisjoint(with: Set((5...9).map(id))))
        #expect(selected(batch).contains(id(10)))
        let explicit = try self.request(count: 10, context: .upcoming, statuses: statuses, explicit: [1, 8, 9, 10])
        let allowed = try MultiCourtMatchScheduler().generate(request: explicit, slots: slots(2), activeMatches: active)
        #expect(selected(allowed).contains(id(8)))
        #expect(selected(allowed).contains(id(10)))
        #expect(selected(allowed).contains(id(9)))
    }

    @Test
    func reversedRosterAndSlotOrderPreserveAssignmentAndMetadata() throws {
        let request = try request(count: 10)
        let reversed = replacing(request, participants: request.participants.reversed())
        let scheduler = MultiCourtMatchScheduler()
        let batch = try scheduler.generate(request: request, slots: slots(2))
        #expect(try scheduler.generate(request: reversed, slots: slots(2).reversed()) == batch)
    }

    @Test(arguments: [ParticipantStatus.unavailable, .resting, .left])
    func availabilityChangesIdentifyInvalidAssignment(status: ParticipantStatus) throws {
        let scheduler = MultiCourtMatchScheduler()
        let request = try request(count: 8)
        let batch = try scheduler.generate(request: request, slots: slots(2))
        let assignment = try #require(batch.assignments.first)
        let affected = try #require(assignment.suggestion.candidate.playerIDs.first)
        var participants = request.participants
        let index = try #require(participants.firstIndex { $0.playerID == affected })
        participants[index].status = status
        let updated = replacing(request, participants: participants)
        #expect(try scheduler.validate(batch: batch, request: updated, slots: slots(2)) ==
                .invalid(.invalidAssignment(courtID: assignment.slot.courtID, reason: .participantNoLongerEligible(affected))))
        #expect(try scheduler.generate(request: updated, slots: slots(2)).assignments.count == 1)
    }

    @Test
    func slotLossAndDuplicateAssignmentsAreInvalid() throws {
        let scheduler = MultiCourtMatchScheduler()
        let request = try request(count: 8)
        let batch = try scheduler.generate(request: request, slots: slots(2))
        #expect(try scheduler.validate(batch: batch, request: request, slots: slots(1)) == .invalid(.slotUnavailable(id(102))))
        let first = batch.assignments[0]
        let repeatedSlot = MatchmakingBatchSuggestion(schedulingContext: .immediate, matchType: .doubles,
            assignments: [first, first])
        #expect(try scheduler.validate(batch: repeatedSlot, request: request, slots: slots(2)) == .invalid(.duplicateSlot(id(101))))
        let repeatedPlayer = MatchmakingBatchSuggestion(schedulingContext: .immediate, matchType: .doubles,
            assignments: [first, MatchmakingSlotAssignment(slot: slots(2)[1], suggestion: first.suggestion, projectedPlayingPlayerIDs: [])])
        #expect(try scheduler.validate(batch: repeatedPlayer, request: request, slots: slots(2)) ==
                .invalid(.duplicatePlayer(id(1), courtID: id(102))))
    }

    @Test
    func typeContextAndFutureEligibilityChangesInvalidate() throws {
        let scheduler = MultiCourtMatchScheduler()
        let statuses = Dictionary(uniqueKeysWithValues: (1...4).map { ($0, ParticipantStatus.playing) })
        let request = try request(count: 7, courts: 1, context: .upcoming, statuses: statuses)
        let active = [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
        let batch = try scheduler.generate(request: request, slots: slots(1), activeMatches: active)
        #expect(try scheduler.validate(batch: batch, request: request, slots: slots(1)) ==
                .invalid(.invalidAssignment(courtID: id(101), reason: .participantNoLongerEligible(id(1)))))
        #expect(try scheduler.validate(batch: batch, request: self.request(count: 7, courts: 1), slots: slots(1)) ==
                .invalid(.schedulingContextChanged))
        #expect(try scheduler.validate(batch: batch,
            request: self.request(count: 7, type: .singles, courts: 1, context: .upcoming), slots: slots(1)) == .invalid(.matchTypeChanged))
    }

    @Test
    func everySecondCourtCandidateIsCheckedForOverlap() throws {
        let scheduler = MultiCourtMatchScheduler()
        let request = try request(count: 8)
        let first = try candidate([1, 2], [3, 4])
        let candidates = MatchCandidateGenerator().candidates(for: request)
        for second in candidates {
            let batch = MatchmakingBatchSuggestion(schedulingContext: .immediate, matchType: .doubles,
                assignments: [
                    MatchmakingSlotAssignment(slot: slots(2)[0], suggestion: MatchSuggestion(candidate: first), projectedPlayingPlayerIDs: []),
                    MatchmakingSlotAssignment(slot: slots(2)[1], suggestion: MatchSuggestion(candidate: second), projectedPlayingPlayerIDs: [])
                ])
            let validity = try scheduler.validate(batch: batch, request: request, slots: slots(2))
            #expect((validity == .valid) == Set(first.playerIDs).isDisjoint(with: second.playerIDs))
        }
        #expect(candidates.count == 210)
    }

    @Test
    func malformedInputsFailEvenWhenNoMatchesCanBeFormed() throws {
        let scheduler = MultiCourtMatchScheduler()
        #expect(throws: MultiCourtSchedulingError.duplicateSlot(id(101))) {
            try scheduler.generate(request: request(count: 0), slots: [slots(1)[0], slots(1)[0]])
        }
        #expect(throws: MultiCourtSchedulingError.capacitySlotMismatch(usableCourts: 2, slots: 1)) {
            try scheduler.generate(request: request(count: 0), slots: slots(1))
        }
        let missing = MatchmakingRequest(matchType: .doubles, schedulingContext: .immediate, participants: [])
        #expect(throws: FairRotationRankingError.missingCapacity) {
            try scheduler.generate(request: missing, slots: [])
        }
        let original = try request(count: 1)
        #expect(throws: FairRotationRankingError.duplicateParticipant(id(1))) {
            try scheduler.generate(request: replacing(original, participants: original.participants + original.participants), slots: slots(2))
        }
        #expect(throws: FairRotationRankingError.unknownParticipant(id(30))) {
            try scheduler.generate(request: request(count: 0, explicit: [30]), slots: slots(2))
        }
        #expect(throws: AdaptiveWaitingPolicyError.capacityOverflow) {
            try scheduler.generate(request: request(count: 0, courts: Int.max), slots: [])
        }
    }

    @Test
    func removalOfSelectedActivePlayerReturnsSemanticInvalidity() throws {
        let scheduler = MultiCourtMatchScheduler()
        let statuses = Dictionary(uniqueKeysWithValues: (1...4).map { ($0, ParticipantStatus.playing) })
        let request = try request(count: 7, courts: 1, context: .upcoming, statuses: statuses)
        let active = [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
        let batch = try scheduler.generate(request: request, slots: slots(1), activeMatches: active)
        let removed = replacing(request, participants: request.participants.filter { $0.playerID != id(1) })
        #expect(try scheduler.validate(batch: batch, request: removed, slots: slots(1), activeMatches: active) ==
                .invalid(.invalidAssignment(courtID: id(101), reason: .missingParticipant(id(1)))))
    }

    @Test
    func activeSnapshotErrorsPropagateWithoutReconciliation() throws {
        let scheduler = MultiCourtMatchScheduler()
        let active = [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
        #expect(throws: UpcomingMatchGenerationError.overlappingActiveParticipant(id(1))) {
            try scheduler.generate(request: request(count: 8, context: .upcoming), slots: slots(2), activeMatches: active + active)
        }
        #expect(throws: UpcomingMatchGenerationError.unknownActiveParticipant(id(4))) {
            try scheduler.generate(request: request(count: 3, context: .upcoming), slots: slots(2), activeMatches: active)
        }
        #expect(throws: MultiCourtSchedulingError.activeSnapshotsInImmediateContext) {
            try scheduler.generate(request: request(count: 8), slots: slots(2), activeMatches: active)
        }
    }

    @Test
    func emptySlotsAndAsynchronousSubsetAreExplicit() throws {
        let scheduler = MultiCourtMatchScheduler()
        #expect(try scheduler.generate(request: request(count: 8), slots: []).assignments.isEmpty)
        let subset = [MatchmakingSlot(courtID: id(102))]
        let result = try scheduler.generate(request: request(count: 8, courts: 1), slots: subset)
        #expect(result.assignments.count == 1)
        #expect(result.assignments[0].slot == subset[0])
        #expect(try scheduler.validate(batch: result, request: request(count: 8), slots: slots(2)) == .valid)
    }

    @Test
    func slotCodablePreservesExistingCourtIdentity() throws {
        let slot = MatchmakingSlot(courtID: Court(id: id(101), name: "Court 1").id)
        #expect(try JSONDecoder().decode(MatchmakingSlot.self, from: JSONEncoder().encode(slot)) == slot)
    }

    private func request(
        count: Int, type: MatchType = .doubles, courts: Int = 2,
        context: SchedulingContext = .immediate, statuses: [Int: ParticipantStatus] = [:],
        explicit: [Int]? = nil, history: ParticipantMatchHistory = ParticipantMatchHistory()
    ) throws -> MatchmakingRequest {
        MatchmakingRequest(matchType: type, schedulingContext: context,
            participants: (0..<count).map {
                SessionParticipant(playerID: id($0 + 1), status: statuses[$0 + 1] ?? .ready,
                                   matchesPlayed: 99, consecutiveMatches: 9, consecutiveRests: 9)
            }, eligibility: explicit.map { .explicit(playerIDs: Set($0.map(id))) } ?? .readyParticipants,
            history: history, capacity: try MatchmakingCapacity(usableCourtCount: courts))
    }

    private func replacing(_ request: MatchmakingRequest, participants: [SessionParticipant]) -> MatchmakingRequest {
        MatchmakingRequest(matchType: request.matchType, schedulingContext: request.schedulingContext,
            participants: participants, eligibility: request.eligibility, history: request.history, capacity: request.capacity)
    }

    private func slots(_ count: Int) -> [MatchmakingSlot] {
        (0..<count).map { MatchmakingSlot(courtID: id(101 + $0)) }
    }

    private func selected(_ batch: MatchmakingBatchSuggestion) -> Set<Player.ID> {
        Set(batch.assignments.flatMap { $0.suggestion.candidate.playerIDs })
    }

    private func entry(_ sequence: Int, _ first: [Int], _ second: [Int], eligible: [Int]? = nil) throws -> MatchHistoryEntry {
        try MatchHistoryEntry(sequence: sequence, candidate: candidate(first, second),
                              eligiblePlayerIDs: eligible.map { Set($0.map(id)) })
    }

    private func candidate(_ first: [Int], _ second: [Int]) throws -> MatchCandidate {
        try MatchCandidate(matchType: first.count == 1 ? .singles : .doubles,
                           teamA: Team(playerIDs: first.map(id)), teamB: Team(playerIDs: second.map(id)))
    }

    private func partnerCost(_ candidates: [MatchCandidate], history: ParticipantMatchHistory) -> Int {
        candidates.reduce(0) { total, candidate in
            [candidate.teamA, candidate.teamB].reduce(total) { subtotal, team in
                subtotal + history.partnerCount(between: team.playerIDs[0], and: team.playerIDs[1])
            }
        }
    }

    private func opponentCost(_ candidates: [MatchCandidate], history: ParticipantMatchHistory) -> Int {
        candidates.reduce(0) { total, candidate in
            candidate.teamA.playerIDs.reduce(total) { subtotal, first in
                candidate.teamB.playerIDs.reduce(subtotal) { $0 + history.opponentCount(between: first, and: $1) }
            }
        }
    }

    private func id(_ value: Int) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(value)))
    }
}
