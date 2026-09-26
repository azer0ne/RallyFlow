/// A tentative decision with availability markers captured at generation time, not a reservation.
nonisolated struct UpcomingMatchSuggestion: Hashable, Sendable {
    let suggestion: MatchSuggestion
    let projectedPlayingPlayerIDs: Set<Player.ID>

    init(suggestion: MatchSuggestion, activePlayerIDs: Set<Player.ID>) {
        self.suggestion = suggestion
        projectedPlayingPlayerIDs = activePlayerIDs.intersection(suggestion.candidate.playerIDs)
    }
}

nonisolated enum UpcomingSuggestionValidity: Equatable, Sendable {
    case valid
    case invalid(UpcomingSuggestionInvalidity)
}

nonisolated enum UpcomingSuggestionInvalidity: Equatable, Sendable {
    case matchTypeChanged
    case missingParticipant(Player.ID)
    case participantNoLongerEligible(Player.ID)
}
