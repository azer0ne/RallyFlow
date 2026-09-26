//
//  WaitingThreshold.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated struct WaitingThreshold: Codable, Hashable, Sendable {
    let eligibleParticipantCount: Int
    let simultaneousPlayerCapacity: Int
    let expectedRestRounds: Int
}
