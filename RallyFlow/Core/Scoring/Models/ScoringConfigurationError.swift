//
//  ScoringConfigurationError.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// An error caused by a clearly invalid numeric scoring configuration.
nonisolated enum ScoringConfigurationError: Error, Equatable, Sendable {
    /// A game or set count is not positive.
    case invalidCount

    /// A point or game target is not positive.
    case invalidTarget

    /// A required winning margin is not positive.
    case invalidWinBy

    /// A point cap is not positive or is below its target.
    case invalidCap

    /// A timed match duration is not positive.
    case invalidDuration

    /// Set rules contain an invalid or incomplete tiebreak definition.
    case invalidSetRules
}
