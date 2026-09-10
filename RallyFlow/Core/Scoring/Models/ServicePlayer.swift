//
//  ServicePlayer.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated struct ServicePlayer: Codable, Hashable, Sendable {
    let playerID: Player.ID
    let side: TeamSide
}
