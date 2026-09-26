//
//  MatchmakingCapacity.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum MatchmakingCapacityError: Error, Equatable, Sendable {
    case invalidUsableCourtCount(Int)
}

nonisolated struct MatchmakingCapacity: Codable, Hashable, Sendable {
    let usableCourtCount: Int
    init(usableCourtCount: Int) throws {
        guard usableCourtCount > 0 else {
            throw MatchmakingCapacityError.invalidUsableCourtCount(usableCourtCount)
        }
        self.usableCourtCount = usableCourtCount
    }
    
    private enum CodingKeys: String, CodingKey {
        case usableCourtCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let usableCourtCount = try container.decode(Int.self, forKey: .usableCourtCount)
        
        do {
            try self.init(usableCourtCount: usableCourtCount)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .usableCourtCount,
                in: container,
                debugDescription: "Usable court count must be positive."
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usableCourtCount, forKey: .usableCourtCount)
    }
}
