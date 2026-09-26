//
//  MatchSuggestion.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated struct MatchSuggestion: Codable, Hashable, Sendable {
    let candidate: MatchCandidate
    let reasons: [SuggestionReason]
    let warnings: [SuggestionWarning]
    
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
