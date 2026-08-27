/// A deterministic engine for configurable tennis tiebreak point progression.
nonisolated struct TennisTiebreakEngine: Sendable {
    /// Creates a stateless tennis tiebreak engine.
    init() {}

    /// Returns the progress produced by applying one rally to a tiebreak.
    ///
    /// - Parameters:
    ///   - event: The rally-winning event to apply.
    ///   - score: The tiebreak score before the rally.
    ///   - target: The minimum points required to win.
    ///   - winBy: The point lead required to win.
    /// - Returns: Updated in-progress or completed tiebreak state.
    /// - Throws: ``ScoringEngineError`` when the event or configuration is invalid.
    nonisolated func apply(
        event: ScoreEvent,
        to score: TiebreakScore,
        target: Int,
        winBy: Int
    ) throws -> TiebreakProgress {
        guard target > 0, winBy > 0 else {
            throw ScoringEngineError.invalidTiebreakConfiguration
        }
        guard winner(
            teamAPoints: score.teamAPoints,
            teamBPoints: score.teamBPoints,
            target: target,
            winBy: winBy
        ) == nil else {
            throw ScoringEngineError.tiebreakAlreadyComplete
        }

        var updatedScore = score
        switch event {
        case .teamAWonRally:
            updatedScore.teamAPoints += 1
        case .teamBWonRally:
            updatedScore.teamBPoints += 1
        case .undo:
            throw ScoringEngineError.unsupportedEvent
        }

        if let winner = winner(
            teamAPoints: updatedScore.teamAPoints,
            teamBPoints: updatedScore.teamBPoints,
            target: target,
            winBy: winBy
        ) {
            return .completed(score: updatedScore, winner: winner)
        }
        return .inProgress(updatedScore)
    }
}

private extension TennisTiebreakEngine {
    /// Returns the winning team when the target and winning margin are satisfied.
    nonisolated func winner(
        teamAPoints: Int,
        teamBPoints: Int,
        target: Int,
        winBy: Int
    ) -> TeamSide? {
        let lead = teamAPoints - teamBPoints
        if teamAPoints >= target, lead >= winBy {
            return .teamA
        }
        if teamBPoints >= target, -lead >= winBy {
            return .teamB
        }
        return nil
    }
}
