//
//  MatchGenerationDependency.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// The result data required before a match can be generated.
enum MatchGenerationDependency: String, Codable, Sendable {
    /// Match generation does not depend on the current match result.
    case independentOfCurrentResult

    /// Match generation requires standings updated with the current result.
    case requiresUpdatedStandings
}
