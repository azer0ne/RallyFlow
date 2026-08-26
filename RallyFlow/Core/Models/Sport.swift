//
//  Sport.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// A racket sport supported by RallyFlow.
enum Sport: String, Codable, CaseIterable, Sendable {
    /// Tennis.
    case tennis

    /// Padel.
    case padel

    /// Badminton.
    case badminton

    /// Pickleball.
    case pickleball
}
