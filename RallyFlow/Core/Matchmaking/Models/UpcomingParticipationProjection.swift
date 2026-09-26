/// One assumed opportunity before the candidate, separate from completed history.
/// Other eligible players are treated as waiting for that opportunity.
nonisolated struct UpcomingParticipationProjection: Hashable, Sendable {
    let activePlayerIDs: Set<Player.ID>
}
