//
//  SuggestionWarning.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated enum SuggestionWarning: String, Codable, CaseIterable, Hashable, Sendable {
    case repeatedPartner
    case repeatedOpponent
    case consecutivePlay
    case insufficientFreshCombinations
}
