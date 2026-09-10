//
//  DoublesServiceOrder.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated struct DoublesServiceOrder: Codable, Hashable, Sendable {
    let players: [ServicePlayer]
    
    init(players: [ServicePlayer]) throws {
        guard players.count == 4,
              Set(players.map(\.playerID)).count == 4,
              players[0].side == players[2].side,
              players[1].side == players[3].side,
              players[0].side != players[1].side else {
            throw ScoringConfigurationError.invalidServiceOrder
        }
        self.players = players
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(players: container.decode([ServicePlayer].self, forKey: .players))
    }
}
