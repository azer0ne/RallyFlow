/// A factual reason that may support a match suggestion.
nonisolated enum SuggestionReason: String, Codable, CaseIterable, Hashable, Sendable {
    /// The candidate includes participants with fewer completed matches.
    case fewerMatchesPlayed

    /// The candidate includes participants who have waited longer.
    case longerWaiting

    /// The candidate creates a partner pairing not previously played.
    case newPartnerCombination

    /// The candidate reduces repetition between partners.
    case reducedPartnerRepetition

    /// The candidate reduces repetition between opponents.
    case reducedOpponentRepetition

    /// The candidate prevents an eligible participant from resting again.
    case avoidsConsecutiveRest

    /// The candidate avoids extending an excessive run of consecutive matches.
    case avoidsExcessiveConsecutivePlay

    /// The candidate uses standings that include the latest completed result.
    case generatedFromUpdatedStandings
}
