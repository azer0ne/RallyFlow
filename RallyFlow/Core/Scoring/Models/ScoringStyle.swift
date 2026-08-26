//
//  ScoringStyle.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// A high-level family of scoring rules.
nonisolated enum ScoringStyle: String, Codable, CaseIterable, Sendable {
    /// Tennis point notation and game progression.
    case tennis

    /// A system in which every rally awards a point.
    case rally

    /// A system in which pickleball points depend on the serving state.
    case pickleballSideOut

    /// A match whose end is determined by elapsed time.
    case timed
}
