//
//  Team.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

import Foundation

/// A grouping of players participating together in a match.
struct Team: Identifiable, Codable, Hashable, Sendable {
    /// The team's stable identifier.
    let id: UUID

    /// The identifiers of the players grouped into the team.
    let playerIDs: [Player.ID]

    /// Creates a team from a group of player identifiers.
    ///
    /// - Parameters:
    ///   - id: The team's stable identifier.
    ///   - playerIDs: The identifiers of the players in the team.
    init(
        id: UUID = UUID(),
        playerIDs: [Player.ID]
    ) {
        self.id = id
        self.playerIDs = playerIDs
    }
}
