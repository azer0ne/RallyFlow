/// Factual participation data derived from completed matchmaking history.
nonisolated struct ParticipantMatchStatistics: Codable, Hashable, Sendable {
    /// The number of completed matches containing the player.
    let matchesPlayed: Int

    /// The total rotations in which the player was eligible but not selected.
    let waitingRounds: Int

    /// The current run of consecutive completed matches containing the player.
    let consecutiveMatches: Int

    /// The current run of eligible rotations in which the player was not selected.
    let consecutiveRests: Int

    /// The sequence of the player's most recently completed match.
    let lastPlayedSequence: Int?
}
