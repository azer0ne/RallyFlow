import Foundation

/// An error caused by invalid matchmaking scheduling capacity.
nonisolated enum MatchmakingCapacityError: Error, Equatable, Sendable {
    /// At least one usable court is required.
    case invalidUsableCourtCount(Int)
}

/// The currently usable simultaneous capacity supplied to matchmaking policy.
nonisolated struct MatchmakingCapacity: Codable, Hashable, Sendable {
    /// Courts that can accept a match during the evaluated scheduling opportunity.
    let usableCourtCount: Int

    /// Creates validated scheduling capacity.
    ///
    /// - Throws: `MatchmakingCapacityError` when `usableCourtCount` is not positive.
    init(usableCourtCount: Int) throws {
        guard usableCourtCount > 0 else {
            throw MatchmakingCapacityError.invalidUsableCourtCount(usableCourtCount)
        }
        self.usableCourtCount = usableCourtCount
    }

    private enum CodingKeys: String, CodingKey {
        case usableCourtCount
    }

    /// Decodes and revalidates scheduling capacity.
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

    /// Encodes the validated usable-court count.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usableCourtCount, forKey: .usableCourtCount)
    }
}
