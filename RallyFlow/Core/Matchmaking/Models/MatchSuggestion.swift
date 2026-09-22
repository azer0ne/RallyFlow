/// A semantically explained candidate selection with no numeric quality metric.
nonisolated struct MatchSuggestion: Codable, Hashable, Sendable {
    /// The selected potential matchup.
    let candidate: MatchCandidate

    /// Facts that support suggesting the candidate, ordered for presentation mapping.
    let reasons: [SuggestionReason]

    /// Facts the host may want to consider before accepting the candidate.
    let warnings: [SuggestionWarning]

    /// Creates an explained suggestion for a candidate.
    init(
        candidate: MatchCandidate,
        reasons: [SuggestionReason] = [],
        warnings: [SuggestionWarning] = []
    ) {
        self.candidate = candidate
        self.reasons = reasons
        self.warnings = warnings
    }
}
