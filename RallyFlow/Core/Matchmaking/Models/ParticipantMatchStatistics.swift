//
//  ParticipantMatchStatistics.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated struct ParticipantMatchStatistics: Codable, Hashable, Sendable {
    let matchesPlayed: Int
    let waitingRounds: Int
    let consecutiveMatches: Int
    let consecutiveRests: Int
    let lastPlayedSequence: Int?
}
