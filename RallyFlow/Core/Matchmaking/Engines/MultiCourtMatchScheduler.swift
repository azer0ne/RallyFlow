import Foundation

/// Invalid batch inputs, distinct from a valid pool that cannot fill a court.
nonisolated enum MultiCourtSchedulingError: Error, Equatable, Sendable {
    case duplicateSlot(Court.ID)
    case capacitySlotMismatch(usableCourts: Int, slots: Int)
    case activeSnapshotsInImmediateContext
}

/// Exact Fair Social selection for interchangeable slots at one caller-defined opportunity.
nonisolated struct MultiCourtMatchScheduler: Sendable {
    /// Returns the maximum feasible number of exclusive assignments, without reserving session state.
    func generate(
        request: MatchmakingRequest,
        slots: [MatchmakingSlot],
        activeMatches: [ActiveMatchSnapshot] = []
    ) throws -> MatchmakingBatchSuggestion {
        let orderedSlots = try validatedSlots(slots, request: request)
        let input = try prepare(request: request, activeMatches: activeMatches)
        let eligibleIDs = Set(input.request.participants.filter(input.request.isEligible).map(\.playerID))
        let assignmentCount = min(slots.count, eligibleIDs.count / request.matchType.playersPerMatch)
        guard assignmentCount > 0 else {
            return MatchmakingBatchSuggestion(
                schedulingContext: request.schedulingContext, matchType: request.matchType, assignments: []
            )
        }
        let candidates = MatchCandidateGenerator().candidates(for: input.request)
        let assessment = try FairRotationCandidateRanker().assessment(
            candidates: candidates, request: input.request, projection: input.projection
        )
        var search = BatchSearch(assessment: assessment, playersPerMatch: request.matchType.playersPerMatch)
        let chosen = search.bestOptions(playerIDs: eligibleIDs, assignmentCount: assignmentCount)
        let activeIDs = input.projection?.activePlayerIDs ?? []
        return MatchmakingBatchSuggestion(
            schedulingContext: request.schedulingContext, matchType: request.matchType,
            assignments: zip(orderedSlots, chosen).map { slot, option in
                MatchmakingSlotAssignment(
                    slot: slot, suggestion: option.suggestion,
                    projectedPlayingPlayerIDs: activeIDs.intersection(option.playerIDs)
                )
            }
        )
    }

    /// Reports the first conflict without repairing assignments or refreshing captured metadata.
    func validate(
        batch: MatchmakingBatchSuggestion,
        request: MatchmakingRequest,
        slots: [MatchmakingSlot],
        activeMatches: [ActiveMatchSnapshot] = []
    ) throws -> MatchmakingBatchValidity {
        guard batch.schedulingContext == request.schedulingContext else {
            return .invalid(.schedulingContextChanged)
        }
        guard batch.matchType == request.matchType else { return .invalid(.matchTypeChanged) }
        let slotIDs = Set(slots.map(\.courtID))
        var seenSlots: Set<Court.ID> = []
        var seenPlayers: Set<Player.ID> = []
        let assignments = batch.assignments.sorted { $0.slot.courtID.uuidString < $1.slot.courtID.uuidString }
        for assignment in assignments {
            let courtID = assignment.slot.courtID
            guard slotIDs.contains(courtID) else { return .invalid(.slotUnavailable(courtID)) }
            guard seenSlots.insert(courtID).inserted else { return .invalid(.duplicateSlot(courtID)) }
            guard assignment.suggestion.candidate.matchType == request.matchType else {
                return .invalid(.invalidAssignment(courtID: courtID, reason: .matchTypeChanged))
            }
            for playerID in assignment.suggestion.candidate.playerIDs.sorted(by: idPrecedes) {
                guard seenPlayers.insert(playerID).inserted else {
                    return .invalid(.duplicatePlayer(playerID, courtID: courtID))
                }
            }
        }
        _ = try validatedSlots(slots, request: request)
        let rosterIDs = Set(request.participants.map(\.playerID))
        for assignment in assignments {
            for playerID in assignment.suggestion.candidate.playerIDs.sorted(by: idPrecedes)
                where !rosterIDs.contains(playerID) {
                return .invalid(.invalidAssignment(courtID: assignment.slot.courtID, reason: .missingParticipant(playerID)))
            }
        }
        let input = try prepare(request: request, activeMatches: activeMatches)
        let eligibleIDs = Set(input.request.participants.filter(input.request.isEligible).map(\.playerID))
        for assignment in assignments {
            for playerID in assignment.suggestion.candidate.playerIDs.sorted(by: idPrecedes) {
                if !eligibleIDs.contains(playerID) {
                    return .invalid(.invalidAssignment(courtID: assignment.slot.courtID,
                        reason: .participantNoLongerEligible(playerID)))
                }
            }
        }
        return .valid
    }

    private func validatedSlots(
        _ slots: [MatchmakingSlot], request: MatchmakingRequest
    ) throws -> [MatchmakingSlot] {
        guard let capacity = request.capacity else { throw FairRotationRankingError.missingCapacity }
        guard !request.matchType.playersPerMatch.multipliedReportingOverflow(by: capacity.usableCourtCount).overflow else {
            throw AdaptiveWaitingPolicyError.capacityOverflow
        }
        let ordered = slots.sorted { $0.courtID.uuidString < $1.courtID.uuidString }
        var seen: Set<Court.ID> = []
        for slot in ordered {
            guard seen.insert(slot.courtID).inserted else { throw MultiCourtSchedulingError.duplicateSlot(slot.courtID) }
        }
        guard slots.isEmpty || capacity.usableCourtCount == slots.count else {
            throw MultiCourtSchedulingError.capacitySlotMismatch(usableCourts: capacity.usableCourtCount, slots: slots.count)
        }
        return ordered
    }

    private func prepare(
        request: MatchmakingRequest, activeMatches: [ActiveMatchSnapshot]
    ) throws -> (request: MatchmakingRequest, projection: UpcomingParticipationProjection?) {
        if request.schedulingContext == .upcoming {
            return try UpcomingMatchGenerator().prepare(request: request, activeMatches: activeMatches)
        }
        guard activeMatches.isEmpty else { throw MultiCourtSchedulingError.activeSnapshotsInImmediateContext }
        var rosterIDs: Set<Player.ID> = []
        for participant in request.participants {
            guard rosterIDs.insert(participant.playerID).inserted else {
                throw FairRotationRankingError.duplicateParticipant(participant.playerID)
            }
        }
        if case .explicit(let playerIDs) = request.eligibility {
            for playerID in playerIDs.sorted(by: idPrecedes) where !rosterIDs.contains(playerID) {
                throw FairRotationRankingError.unknownParticipant(playerID)
            }
        }
        return (request, nil)
    }

    private func idPrecedes(_ lhs: Player.ID, _ rhs: Player.ID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

/// Exact partition search. Local mutable scratch storage never escapes a generation call.
nonisolated private struct BatchSearch {
    let assessment: FairRotationAssessment
    let playersPerMatch: Int
    let optionsByPlayer: [Player.ID: [FairRotationBatchOption]]
    var primaryCache: [Set<Player.ID>: FairRotationPrimaryPriority] = [:]
    var best: (primary: FairRotationPrimaryPriority, secondary: FairRotationSecondaryPriority,
               keys: [String], options: [FairRotationBatchOption])?

    init(assessment: FairRotationAssessment, playersPerMatch: Int) {
        self.assessment = assessment
        self.playersPerMatch = playersPerMatch
        var bestByGroup: [Set<Player.ID>: FairRotationBatchOption] = [:]
        for option in assessment.batchOptions {
            if let previous = bestByGroup[option.playerIDs],
               previous.secondary < option.secondary
                || (previous.secondary == option.secondary && previous.canonicalKey < option.canonicalKey) {
                continue
            }
            bestByGroup[option.playerIDs] = option
        }
        var indexed: [Player.ID: [FairRotationBatchOption]] = [:]
        for option in bestByGroup.values.sorted(by: { $0.canonicalKey < $1.canonicalKey }) {
            for playerID in option.playerIDs { indexed[playerID, default: []].append(option) }
        }
        optionsByPlayer = indexed
    }

    mutating func bestOptions(playerIDs: Set<Player.ID>, assignmentCount: Int) -> [FairRotationBatchOption] {
        visit(remaining: playerIDs, slotsLeft: assignmentCount, chosen: [], selected: [], secondary: .init())
        return best?.options ?? []
    }

    private mutating func visit(
        remaining: Set<Player.ID>, slotsLeft: Int, chosen: [FairRotationBatchOption],
        selected: Set<Player.ID>, secondary: FairRotationSecondaryPriority
    ) {
        if slotsLeft == 0 {
            let primary = primaryCache[selected] ?? assessment.primaryPriority(selectedPlayerIDs: selected)
            primaryCache[selected] = primary
            if let best {
                if best.primary < primary { return }
                if best.primary == primary && best.secondary < secondary { return }
            }
            let ordered = chosen.sorted { $0.canonicalKey < $1.canonicalKey }
            let keys = ordered.map(\.canonicalKey)
            if let best, best.primary == primary, best.secondary == secondary,
               !keys.lexicographicallyPrecedes(best.keys) { return }
            best = (primary, secondary, keys, ordered)
            return
        }
        guard remaining.count / playersPerMatch >= slotsLeft,
              let pivot = remaining.min(by: { $0.uuidString < $1.uuidString }) else { return }
        for option in optionsByPlayer[pivot] ?? [] where option.playerIDs.isSubset(of: remaining) {
            visit(remaining: remaining.subtracting(option.playerIDs), slotsLeft: slotsLeft - 1,
                  chosen: chosen + [option], selected: selected.union(option.playerIDs),
                  secondary: secondary.adding(option.secondary))
        }
        if remaining.count > slotsLeft * playersPerMatch {
            visit(remaining: remaining.subtracting([pivot]), slotsLeft: slotsLeft,
                  chosen: chosen, selected: selected, secondary: secondary)
        }
    }
}
