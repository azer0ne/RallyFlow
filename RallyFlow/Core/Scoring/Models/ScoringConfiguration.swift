//
//  ScoringConfiguration.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

import Foundation

/// A composition of the rules required to score a match.
nonisolated struct ScoringConfiguration: Codable, Hashable, Sendable {
    /// The high-level scoring family.
    let style: ScoringStyle

    /// The system used to count points.
    let pointSystem: PointSystem

    /// The structure that determines when the match ends.
    let matchStructure: MatchStructure

    /// The rule used to resolve deuce, when applicable.
    let deuceRule: DeuceRule?

    /// The rule used to resolve a final tie, when applicable.
    let tieRule: TieRule?

    /// The match's serving structure.
    let servingRule: ServingRule

    /// Creates a validated scoring configuration.
    ///
    /// - Parameters:
    ///   - style: The high-level scoring family.
    ///   - pointSystem: The point-counting system.
    ///   - matchStructure: The structure that determines when the match ends.
    ///   - deuceRule: The rule used to resolve deuce, when applicable.
    ///   - tieRule: The rule used to resolve a final tie, when applicable.
    ///   - servingRule: The match's serving structure.
    /// - Throws: ``ScoringConfigurationError`` when a numeric rule is invalid.
    init(
        style: ScoringStyle,
        pointSystem: PointSystem,
        matchStructure: MatchStructure,
        deuceRule: DeuceRule? = nil,
        tieRule: TieRule? = nil,
        servingRule: ServingRule
    ) throws {
        try matchStructure.validate()
        try tieRule?.validate()

        self.style = style
        self.pointSystem = pointSystem
        self.matchStructure = matchStructure
        self.deuceRule = deuceRule
        self.tieRule = tieRule
        self.servingRule = servingRule
    }

    /// Creates a validated scoring configuration by decoding serialized data.
    ///
    /// - Parameter decoder: The decoder containing the serialized configuration.
    /// - Throws: A decoding error when the data is malformed or contains invalid rules.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let style = try container.decode(ScoringStyle.self, forKey: .style)
        let pointSystem = try container.decode(PointSystem.self, forKey: .pointSystem)
        let matchStructure = try container.decode(MatchStructure.self, forKey: .matchStructure)
        let deuceRule = try container.decodeIfPresent(DeuceRule.self, forKey: .deuceRule)
        let tieRule = try container.decodeIfPresent(TieRule.self, forKey: .tieRule)
        let servingRule = try container.decode(ServingRule.self, forKey: .servingRule)

        do {
            try self.init(
                style: style,
                pointSystem: pointSystem,
                matchStructure: matchStructure,
                deuceRule: deuceRule,
                tieRule: tieRule,
                servingRule: servingRule
            )
        } catch let error as ScoringConfigurationError {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid scoring configuration: \(error)"
                )
            )
        }
    }
}

private extension MatchStructure {
    /// Validates numeric values that would make the structure impossible to play.
    nonisolated func validate() throws {
        switch self {
        case .fixedGames(let count):
            guard count > 0 else {
                throw ScoringConfigurationError.invalidCount
            }

        case .raceToGames(let target):
            guard target > 0 else {
                throw ScoringConfigurationError.invalidTarget
            }

        case let .bestOfGames(count, pointsPerGame, winBy, cap):
            guard count > 0 else {
                throw ScoringConfigurationError.invalidCount
            }
            try validatePointTarget(pointsPerGame, winBy: winBy, cap: cap)

        case let .bestOfSets(count, setRules):
            guard count > 0 else {
                throw ScoringConfigurationError.invalidCount
            }
            guard count.isMultiple(of: 2) == false else {
                throw ScoringConfigurationError.invalidBestOfCount
            }
            try setRules.validate()

        case let .raceToPoints(target, winBy, cap):
            try validatePointTarget(target, winBy: winBy, cap: cap)

        case .fixedTotalPoints(let total):
            guard total > 0 else {
                throw ScoringConfigurationError.invalidTarget
            }

        case .timed(let durationSeconds):
            guard durationSeconds > 0 else {
                throw ScoringConfigurationError.invalidDuration
            }
        }
    }

    /// Validates a point target, winning margin, and optional cap.
    nonisolated func validatePointTarget(_ target: Int, winBy: Int, cap: Int?) throws {
        guard target > 0 else {
            throw ScoringConfigurationError.invalidTarget
        }
        guard winBy > 0 else {
            throw ScoringConfigurationError.invalidWinBy
        }
        guard cap.map({ $0 >= target }) ?? true else {
            throw ScoringConfigurationError.invalidCap
        }
    }
}

private extension SetRules {
    /// Validates set and optional tiebreak values.
    nonisolated func validate() throws {
        guard gamesToWin > 0, winByGames > 0 else {
            throw ScoringConfigurationError.invalidSetRules
        }

        switch (tiebreakAt, tiebreakTarget, tiebreakWinBy) {
        case (nil, nil, nil):
            return
        case let (.some(tiebreakAt), .some(tiebreakTarget), .some(tiebreakWinBy))
            where tiebreakAt > 0 && tiebreakTarget > 0 && tiebreakWinBy > 0:
            return
        default:
            throw ScoringConfigurationError.invalidSetRules
        }
    }
}

private extension TieRule {
    /// Validates associated numeric tie-breaking values.
    nonisolated func validate() throws {
        switch self {
        case .draw, .decidingGame:
            return
        case let .tiebreak(target, winBy):
            guard target > 0 else {
                throw ScoringConfigurationError.invalidTarget
            }
            guard winBy > 0 else {
                throw ScoringConfigurationError.invalidWinBy
            }
        case .continueUntilLead(let lead):
            guard lead > 0 else {
                throw ScoringConfigurationError.invalidWinBy
            }
        }
    }
}
