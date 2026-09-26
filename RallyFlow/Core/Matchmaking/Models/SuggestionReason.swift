//
//  SuggestionReason.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated enum SuggestionReason: String, Codable, CaseIterable, Hashable, Sendable {
    case fewerMatchesPlayed
    case longerWaiting
    case newPartnerCombination
    case reducedPartnerRepetition
    case reducedOpponentRepetition
    case avoidsConsecutiveRest
    case avoidsExcessiveConsecutivePlay
    case generatedFromUpdatedStandings
}
