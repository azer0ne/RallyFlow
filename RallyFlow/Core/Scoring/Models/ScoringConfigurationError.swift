//
//  ScoringConfigurationError.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum ScoringConfigurationError: Error, Equatable, Sendable {
    case invalidServiceOrder
    case invalidOneServeEachRules
    case invalidCount
    case invalidBestOfCount
    case invalidTarget
    case invalidWinBy
    case invalidCap
    case invalidDuration
    case invalidSetRules
}
