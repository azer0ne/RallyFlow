//
//  SessionParticipant.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

import Foundation

/// Session-specific state for a participating player.
struct SessionParticipant: Identifiable, Codable, Hashable, Sendable {
    /// The participant record's stable identifier.
    let id: UUID

    /// The identifier of the reusable player represented in the session.
    let playerID: Player.ID

    /// The participant's current session availability.
    var status: ParticipantStatus

    /// The number of matches played during the session.
    var matchesPlayed: Int

    /// The number of consecutive matches played.
    var consecutiveMatches: Int

    /// The number of consecutive match rotations rested.
    var consecutiveRests: Int

    /// Creates session-specific state for a player.
    ///
    /// - Parameters:
    ///   - id: The participant record's stable identifier.
    ///   - playerID: The identifier of the reusable player.
    ///   - status: The player's current session availability.
    ///   - matchesPlayed: The number of matches played in this session.
    ///   - consecutiveMatches: The number of consecutive matches played.
    ///   - consecutiveRests: The number of consecutive match rotations rested.
    init(
        id: UUID = UUID(),
        playerID: Player.ID,
        status: ParticipantStatus = .ready,
        matchesPlayed: Int = 0,
        consecutiveMatches: Int = 0,
        consecutiveRests: Int = 0
    ) {
        self.id = id
        self.playerID = playerID
        self.status = status
        self.matchesPlayed = matchesPlayed
        self.consecutiveMatches = consecutiveMatches
        self.consecutiveRests = consecutiveRests
    }
}
