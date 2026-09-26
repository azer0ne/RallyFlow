//
//  MatchHistoryEntry.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum MatchHistoryEntryError: Error, Equatable, Sendable {
    case negativeSequence
    case selectedPlayerWasNotEligible
}

nonisolated struct MatchHistoryEntry: Codable, Hashable, Sendable {
    let sequence: Int
    let candidate: MatchCandidate
    let eligiblePlayerIDs: Set<Player.ID>
    init(
        sequence: Int,
        candidate: MatchCandidate,
        eligiblePlayerIDs: Set<Player.ID>? = nil
    ) throws {
        guard sequence >= 0 else {
            throw MatchHistoryEntryError.negativeSequence
        }
        
        let eligiblePlayerIDs = eligiblePlayerIDs ?? Set(candidate.playerIDs)
        guard eligiblePlayerIDs.isSuperset(of: candidate.playerIDs) else {
            throw MatchHistoryEntryError.selectedPlayerWasNotEligible
        }
        
        self.sequence = sequence
        self.candidate = candidate
        self.eligiblePlayerIDs = eligiblePlayerIDs
    }
    
    private enum CodingKeys: String, CodingKey {
        case sequence
        case candidate
        case eligiblePlayerIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sequence = try container.decode(Int.self, forKey: .sequence)
        let candidate = try container.decode(MatchCandidate.self, forKey: .candidate)
        let eligiblePlayerIDs = try container.decode(
            Set<Player.ID>.self,
            forKey: .eligiblePlayerIDs
        )
        
        do {
            try self.init(
                sequence: sequence,
                candidate: candidate,
                eligiblePlayerIDs: eligiblePlayerIDs
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .eligiblePlayerIDs,
                in: container,
                debugDescription: "Decoded match history entry is invalid."
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(candidate, forKey: .candidate)
        try container.encode(eligiblePlayerIDs, forKey: .eligiblePlayerIDs)
    }
}
