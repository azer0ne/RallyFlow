//
//  Player.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

import Foundation

/// Reusable identity and profile data for a player.
struct Player: Identifiable, Codable, Hashable, Sendable {
    /// The player's stable identifier.
    let id: UUID

    /// The player's name.
    var name: String

    /// Creates a player with a generated identifier by default.
    ///
    /// - Parameters:
    ///   - id: The player's stable identifier.
    ///   - name: The player's name.
    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }
}
