//
//  ScoreEvent.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum ScoreEvent: Codable, Hashable, Sendable {
    case teamAWonRally
    case teamBWonRally
    case undo
}
