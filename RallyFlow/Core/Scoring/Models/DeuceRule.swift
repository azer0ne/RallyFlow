//
//  DeuceRule.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The rule used to resolve deuce.
nonisolated enum DeuceRule: String, Codable, CaseIterable, Sendable {
    /// A team must gain advantage before winning the game.
    case advantage

    /// The next point at deuce decides the game.
    case noAd
}
