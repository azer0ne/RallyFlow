/// One caller-designated schedulable court, without live ownership or lifecycle state.
nonisolated struct MatchmakingSlot: Codable, Hashable, Sendable {
    let courtID: Court.ID
}
