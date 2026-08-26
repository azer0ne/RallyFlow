//
//  PointSystem.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The point-counting system used within a match.
nonisolated enum PointSystem: Codable, Hashable, Sendable {
    /// Tennis point notation and game progression.
    case tennis

    /// One point awarded for every rally.
    case rally

    /// Pickleball scoring in which only the serving side may score.
    case pickleballSideOut
}
