import Foundation
import Testing
@testable import RallyFlow

nonisolated struct UpcomingMatchGeneratorTests {
    @Test(arguments: [5, 6, 7])
    func waitingPlayersFillTheNextMatchBeforeActivePlayers(count: Int) throws {
        let request = try request(count: count)
        let snapshots = try snapshots()
        let before = request
        let generator = UpcomingMatchGenerator()
        let result = try #require(try generator.generate(request: request, activeMatches: snapshots))

        #expect(Set(result.suggestion.candidate.playerIDs).isSuperset(of: Set((5...count).map(id))))
        #expect(result.projectedPlayingPlayerIDs.count == 8 - count)
        #expect(result.projectedPlayingPlayerIDs == Set((1...(8 - count)).map(id)))
        #expect(Set(result.suggestion.candidate.playerIDs).count == 4)
        #expect(result.suggestion.warnings.contains(.consecutivePlay))
        #expect(try generator.generate(request: request, activeMatches: snapshots) == result)
        #expect(request == before)
        #expect(request.history.entries.isEmpty)
        #expect(request.participants.allSatisfy { $0.matchesPlayed == 42 })
    }

    @Test
    func sevenPlayerFullPipelineMatchesProjectedRanker() throws {
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: snapshots()[0].candidate)
        ])
        let request = try request(count: 7, history: history)
        let resolved = try self.request(
            count: 7, eligibility: .explicit(playerIDs: Set((1...7).map(id))), history: history
        )
        let candidates = MatchCandidateGenerator().candidates(for: resolved)
        let expected = try #require(FairRotationCandidateRanker().rank(
            candidates: candidates, request: resolved,
            projection: UpcomingParticipationProjection(activePlayerIDs: Set((1...4).map(id)))
        ).first)
        let result = try #require(try UpcomingMatchGenerator().generate(
            request: request, activeMatches: snapshots()
        ))

        #expect(candidates.count == 105)
        #expect(Set(candidates).count == 105)
        #expect(result.suggestion == expected)
        #expect(Set(result.suggestion.candidate.playerIDs) == Set([1, 5, 6, 7].map(id)))
        #expect(result.projectedPlayingPlayerIDs == [id(1)])
    }

    @Test
    func fourPlayersCanReplayAndCompletedPartnershipsInfluencePairing() throws {
        let active = try snapshots()
        let emptyRequest = try request(count: 4)
        let initial = try #require(try UpcomingMatchGenerator().generate(request: emptyRequest, activeMatches: active))
        #expect(initial.suggestion.candidate == active[0].candidate)
        #expect(initial.suggestion.reasons.contains(.newPartnerCombination))
        #expect(!initial.suggestion.warnings.contains(.repeatedPartner))

        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: active[0].candidate)
        ])
        let replay = try #require(try UpcomingMatchGenerator().generate(
            request: request(count: 4, history: history), activeMatches: active
        ))
        #expect(replay.projectedPlayingPlayerIDs == Set((1...4).map(id)))
        #expect(replay.suggestion.candidate == (try candidate([1, 3], [2, 4])))
        #expect(replay.suggestion.candidate != active[0].candidate)
    }

    @Test
    func immediateGenerationStillCannotUseActiveParticipants() throws {
        let immediate = try request(count: 7, context: .immediate)
        #expect(try ImmediateMatchGenerator().generate(request: immediate) == nil)
    }

    @Test
    func unrelatedPlayingParticipantRemainsExcluded() throws {
        let request = try request(count: 8, statuses: [8: .playing])
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: snapshots()))
        #expect(!result.suggestion.candidate.contains(playerID: id(8)))
        #expect(result.projectedPlayingPlayerIDs == [id(1)])
    }

    @Test
    func explicitWhitelistAuthorizesActivePlayerWithoutSnapshot() throws {
        let request = try request(count: 7, eligibility: .explicit(playerIDs: Set([2, 5, 6, 7].map(id))))
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: []))
        #expect(Set(result.suggestion.candidate.playerIDs) == Set([2, 5, 6, 7].map(id)))
        #expect(result.projectedPlayingPlayerIDs == [id(2)])
    }

    @Test
    func whitelistCanExcludePlayersFromSuppliedSnapshots() throws {
        let request = try request(count: 7, eligibility: .explicit(playerIDs: Set([4, 5, 6, 7].map(id))))
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: snapshots()))
        #expect(result.projectedPlayingPlayerIDs == [id(4)])
    }

    @Test(arguments: [ParticipantStatus.resting, .unavailable, .left])
    func unavailableStatusesNeverBecomeFutureEligible(status: ParticipantStatus) throws {
        let request = try request(count: 8, statuses: [8: status],
                                  eligibility: .explicit(playerIDs: Set([1, 5, 6, 7, 8].map(id))))
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: snapshots()))
        #expect(!result.suggestion.candidate.contains(playerID: id(8)))
    }

    @Test
    func leavingSoonRequiresExplicitPermissionEvenInSnapshot() throws {
        let defaultRequest = try request(count: 4, statuses: [1: .leavingSoon])
        #expect(try UpcomingMatchGenerator().generate(request: defaultRequest, activeMatches: snapshots()) == nil)
        let allowed = try request(count: 4, statuses: [1: .leavingSoon],
                                 eligibility: .explicit(playerIDs: Set((1...4).map(id))))
        let result = try #require(try UpcomingMatchGenerator().generate(request: allowed, activeMatches: snapshots()))
        #expect(result.projectedPlayingPlayerIDs.contains(id(1)))
    }

    @Test
    func leavingSoonWithoutActiveSnapshotIsNotMarkedPlaying() throws {
        let request = try request(count: 4, statuses: [1: .leavingSoon, 2: .ready, 3: .ready, 4: .ready],
                                  eligibility: .explicit(playerIDs: Set((1...4).map(id))))
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: []))
        #expect(result.projectedPlayingPlayerIDs.isEmpty)
    }

    @Test
    func revalidationAcceptsExpectedPlayersStillPlayingAndLaterReady() throws {
        let generator = UpcomingMatchGenerator()
        let request = try request(count: 7)
        let result = try #require(try generator.generate(request: request, activeMatches: snapshots()))
        #expect(try generator.validate(suggestion: result, request: request, activeMatches: snapshots()) == .valid)
        let finished = try self.request(count: 7, statuses: [1: .ready, 2: .ready, 3: .ready, 4: .ready])
        #expect(try generator.validate(suggestion: result, request: finished, activeMatches: []) == .valid)
        let refreshed = try #require(try generator.generate(request: finished, activeMatches: []))
        #expect(refreshed.projectedPlayingPlayerIDs.isEmpty)
    }

    @Test(arguments: [ParticipantStatus.unavailable, .resting, .left, .leavingSoon])
    func availabilityChangeInvalidatesAndRegenerationFindsReplacement(status: ParticipantStatus) throws {
        let generator = UpcomingMatchGenerator()
        let original = try request(count: 7)
        let result = try #require(try generator.generate(request: original, activeMatches: snapshots()))
        let updated = try request(count: 7, statuses: [5: status])
        #expect(try generator.validate(suggestion: result, request: updated, activeMatches: snapshots())
                == .invalid(.participantNoLongerEligible(id(5))))
        let replacement = try #require(try generator.generate(request: updated, activeMatches: snapshots()))
        #expect(!replacement.suggestion.candidate.contains(playerID: id(5)))
    }

    @Test
    func lostActiveAuthorizationInvalidatesSuggestion() throws {
        let generator = UpcomingMatchGenerator()
        let request = try request(count: 7)
        let result = try #require(try generator.generate(request: request, activeMatches: snapshots()))
        #expect(try generator.validate(suggestion: result, request: request, activeMatches: [])
                == .invalid(.participantNoLongerEligible(id(1))))
        #expect(try generator.generate(request: request, activeMatches: []) == nil)
    }

    @Test
    func removedParticipantAndChangedMatchTypeInvalidate() throws {
        let generator = UpcomingMatchGenerator()
        let original = try request(count: 7)
        let result = try #require(try generator.generate(request: original, activeMatches: snapshots()))
        let removed = replacing(original, participants: original.participants.filter { $0.playerID != id(5) })
        #expect(try generator.validate(suggestion: result, request: removed, activeMatches: snapshots())
                == .invalid(.missingParticipant(id(5))))
        let singles = try request(count: 7, type: .singles)
        #expect(try generator.validate(suggestion: result, request: singles, activeMatches: snapshots())
                == .invalid(.matchTypeChanged))
    }

    @Test
    func completedHistoryAndCachedCountersStayUnchanged() throws {
        let active = try snapshots()
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 7, candidate: active[0].candidate,
                              eligiblePlayerIDs: Set((1...7).map(id)))
        ])
        let request = try request(count: 7, history: history)
        let before = request
        let stats = (1...7).map { history.statistics(for: id($0)) }
        _ = try UpcomingMatchGenerator().generate(request: request, activeMatches: active)
        #expect(request == before)
        #expect(request.history.entries.count == 1)
        #expect(request.history.entries[0].sequence == 7)
        #expect((1...7).map { request.history.statistics(for: id($0)) } == stats)
        #expect(request.history.partnerCount(between: id(1), and: id(2)) == 1)
        #expect(request.history.opponentCount(between: id(1), and: id(3)) == 1)
        #expect(request.participants == before.participants)
        #expect(active == (try snapshots()))
    }

    @Test
    func completedRelationshipVarietyChangesWhichActivePlayerIsChosen() throws {
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: candidate([1, 5], [6, 7])),
            MatchHistoryEntry(sequence: 1, candidate: candidate([2, 3], [4, 8]))
        ])
        let request = try request(count: 7, history: history)
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: snapshots()))
        #expect(result.projectedPlayingPlayerIDs == [id(2)])
        #expect(Set(result.suggestion.candidate.playerIDs).isSuperset(of: Set([5, 6, 7].map(id))))
    }

    @Test
    func projectionPrioritizesWaitingWithoutExcludingReplay() throws {
        let request = try request(count: 5, eligibility: .explicit(playerIDs: Set((1...5).map(id))))
        let replay = try candidate([1, 2], [3, 4])
        let includesWaiting = try candidate([1, 2], [3, 5])
        let ranked = try FairRotationCandidateRanker().rank(
            candidates: [replay, includesWaiting], request: request,
            projection: UpcomingParticipationProjection(activePlayerIDs: Set((1...4).map(id)))
        )
        #expect(ranked.first?.candidate == includesWaiting)
        #expect(ranked.last?.candidate == replay)
    }

    @Test
    func sharedEligibilityKeepsCandidateGenerationAndRankingAligned() throws {
        let request = try request(count: 9, statuses: [5: .resting, 6: .unavailable, 7: .left, 8: .leavingSoon])
        let candidates = MatchCandidateGenerator().candidates(for: request)
        #expect(candidates.isEmpty)
        let explicit = try self.request(count: 9, statuses: [5: .resting, 6: .unavailable, 7: .left, 8: .leavingSoon],
                                        eligibility: .explicit(playerIDs: Set((1...9).map(id))))
        let allowed = MatchCandidateGenerator().candidates(for: explicit)
        let ranked = try FairRotationCandidateRanker().rank(candidates: allowed, request: explicit)
        #expect(ranked.count == allowed.count)
        #expect(allowed.allSatisfy { Set($0.playerIDs).isDisjoint(with: Set([5, 6, 7].map(id))) })
    }

    @Test
    func multipleRelevantSnapshotsAreOneOpportunityAndOrderIndependent() throws {
        let active = try snapshots() + [ActiveMatchSnapshot(candidate: candidate([5, 6], [7, 8]))]
        let statuses = Dictionary(uniqueKeysWithValues: (1...8).map { ($0, ParticipantStatus.playing) })
        let request = try request(count: 11, statuses: statuses, courts: 2)
        let generator = UpcomingMatchGenerator()
        let result = try #require(try generator.generate(request: request, activeMatches: active))
        #expect(result.projectedPlayingPlayerIDs.count == 1)
        #expect(Set(result.suggestion.candidate.playerIDs).isSuperset(of: Set([9, 10, 11].map(id))))
        let reversed = replacing(request, participants: request.participants.reversed())
        #expect(try generator.generate(request: reversed, activeMatches: active.reversed()) == result)
    }

    @Test(arguments: [0, 1, 3])
    func readyOnlyInsufficientPoolReturnsNil(count: Int) throws {
        let statuses = Dictionary(uniqueKeysWithValues: (1...4).map { ($0, ParticipantStatus.ready) })
        #expect(try UpcomingMatchGenerator().generate(
            request: request(count: count, statuses: statuses), activeMatches: []
        ) == nil)
    }

    @Test
    func singlesSupportsFutureParticipation() throws {
        let request = try request(count: 3, statuses: [3: .ready], type: .singles)
        let active = [ActiveMatchSnapshot(candidate: try candidate([1], [2]))]
        let result = try #require(try UpcomingMatchGenerator().generate(request: request, activeMatches: active))
        #expect(Set(result.suggestion.candidate.playerIDs) == [id(1), id(3)])
        #expect(result.projectedPlayingPlayerIDs == [id(1)])
    }

    @Test
    func invalidContextCapacityAndRosterFailPredictably() throws {
        let generator = UpcomingMatchGenerator()
        #expect(throws: UpcomingMatchGenerationError.invalidSchedulingContext(.immediate)) {
            try generator.generate(request: request(count: 7, context: .immediate), activeMatches: snapshots())
        }
        let missing = MatchmakingRequest(matchType: .doubles, schedulingContext: .upcoming, participants: [])
        #expect(throws: FairRotationRankingError.missingCapacity) {
            try generator.generate(request: missing, activeMatches: [])
        }
        #expect(throws: MatchmakingCapacityError.invalidUsableCourtCount(0)) {
            try request(count: 7, courts: 0)
        }
        #expect(throws: AdaptiveWaitingPolicyError.capacityOverflow) {
            try generator.generate(request: request(count: 0, courts: Int.max), activeMatches: [])
        }
        let valid = try request(count: 7)
        let duplicate = replacing(valid, participants: valid.participants + [valid.participants[0]])
        #expect(throws: FairRotationRankingError.duplicateParticipant(id(1))) {
            try generator.generate(request: duplicate, activeMatches: snapshots())
        }
    }

    @Test
    func unknownAndOverlappingActiveSnapshotsAreRejected() throws {
        let generator = UpcomingMatchGenerator()
        let request = try request(count: 7)
        #expect(throws: UpcomingMatchGenerationError.unknownActiveParticipant(id(8))) {
            try generator.generate(request: request, activeMatches: [ActiveMatchSnapshot(candidate: candidate([1, 2], [3, 8]))])
        }
        #expect(throws: UpcomingMatchGenerationError.overlappingActiveParticipant(id(1))) {
            try generator.generate(request: request, activeMatches: snapshots() + snapshots())
        }
        #expect(throws: FairRotationRankingError.unknownParticipant(id(9))) {
            try generator.generate(request: self.request(count: 7, eligibility: .explicit(playerIDs: [id(9)])), activeMatches: [])
        }
    }

    @Test
    func snapshotCodableReusesCandidateValidation() throws {
        let snapshot = try snapshots()[0]
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(ActiveMatchSnapshot.self, from: data) == snapshot)
        #expect(throws: MatchCandidateError.duplicatePlayer) {
            ActiveMatchSnapshot(candidate: try candidate([1, 2], [1, 4]))
        }
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var match = try #require(object["candidate"] as? [String: Any])
        var teamB = try #require(match["teamB"] as? [String: Any])
        teamB["playerIDs"] = [id(1).uuidString, id(4).uuidString]
        match["teamB"] = teamB
        object["candidate"] = match
        let malformed = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ActiveMatchSnapshot.self, from: malformed)
        }
    }

    @Test
    func projectionCannotBeAppliedToImmediateOrUnknownPlayers() throws {
        let match = try candidate([1, 2], [3, 4])
        #expect(throws: FairRotationRankingError.invalidProjectionContext) {
            try FairRotationCandidateRanker().rank(candidates: [match],
                request: request(count: 4, context: .immediate),
                projection: UpcomingParticipationProjection(activePlayerIDs: [id(1)]))
        }
        #expect(throws: FairRotationRankingError.invalidProjectedParticipant(id(9))) {
            try FairRotationCandidateRanker().rank(candidates: [match],
                request: request(count: 4, eligibility: .explicit(playerIDs: Set((1...4).map(id)))),
                projection: UpcomingParticipationProjection(activePlayerIDs: [id(9)]))
        }
    }

    private func request(
        count: Int, statuses: [Int: ParticipantStatus] = [:],
        eligibility: MatchmakingEligibility = .readyParticipants,
        history: ParticipantMatchHistory = ParticipantMatchHistory(),
        courts: Int = 1, context: SchedulingContext = .upcoming, type: MatchType = .doubles
    ) throws -> MatchmakingRequest {
        MatchmakingRequest(matchType: type, schedulingContext: context,
            participants: (0..<count).map { index in
                let value = index + 1
                return SessionParticipant(playerID: id(value),
                    status: statuses[value] ?? (value <= 4 ? .playing : .ready),
                    matchesPlayed: 42, consecutiveMatches: 10, consecutiveRests: 9)
            }, eligibility: eligibility, history: history,
            capacity: try MatchmakingCapacity(usableCourtCount: courts))
    }

    private func replacing(_ request: MatchmakingRequest, participants: [SessionParticipant]) -> MatchmakingRequest {
        MatchmakingRequest(matchType: request.matchType, schedulingContext: request.schedulingContext,
            participants: participants, eligibility: request.eligibility, history: request.history, capacity: request.capacity)
    }

    private func snapshots() throws -> [ActiveMatchSnapshot] {
        [ActiveMatchSnapshot(candidate: try candidate([1, 2], [3, 4]))]
    }

    private func candidate(_ first: [Int], _ second: [Int]) throws -> MatchCandidate {
        try MatchCandidate(matchType: first.count == 1 ? .singles : .doubles,
                           teamA: Team(playerIDs: first.map(id)), teamB: Team(playerIDs: second.map(id)))
    }

    private func id(_ value: Int) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(value)))
    }
}
