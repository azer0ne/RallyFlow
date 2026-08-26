//
//  MatchType.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// The number of teams and players participating in a match.
enum MatchType: String, Codable, CaseIterable, Sendable {
    /// A match with one player on each team.
    case singles

    /// A match with two players on each team.
    case doubles

    /// The total number of players required for a match.
    var playersPerMatch: Int {
        switch self {
        case .singles:
            return 2
        case .doubles:
            return 4
        }
    }

    /// The number of players required for each team.
    var playersPerTeam: Int {
        switch self {
        case .singles:
            return 1
        case .doubles:
            return 2
        }
    }
}
