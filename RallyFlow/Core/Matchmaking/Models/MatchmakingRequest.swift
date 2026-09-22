import Foundation

/// The source used to determine which request participants may be combined.
nonisolated enum MatchmakingEligibility: Codable, Hashable, Sendable {
    /// Uses only participants whose status is `ready`.
    case readyParticipants

    /// Uses a caller-supplied set of player identifiers.
    case explicit(playerIDs: Set<Player.ID>)
}

/// The domain input required to enumerate potential matchups.
nonisolated struct MatchmakingRequest: Codable, Hashable, Sendable {
    /// The required number of players per team.
    let matchType: MatchType

    /// Whether the candidates are intended for immediate or later play.
    let schedulingContext: SchedulingContext

    /// Session participant state available to candidate generation.
    let participants: [SessionParticipant]

    /// The policy-free description of the participant pool to consider.
    let eligibility: MatchmakingEligibility

    /// Completed-match facts available to later candidate evaluation.
    let history: ParticipantMatchHistory

    /// Creates a candidate-generation request.
    init(
        matchType: MatchType,
        schedulingContext: SchedulingContext,
        participants: [SessionParticipant],
        eligibility: MatchmakingEligibility = .readyParticipants,
        history: ParticipantMatchHistory = ParticipantMatchHistory()
    ) {
        self.matchType = matchType
        self.schedulingContext = schedulingContext
        self.participants = participants
        self.eligibility = eligibility
        self.history = history
    }
}
