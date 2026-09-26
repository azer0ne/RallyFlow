//
//  MatchmakingRequest.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum MatchmakingEligibility: Codable, Hashable, Sendable {
    case readyParticipants
    case explicit(playerIDs: Set<Player.ID>)
}

nonisolated struct MatchmakingRequest: Codable, Hashable, Sendable {
    let matchType: MatchType
    let schedulingContext: SchedulingContext
    let participants: [SessionParticipant]
    let eligibility: MatchmakingEligibility
    let history: ParticipantMatchHistory
    let capacity: MatchmakingCapacity?
    
    init(
        matchType: MatchType,
        schedulingContext: SchedulingContext,
        participants: [SessionParticipant],
        eligibility: MatchmakingEligibility = .readyParticipants,
        history: ParticipantMatchHistory = ParticipantMatchHistory(),
        capacity: MatchmakingCapacity? = nil
    ) {
        self.matchType = matchType
        self.schedulingContext = schedulingContext
        self.participants = participants
        self.eligibility = eligibility
        self.history = history
        self.capacity = capacity
    }

    /// Upcoming playing/leaving-soon participants require explicit authorization.
    /// Immediate requests never admit those statuses, even through an explicit whitelist.
    func isEligible(_ participant: SessionParticipant) -> Bool {
        if case .explicit(let playerIDs) = eligibility,
           !playerIDs.contains(participant.playerID) {
            return false
        }
        switch participant.status {
        case .ready:
            return true
        case .playing, .leavingSoon:
            guard schedulingContext == .upcoming else { return false }
            if case .explicit = eligibility { return true }
            return false
        case .resting, .unavailable, .left:
            return false
        }
    }
}
