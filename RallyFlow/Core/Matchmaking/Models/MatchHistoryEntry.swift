import Foundation

/// An error caused by invalid completed-match history data.
nonisolated enum MatchHistoryEntryError: Error, Equatable, Sendable {
    /// Match order cannot be represented by a negative sequence.
    case negativeSequence

    /// Every selected player must have been eligible for the recorded rotation.
    case selectedPlayerWasNotEligible
}

/// A completed matchup and the eligibility facts for its rotation.
nonisolated struct MatchHistoryEntry: Codable, Hashable, Sendable {
    /// The monotonic order of the completed matchup within its session.
    let sequence: Int

    /// The player grouping that completed the match.
    let candidate: MatchCandidate

    /// Players who could fairly have been selected for this rotation.
    let eligiblePlayerIDs: Set<Player.ID>

    /// Creates a validated completed-match history entry.
    ///
    /// Passing `nil` for eligibility records only the selected players as eligible,
    /// which preserves relationship history without inferring waiting for others.
    ///
    /// - Throws: `MatchHistoryEntryError` for a negative sequence or inconsistent eligibility.
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

    /// Decodes and revalidates a completed-match history entry.
    ///
    /// - Throws: `DecodingError` when the decoded entry violates a history invariant.
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

    /// Encodes the sequence, candidate, and eligible player identifiers.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(candidate, forKey: .candidate)
        try container.encode(eligiblePlayerIDs, forKey: .eligiblePlayerIDs)
    }
}
