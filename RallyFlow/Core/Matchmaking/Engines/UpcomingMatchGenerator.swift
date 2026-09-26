import Foundation

nonisolated enum UpcomingMatchGenerationError: Error, Equatable, Sendable {
    case invalidSchedulingContext(SchedulingContext)
    case unknownActiveParticipant(Player.ID)
    case overlappingActiveParticipant(Player.ID)
}

/// Produces one tentative Fair Social decision. Independent calls may select overlapping players.
nonisolated struct UpcomingMatchGenerator: Sendable {
    func generate(
        request: MatchmakingRequest,
        activeMatches: [ActiveMatchSnapshot]
    ) throws -> UpcomingMatchSuggestion? {
        let input = try prepare(request: request, activeMatches: activeMatches)
        let candidates = MatchCandidateGenerator().candidates(for: input.request)
        guard let suggestion = try FairRotationCandidateRanker().rank(
            candidates: candidates, request: input.request, projection: input.projection
        ).first else { return nil }

        return UpcomingMatchSuggestion(
            suggestion: suggestion,
            activePlayerIDs: input.projection?.activePlayerIDs ?? []
        )
    }

    /// Checks current legality, not whether the candidate still ranks first.
    /// Malformed request/snapshot data throws; availability changes return semantic invalidity.
    /// Regenerate separately to refresh the suggestion's reasons and captured playing markers.
    func validate(
        suggestion: UpcomingMatchSuggestion,
        request: MatchmakingRequest,
        activeMatches: [ActiveMatchSnapshot]
    ) throws -> UpcomingSuggestionValidity {
        try validateContextAndCapacity(request)
        let candidate = suggestion.suggestion.candidate
        guard candidate.matchType == request.matchType else {
            return .invalid(.matchTypeChanged)
        }
        let rosterIDs = Set(request.participants.map(\.playerID))
        for playerID in candidate.playerIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard rosterIDs.contains(playerID) else {
                return .invalid(.missingParticipant(playerID))
            }
        }
        let input = try prepare(request: request, activeMatches: activeMatches)
        let eligibleIDs = Set(input.request.participants.filter(input.request.isEligible).map(\.playerID))
        for playerID in candidate.playerIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard eligibleIDs.contains(playerID) else {
                return .invalid(.participantNoLongerEligible(playerID))
            }
        }
        return .valid
    }

    private func validateContextAndCapacity(_ request: MatchmakingRequest) throws {
        guard request.schedulingContext == .upcoming else {
            throw UpcomingMatchGenerationError.invalidSchedulingContext(request.schedulingContext)
        }
        guard let capacity = request.capacity else {
            throw FairRotationRankingError.missingCapacity
        }
        guard !request.matchType.playersPerMatch.multipliedReportingOverflow(
            by: capacity.usableCourtCount
        ).overflow else {
            throw AdaptiveWaitingPolicyError.capacityOverflow
        }
    }

    /// Resolves the shared future pool and one transient opportunity for single or batch decisions.
    func prepare(
        request: MatchmakingRequest,
        activeMatches: [ActiveMatchSnapshot]
    ) throws -> (request: MatchmakingRequest, projection: UpcomingParticipationProjection?) {
        try validateContextAndCapacity(request)
        var rosterIDs: Set<Player.ID> = []
        for participant in request.participants {
            guard rosterIDs.insert(participant.playerID).inserted else {
                throw FairRotationRankingError.duplicateParticipant(participant.playerID)
            }
        }
        var snapshotIDs: Set<Player.ID> = []
        for playerID in activeMatches.flatMap(\.playerIDs).sorted(by: { $0.uuidString < $1.uuidString }) {
            guard rosterIDs.contains(playerID) else {
                throw UpcomingMatchGenerationError.unknownActiveParticipant(playerID)
            }
            guard snapshotIDs.insert(playerID).inserted else {
                throw UpcomingMatchGenerationError.overlappingActiveParticipant(playerID)
            }
        }

        let eligibility: MatchmakingEligibility
        switch request.eligibility {
        case .readyParticipants:
            eligibility = .explicit(playerIDs: Set(request.participants.compactMap {
                if $0.status == .ready || ($0.status == .playing && snapshotIDs.contains($0.playerID)) {
                    return $0.playerID
                }
                return nil
            }))
        case .explicit(let playerIDs):
            for playerID in playerIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                guard rosterIDs.contains(playerID) else {
                    throw FairRotationRankingError.unknownParticipant(playerID)
                }
            }
            eligibility = request.eligibility
        }

        let resolved = MatchmakingRequest(
            matchType: request.matchType, schedulingContext: .upcoming,
            participants: request.participants, eligibility: eligibility,
            history: request.history, capacity: request.capacity
        )
        let activeIDs = Set(request.participants.filter {
            ($0.status == .playing || $0.status == .leavingSoon)
                && (snapshotIDs.contains($0.playerID) || ($0.status == .playing && resolved.isEligible($0)))
        }.map(\.playerID))
        let eligibleIDs = Set(request.participants.filter(resolved.isEligible).map(\.playerID))
        let projection = activeIDs.isEmpty ? nil : UpcomingParticipationProjection(
            activePlayerIDs: activeIDs.intersection(eligibleIDs)
        )
        return (resolved, projection)
    }
}
