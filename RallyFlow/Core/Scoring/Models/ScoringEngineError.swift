//
//  ScoringEngineError.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum ScoringEngineError: Error, Equatable, Sendable {
    case emptyHistory
    case unsupportedMatchStructure
    case incompatiblePointSystem
    case incompatibleScoreState
    case missingDeuceRule
    case unsupportedEvent
    case gameAlreadyComplete
    case missingSetRules
    case gameNotComplete
    case invalidTiebreakConfiguration
    case invalidTiebreakState
    case tiebreakAlreadyComplete
    case matchAlreadyCompleted
    case invalidCompletedSet
    case invalidMatchState
}
