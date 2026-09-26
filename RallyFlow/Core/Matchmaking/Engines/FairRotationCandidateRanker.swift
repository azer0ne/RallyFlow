//
//  FairRotationCandidateRanker.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum FairRotationRankingError: Error, Equatable, Sendable {
    case missingCapacity
    case duplicateParticipant(Player.ID)
    case emptyEligibleParticipantPool
    case candidateMatchTypeMismatch(expected: MatchType, actual: MatchType)
    case unknownParticipant(Player.ID)
    case ineligibleParticipant(Player.ID)
    case invalidProjectionContext
    case invalidProjectedParticipant(Player.ID)
}

nonisolated struct FairRotationCandidateRanker: Sendable {
    func rank(
        candidates: [MatchCandidate],
        request: MatchmakingRequest,
        projection: UpcomingParticipationProjection? = nil
    ) throws -> [MatchSuggestion] {
        if projection != nil, request.schedulingContext != .upcoming {
            throw FairRotationRankingError.invalidProjectionContext
        }
        guard !candidates.isEmpty else { return [] }
        return try assessment(candidates: candidates, request: request, projection: projection).suggestions
    }

    /// Shares one validated history snapshot and comparison policy with exact batch search.
    func assessment(
        candidates: [MatchCandidate],
        request: MatchmakingRequest,
        projection: UpcomingParticipationProjection?
    ) throws -> FairRotationAssessment {
        if projection != nil, request.schedulingContext != .upcoming {
            throw FairRotationRankingError.invalidProjectionContext
        }
        let participantByPlayerID = try validatedParticipants(request.participants)
        let eligibleParticipants = request.participants.filter {
            request.isEligible($0)
        }
        guard !eligibleParticipants.isEmpty else {
            throw FairRotationRankingError.emptyEligibleParticipantPool
        }
        guard let capacity = request.capacity else {
            throw FairRotationRankingError.missingCapacity
        }
        
        let eligiblePlayerIDs = eligibleParticipants.map(\.playerID)
        let eligiblePlayerIDSet = Set(eligiblePlayerIDs)
        for playerID in (projection?.activePlayerIDs ?? []).sorted(by: { $0.uuidString < $1.uuidString }) {
            guard eligiblePlayerIDSet.contains(playerID),
                  let participant = participantByPlayerID[playerID],
                  participant.status == .playing || participant.status == .leavingSoon else {
                throw FairRotationRankingError.invalidProjectedParticipant(playerID)
            }
        }
        let uniqueCandidates = deduplicated(candidates)
        try validate(
            uniqueCandidates,
            request: request,
            participantByPlayerID: participantByPlayerID,
            eligiblePlayerIDs: eligiblePlayerIDSet
        )
        
        let waitingThreshold = try AdaptiveWaitingPolicy().threshold(
            eligibleParticipantCount: eligibleParticipants.count,
            playersPerMatch: request.matchType.playersPerMatch,
            usableCourtCount: capacity.usableCourtCount
        )
        let historySnapshot = HistorySnapshot(
            history: request.history,
            playerIDs: eligiblePlayerIDs,
            projection: projection
        )
        let evaluations = uniqueCandidates.map {
            evaluate(
                $0,
                eligibleParticipants: eligibleParticipants,
                history: historySnapshot,
                waitingThreshold: waitingThreshold
            )
        }
        let explanationContext = ExplanationContext(evaluations: evaluations)
        
        let sortedEvaluations = evaluations.sorted(by: isHigherPriority)
        let suggestions = sortedEvaluations.map {
            MatchSuggestion(
                candidate: $0.candidate,
                reasons: reasons(for: $0, context: explanationContext),
                warnings: warnings(for: $0)
            )
        }
        return FairRotationAssessment(
            suggestions: suggestions, evaluations: sortedEvaluations,
            eligibleParticipants: eligibleParticipants, history: historySnapshot,
            waitingThreshold: waitingThreshold
        )
    }
}

nonisolated private extension FairRotationCandidateRanker {
    func validatedParticipants(
        _ participants: [SessionParticipant]
    ) throws -> [Player.ID: SessionParticipant] {
        var result: [Player.ID: SessionParticipant] = [:]
        for participant in participants {
            guard result.updateValue(participant, forKey: participant.playerID) == nil else {
                throw FairRotationRankingError.duplicateParticipant(participant.playerID)
            }
        }
        return result
    }
    
    func validate(
        _ candidates: [MatchCandidate],
        request: MatchmakingRequest,
        participantByPlayerID: [Player.ID: SessionParticipant],
        eligiblePlayerIDs: Set<Player.ID>
    ) throws {
        for candidate in candidates {
            guard candidate.matchType == request.matchType else {
                throw FairRotationRankingError.candidateMatchTypeMismatch(
                    expected: request.matchType,
                    actual: candidate.matchType
                )
            }
            
            for playerID in candidate.playerIDs {
                guard participantByPlayerID[playerID] != nil else {
                    throw FairRotationRankingError.unknownParticipant(playerID)
                }
                guard eligiblePlayerIDs.contains(playerID) else {
                    throw FairRotationRankingError.ineligibleParticipant(playerID)
                }
            }
        }
    }
    
    func deduplicated(_ candidates: [MatchCandidate]) -> [MatchCandidate] {
        var seen: Set<MatchCandidate> = []
        return candidates.sorted {
            representationKey(for: $0) < representationKey(for: $1)
        }.filter {
            seen.insert($0).inserted
        }
    }
    
    func evaluate(
        _ candidate: MatchCandidate,
        eligibleParticipants: [SessionParticipant],
        history: HistorySnapshot,
        waitingThreshold: WaitingThreshold
    ) -> CandidateEvaluation {
        let selectedPlayerIDs = Set(candidate.playerIDs)
        let participation = participation(
            selectedPlayerIDs: selectedPlayerIDs, eligibleParticipants: eligibleParticipants,
            history: history, waitingThreshold: waitingThreshold
        )
        return CandidateEvaluation(
            candidate: candidate,
            primaryPriority: participation.primaryPriority,
            maximumMatchDeficit: participation.maximumMatchDeficit,
            maximumWaitingExcess: participation.maximumWaitingExcess,
            maximumSelectedRest: participation.maximumSelectedRest,
            partnerRepetition: partnerRepetition(for: candidate, history: history),
            opponentRepetition: opponentRepetition(for: candidate, history: history),
            consecutivePlayCount: candidate.playerIDs.count { playerID in
                let participant = eligibleParticipants.first { $0.playerID == playerID }
                return history.statistics(for: playerID).consecutiveMatches > 0
                || participant?.status == .playing
            },
            canonicalKey: canonicalKey(for: candidate)
        )
    }

    func participation(
        selectedPlayerIDs: Set<Player.ID>,
        eligibleParticipants: [SessionParticipant],
        history: HistorySnapshot,
        waitingThreshold: WaitingThreshold
    ) -> ParticipationEvaluation {
        let projectedMatchCounts = eligibleParticipants.map { participant in
            history.statistics(for: participant.playerID).matchesPlayed
            + (selectedPlayerIDs.contains(participant.playerID) ? 1 : 0)
        }
        let maximumProjectedMatchCount = projectedMatchCounts.max() ?? 0
        
        var maximumMatchDeficit = 0
        var maximumWaitingExcess = 0
        var worstPrimaryDeficit = 0
        var primaryDeficits: [Int] = []
        var aggregatePrimaryDeficit = 0
        var maximumSelectedRest = 0
        
        for (index, participant) in eligibleParticipants.enumerated() {
            let statistics = history.statistics(for: participant.playerID)
            let isSelected = selectedPlayerIDs.contains(participant.playerID)
            let matchDeficit = maximumProjectedMatchCount - projectedMatchCounts[index]
            let projectedRest = isSelected ? 0 : statistics.consecutiveRests + 1
            let waitingExcess = max(
                0,
                projectedRest - waitingThreshold.expectedRestRounds
            )
            let primaryDeficit = max(matchDeficit, waitingExcess)
            
            maximumMatchDeficit = max(maximumMatchDeficit, matchDeficit)
            maximumWaitingExcess = max(maximumWaitingExcess, waitingExcess)
            worstPrimaryDeficit = max(worstPrimaryDeficit, primaryDeficit)
            primaryDeficits.append(primaryDeficit)
            aggregatePrimaryDeficit += matchDeficit + waitingExcess
            
            if isSelected {
                maximumSelectedRest = max(maximumSelectedRest, statistics.consecutiveRests)
            }
        }
        
        let participantsAtWorstDeficit = worstPrimaryDeficit == 0
        ? 0
        : primaryDeficits.count { $0 == worstPrimaryDeficit }
        
        return ParticipationEvaluation(
            primaryPriority: FairRotationPrimaryPriority(
                worstDeficit: worstPrimaryDeficit,
                participantsAtWorstDeficit: participantsAtWorstDeficit,
                aggregateDeficit: aggregatePrimaryDeficit
            ),
            maximumMatchDeficit: maximumMatchDeficit,
            maximumWaitingExcess: maximumWaitingExcess,
            maximumSelectedRest: maximumSelectedRest
        )
    }
    
    func partnerRepetition(
        for candidate: MatchCandidate,
        history: HistorySnapshot
    ) -> Int {
        guard candidate.matchType == .doubles else { return 0 }
        return teamPairs(in: candidate.teamA).reduce(0) {
            $0 + history.partnerCount(between: $1.0, and: $1.1)
        } + teamPairs(in: candidate.teamB).reduce(0) {
            $0 + history.partnerCount(between: $1.0, and: $1.1)
        }
    }
    
    func opponentRepetition(
        for candidate: MatchCandidate,
        history: HistorySnapshot
    ) -> Int {
        candidate.teamA.playerIDs.reduce(0) { total, firstPlayerID in
            total + candidate.teamB.playerIDs.reduce(0) { subtotal, secondPlayerID in
                subtotal + history.opponentCount(
                    between: firstPlayerID,
                    and: secondPlayerID
                )
            }
        }
    }
    
    func teamPairs(in team: Team) -> [(Player.ID, Player.ID)] {
        guard team.playerIDs.count > 1 else { return [] }
        var pairs: [(Player.ID, Player.ID)] = []
        for firstIndex in 0..<(team.playerIDs.count - 1) {
            for secondIndex in (firstIndex + 1)..<team.playerIDs.count {
                pairs.append((team.playerIDs[firstIndex], team.playerIDs[secondIndex]))
            }
        }
        return pairs
    }
    
    func isHigherPriority(
        _ lhs: CandidateEvaluation,
        _ rhs: CandidateEvaluation
    ) -> Bool {
        if lhs.primaryPriority != rhs.primaryPriority {
            return lhs.primaryPriority < rhs.primaryPriority
        }
        if lhs.partnerRepetition != rhs.partnerRepetition {
            return lhs.partnerRepetition < rhs.partnerRepetition
        }
        if lhs.opponentRepetition != rhs.opponentRepetition {
            return lhs.opponentRepetition < rhs.opponentRepetition
        }
        if lhs.consecutivePlayCount != rhs.consecutivePlayCount {
            return lhs.consecutivePlayCount < rhs.consecutivePlayCount
        }
        return lhs.canonicalKey < rhs.canonicalKey
    }
    
    func reasons(
        for evaluation: CandidateEvaluation,
        context: ExplanationContext
    ) -> [SuggestionReason] {
        var reasons: [SuggestionReason] = []
        
        if context.maximumMatchDeficitRange.isImproved(by: evaluation.maximumMatchDeficit) {
            reasons.append(.fewerMatchesPlayed)
        }
        if evaluation.maximumSelectedRest > 0,
           context.maximumSelectedRestRange.isMaximized(by: evaluation.maximumSelectedRest) {
            reasons.append(.longerWaiting)
        }
        if context.maximumWaitingExcessRange.isImproved(by: evaluation.maximumWaitingExcess) {
            reasons.append(.avoidsConsecutiveRest)
        }
        if evaluation.candidate.matchType == .doubles {
            if evaluation.partnerRepetition == 0 {
                reasons.append(.newPartnerCombination)
            } else if context.partnerRepetitionRange.isImproved(by: evaluation.partnerRepetition) {
                reasons.append(.reducedPartnerRepetition)
            }
        }
        if context.opponentRepetitionRange.isImproved(by: evaluation.opponentRepetition) {
            reasons.append(.reducedOpponentRepetition)
        }
        if context.consecutivePlayRange.isImproved(by: evaluation.consecutivePlayCount) {
            reasons.append(.avoidsExcessiveConsecutivePlay)
        }
        
        return reasons
    }
    
    func warnings(for evaluation: CandidateEvaluation) -> [SuggestionWarning] {
        var warnings: [SuggestionWarning] = []
        if evaluation.partnerRepetition > 0 {
            warnings.append(.repeatedPartner)
        }
        if evaluation.opponentRepetition > 0 {
            warnings.append(.repeatedOpponent)
        }
        if evaluation.consecutivePlayCount > 0 {
            warnings.append(.consecutivePlay)
        }
        return warnings
    }
    
    func canonicalKey(for candidate: MatchCandidate) -> String {
        candidate.matchType.rawValue + "|" + [
            playerKey(candidate.teamA.playerIDs),
            playerKey(candidate.teamB.playerIDs)
        ].sorted().joined(separator: "|")
    }
    
    func representationKey(for candidate: MatchCandidate) -> String {
        [
            canonicalKey(for: candidate),
            candidate.teamA.id.uuidString,
            candidate.teamB.id.uuidString,
            candidate.teamA.playerIDs.map(\.uuidString).joined(separator: ":"),
            candidate.teamB.playerIDs.map(\.uuidString).joined(separator: ":")
        ].joined(separator: "|")
    }
    
    func playerKey(_ playerIDs: [Player.ID]) -> String {
        playerIDs.map(\.uuidString).sorted().joined(separator: ":")
    }
}

nonisolated fileprivate struct CandidateEvaluation: Sendable {
    let candidate: MatchCandidate
    let primaryPriority: FairRotationPrimaryPriority
    let maximumMatchDeficit: Int
    let maximumWaitingExcess: Int
    let maximumSelectedRest: Int
    let partnerRepetition: Int
    let opponentRepetition: Int
    let consecutivePlayCount: Int
    let canonicalKey: String
}

/// Internal minimax tuple shared by single-candidate and whole-batch participation evaluation.
nonisolated struct FairRotationPrimaryPriority: Equatable, Comparable, Sendable {
    let worstDeficit: Int
    let participantsAtWorstDeficit: Int
    let aggregateDeficit: Int
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.worstDeficit != rhs.worstDeficit {
            return lhs.worstDeficit < rhs.worstDeficit
        }
        if lhs.participantsAtWorstDeficit != rhs.participantsAtWorstDeficit {
            return lhs.participantsAtWorstDeficit < rhs.participantsAtWorstDeficit
        }
        return lhs.aggregateDeficit < rhs.aggregateDeficit
    }
}

nonisolated private struct ValueRange: Sendable {
    let minimum: Int
    let maximum: Int
    
    func isImproved(by value: Int) -> Bool {
        minimum < maximum && value == minimum
    }
    
    func isMaximized(by value: Int) -> Bool {
        minimum < maximum && value == maximum
    }
}

nonisolated private struct ExplanationContext: Sendable {
    let maximumMatchDeficitRange: ValueRange
    let maximumWaitingExcessRange: ValueRange
    let maximumSelectedRestRange: ValueRange
    let partnerRepetitionRange: ValueRange
    let opponentRepetitionRange: ValueRange
    let consecutivePlayRange: ValueRange
    
    init(evaluations: [CandidateEvaluation]) {
        maximumMatchDeficitRange = ValueRange(
            evaluations.map(\.maximumMatchDeficit)
        )
        maximumWaitingExcessRange = ValueRange(
            evaluations.map(\.maximumWaitingExcess)
        )
        maximumSelectedRestRange = ValueRange(
            evaluations.map(\.maximumSelectedRest)
        )
        partnerRepetitionRange = ValueRange(evaluations.map(\.partnerRepetition))
        opponentRepetitionRange = ValueRange(evaluations.map(\.opponentRepetition))
        consecutivePlayRange = ValueRange(evaluations.map(\.consecutivePlayCount))
    }
}

nonisolated private extension ValueRange {
    init(_ values: [Int]) {
        minimum = values.min() ?? 0
        maximum = values.max() ?? 0
    }
}

nonisolated fileprivate struct HistorySnapshot: Sendable {
    private let statisticsByPlayerID: [Player.ID: ParticipationInputs]
    private let partnerCounts: [PlayerPair: Int]
    private let opponentCounts: [PlayerPair: Int]
    
    init(
        history: ParticipantMatchHistory,
        playerIDs: [Player.ID],
        projection: UpcomingParticipationProjection?
    ) {
        statisticsByPlayerID = Dictionary(
            uniqueKeysWithValues: playerIDs.map {
                ($0, ParticipationInputs(statistics: history.statistics(for: $0),
                                         playerID: $0, projection: projection))
            }
        )
        var partnerCounts: [PlayerPair: Int] = [:]
        var opponentCounts: [PlayerPair: Int] = [:]
        
        for pair in Self.pairs(in: playerIDs) {
            let firstPlayerID = pair.firstPlayerID
            let secondPlayerID = pair.secondPlayerID
            let partnerCount = history.partnerCount(
                between: firstPlayerID,
                and: secondPlayerID
            )
            let opponentCount = history.opponentCount(
                between: firstPlayerID,
                and: secondPlayerID
            )
            if partnerCount > 0 {
                partnerCounts[pair, default: 0] = partnerCount
            }
            if opponentCount > 0 {
                opponentCounts[pair, default: 0] = opponentCount
            }
        }
        
        self.partnerCounts = partnerCounts
        self.opponentCounts = opponentCounts
    }
    
    func statistics(for playerID: Player.ID) -> ParticipationInputs {
        guard let statistics = statisticsByPlayerID[playerID] else {
            preconditionFailure(
                "Validated eligible participant is missing from the history snapshot."
            )
        }
        return statistics
    }
    
    func partnerCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        partnerCounts[PlayerPair(firstPlayerID, secondPlayerID), default: 0]
    }
    
    func opponentCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        opponentCounts[PlayerPair(firstPlayerID, secondPlayerID), default: 0]
    }
    
    static func pairs(in playerIDs: [Player.ID]) -> [PlayerPair] {
        guard playerIDs.count > 1 else { return [] }
        var result: [PlayerPair] = []
        for firstIndex in 0..<(playerIDs.count - 1) {
            for secondIndex in (firstIndex + 1)..<playerIDs.count {
                result.append(PlayerPair(playerIDs[firstIndex], playerIDs[secondIndex]))
            }
        }
        return result
    }
}

nonisolated fileprivate struct ParticipationInputs: Sendable {
    let matchesPlayed: Int
    let consecutiveMatches: Int
    let consecutiveRests: Int

    init(statistics: ParticipantMatchStatistics, playerID: Player.ID,
         projection: UpcomingParticipationProjection?) {
        guard let projection else {
            matchesPlayed = statistics.matchesPlayed
            consecutiveMatches = statistics.consecutiveMatches
            consecutiveRests = statistics.consecutiveRests
            return
        }
        let isActive = projection.activePlayerIDs.contains(playerID)
        matchesPlayed = statistics.matchesPlayed + (isActive ? 1 : 0)
        consecutiveMatches = isActive ? statistics.consecutiveMatches + 1 : 0
        consecutiveRests = isActive ? 0 : statistics.consecutiveRests + 1
    }
}

nonisolated private struct PlayerPair: Hashable, Sendable {
    let firstPlayerID: Player.ID
    let secondPlayerID: Player.ID
    
    init(_ firstPlayerID: Player.ID, _ secondPlayerID: Player.ID) {
        if firstPlayerID.uuidString < secondPlayerID.uuidString {
            self.firstPlayerID = firstPlayerID
            self.secondPlayerID = secondPlayerID
        } else {
            self.firstPlayerID = secondPlayerID
            self.secondPlayerID = firstPlayerID
        }
    }
}

nonisolated private struct ParticipationEvaluation {
    let primaryPriority: FairRotationPrimaryPriority
    let maximumMatchDeficit: Int
    let maximumWaitingExcess: Int
    let maximumSelectedRest: Int
}

/// Request-local assessment; numeric comparison inputs never enter suggestion models.
nonisolated struct FairRotationAssessment: Sendable {
    let suggestions: [MatchSuggestion]
    fileprivate let evaluations: [CandidateEvaluation]
    fileprivate let eligibleParticipants: [SessionParticipant]
    fileprivate let history: HistorySnapshot
    fileprivate let waitingThreshold: WaitingThreshold

    func primaryPriority(selectedPlayerIDs: Set<Player.ID>) -> FairRotationPrimaryPriority {
        FairRotationCandidateRanker().participation(
            selectedPlayerIDs: selectedPlayerIDs, eligibleParticipants: eligibleParticipants,
            history: history, waitingThreshold: waitingThreshold
        ).primaryPriority
    }

    /// Materializes candidate costs alongside metadata in O(candidate count).
    var batchOptions: [FairRotationBatchOption] {
        zip(suggestions, evaluations).map { suggestion, evaluation in
            FairRotationBatchOption(
                suggestion: suggestion, playerIDs: Set(suggestion.candidate.playerIDs),
                secondary: FairRotationSecondaryPriority(
                    partners: evaluation.partnerRepetition, opponents: evaluation.opponentRepetition,
                    consecutivePlay: evaluation.consecutivePlayCount
                ), canonicalKey: evaluation.canonicalKey
            )
        }
    }
}

/// A candidate's additive secondary costs, after whole-batch participation has been compared.
nonisolated struct FairRotationSecondaryPriority: Equatable, Comparable, Sendable {
    var partners = 0
    var opponents = 0
    var consecutivePlay = 0

    func adding(_ other: Self) -> Self {
        Self(partners: partners + other.partners, opponents: opponents + other.opponents,
             consecutivePlay: consecutivePlay + other.consecutivePlay)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.partners != rhs.partners { return lhs.partners < rhs.partners }
        if lhs.opponents != rhs.opponents { return lhs.opponents < rhs.opponents }
        return lhs.consecutivePlay < rhs.consecutivePlay
    }
}

/// Keeps original semantic metadata attached throughout dominance pruning and batch search.
nonisolated struct FairRotationBatchOption: Sendable {
    let suggestion: MatchSuggestion
    let playerIDs: Set<Player.ID>
    let secondary: FairRotationSecondaryPriority
    let canonicalKey: String
}
