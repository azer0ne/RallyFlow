/// A validated active grouping expected to finish before the evaluated upcoming slot.
nonisolated struct ActiveMatchSnapshot: Codable, Hashable, Sendable {
    let candidate: MatchCandidate

    var playerIDs: [Player.ID] { candidate.playerIDs }
}
