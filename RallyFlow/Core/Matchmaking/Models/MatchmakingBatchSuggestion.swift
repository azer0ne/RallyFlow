/// Exclusive assignments within this value only; independent calls do not reserve players.
nonisolated struct MatchmakingBatchSuggestion: Hashable, Sendable {
    let schedulingContext: SchedulingContext
    let matchType: MatchType
    let assignments: [MatchmakingSlotAssignment]
}

/// A suggested matchup for a court, with active-player markers captured at generation time.
nonisolated struct MatchmakingSlotAssignment: Hashable, Sendable {
    let slot: MatchmakingSlot
    let suggestion: MatchSuggestion
    let projectedPlayingPlayerIDs: Set<Player.ID>
}

/// Legality of an existing batch, independent of its current fairness rank.
nonisolated enum MatchmakingBatchValidity: Equatable, Sendable {
    case valid
    case invalid(MatchmakingBatchInvalidity)
}

/// The first structural or availability conflict, identifying the affected court when applicable.
nonisolated enum MatchmakingBatchInvalidity: Equatable, Sendable {
    case schedulingContextChanged
    case matchTypeChanged
    case slotUnavailable(Court.ID)
    case duplicateSlot(Court.ID)
    case duplicatePlayer(Player.ID, courtID: Court.ID)
    case invalidAssignment(courtID: Court.ID, reason: UpcomingSuggestionInvalidity)
}
