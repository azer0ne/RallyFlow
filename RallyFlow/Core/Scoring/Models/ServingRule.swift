//
//  ServingRule.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The serving structure used by a match.
nonisolated enum ServingRule: Codable, Hashable, Sendable {
    /// The sport's standard serving structure.
    case standard

    /// Each player in a doubles match serves one game.
    case eachDoublesPlayerServesOnce

    /// Pickleball doubles serving structure.
    case pickleballDoubles

    /// Serving state is controlled manually.
    case manual
}
