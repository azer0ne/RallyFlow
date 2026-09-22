/// A factual concern associated with a match suggestion.
nonisolated enum SuggestionWarning: String, Codable, CaseIterable, Hashable, Sendable {
    /// At least one partner pairing has occurred before.
    case repeatedPartner

    /// At least one opponent pairing has occurred before.
    case repeatedOpponent

    /// At least one participant would play consecutively.
    case consecutivePlay

    /// The eligible pool cannot produce enough previously unseen combinations.
    case insufficientFreshCombinations
}
