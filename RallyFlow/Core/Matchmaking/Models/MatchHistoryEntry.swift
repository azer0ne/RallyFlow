//
//  MatchHistoryEntry.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum MatchHistoryEntryError: Error, Equatable, Sendable {
    case negativeSequence
    case negativeOpportunitySequence
    case selectedPlayerWasNotEligible
}

nonisolated struct MatchHistoryEntry: Codable, Hashable, Sendable {
    let sequence: Int
    let candidate: MatchCandidate
    let eligiblePlayerIDs: Set<Player.ID>
    /// Explicitly groups simultaneous completions. Nil retains one opportunity per entry.
    let opportunitySequence: Int?
    init(
        sequence: Int,
        candidate: MatchCandidate,
        eligiblePlayerIDs: Set<Player.ID>? = nil,
        opportunitySequence: Int? = nil
    ) throws {
        guard sequence >= 0 else {
            throw MatchHistoryEntryError.negativeSequence
        }
        if let opportunitySequence, opportunitySequence < 0 {
            throw MatchHistoryEntryError.negativeOpportunitySequence
        }
        
        let eligiblePlayerIDs = eligiblePlayerIDs ?? Set(candidate.playerIDs)
        guard eligiblePlayerIDs.isSuperset(of: candidate.playerIDs) else {
            throw MatchHistoryEntryError.selectedPlayerWasNotEligible
        }
        
        self.sequence = sequence
        self.candidate = candidate
        self.eligiblePlayerIDs = eligiblePlayerIDs
        self.opportunitySequence = opportunitySequence
    }
    
    private enum CodingKeys: String, CodingKey {
        case sequence
        case candidate
        case eligiblePlayerIDs
        case opportunitySequence
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
                eligiblePlayerIDs: eligiblePlayerIDs,
                opportunitySequence: container.decodeIfPresent(Int.self, forKey: .opportunitySequence)
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
        try container.encodeIfPresent(opportunitySequence, forKey: .opportunitySequence)
    }
}
