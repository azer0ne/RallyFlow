/// The result of applying one rally to a tiebreak score.
nonisolated enum TiebreakProgress: Codable, Hashable, Sendable {
    /// The tiebreak remains in progress at the supplied score.
    case inProgress(TiebreakScore)

    /// The tiebreak completed at the supplied score with the specified winner.
    case completed(score: TiebreakScore, winner: TeamSide)
}
