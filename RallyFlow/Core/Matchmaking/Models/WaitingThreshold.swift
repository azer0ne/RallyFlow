/// Capacity-derived context for interpreting eligible waiting streaks.
nonisolated struct WaitingThreshold: Codable, Hashable, Sendable {
    /// Participants considered for the scheduling opportunity.
    let eligibleParticipantCount: Int

    /// Participants who can play simultaneously on the usable courts.
    let simultaneousPlayerCapacity: Int

    /// Expected resting opportunities under the synchronized-round approximation.
    let expectedRestRounds: Int
}
