import Foundation

/// An error caused by a structurally invalid potential matchup.
nonisolated enum MatchCandidateError: Error, Equatable, Sendable {
    /// A team does not contain the number of players required by the match type.
    case invalidTeamSize(expected: Int, actual: Int)

    /// A player appears more than once across the matchup.
    case duplicatePlayer
}

/// A structurally valid potential matchup with no scheduling or lifecycle state.
nonisolated struct MatchCandidate: Codable, Sendable {
    /// The number of players expected on each side.
    let matchType: MatchType

    /// One side of the potential matchup.
    let teamA: Team

    /// The opposing side of the potential matchup.
    let teamB: Team

    /// Every player in the matchup, preserving side and team-member order.
    ///
    /// - Complexity: O(n), where `n` is the number of players in the matchup.
    var playerIDs: [Player.ID] {
        teamA.playerIDs + teamB.playerIDs
    }

    /// Creates a potential matchup after validating team sizes and player uniqueness.
    ///
    /// Team identity is retained for compatibility with the existing `Team` model, but
    /// candidate equality is based on player groupings because swapping sides does not
    /// create a different matchup.
    ///
    /// - Throws: `MatchCandidateError` when a team has the wrong size or a player repeats.
    init(matchType: MatchType, teamA: Team, teamB: Team) throws {
        let expectedTeamSize = matchType.playersPerTeam
        guard teamA.playerIDs.count == expectedTeamSize else {
            throw MatchCandidateError.invalidTeamSize(
                expected: expectedTeamSize,
                actual: teamA.playerIDs.count
            )
        }
        guard teamB.playerIDs.count == expectedTeamSize else {
            throw MatchCandidateError.invalidTeamSize(
                expected: expectedTeamSize,
                actual: teamB.playerIDs.count
            )
        }

        let playerIDs = teamA.playerIDs + teamB.playerIDs
        guard Set(playerIDs).count == playerIDs.count else {
            throw MatchCandidateError.duplicatePlayer
        }

        self.matchType = matchType
        self.teamA = teamA
        self.teamB = teamB
    }

    /// Returns whether the matchup contains the specified player.
    ///
    /// - Complexity: O(n), where `n` is the number of players in the matchup.
    func contains(playerID: Player.ID) -> Bool {
        teamA.playerIDs.contains(playerID) || teamB.playerIDs.contains(playerID)
    }

    private enum CodingKeys: String, CodingKey {
        case matchType
        case teamA
        case teamB
    }

    /// Decodes and revalidates a potential matchup.
    ///
    /// - Throws: `DecodingError` when decoded teams do not form a valid candidate.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let matchType = try container.decode(MatchType.self, forKey: .matchType)
        let teamA = try container.decode(Team.self, forKey: .teamA)
        let teamB = try container.decode(Team.self, forKey: .teamB)

        do {
            try self.init(matchType: matchType, teamA: teamA, teamB: teamB)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .teamA,
                in: container,
                debugDescription: "Decoded teams do not form a valid match candidate."
            )
        }
    }

    /// Encodes the match type and both teams.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchType, forKey: .matchType)
        try container.encode(teamA, forKey: .teamA)
        try container.encode(teamB, forKey: .teamB)
    }
}

nonisolated extension MatchCandidate: Equatable {
    /// Returns whether two candidates contain the same opposing player groups.
    static func == (lhs: MatchCandidate, rhs: MatchCandidate) -> Bool {
        lhs.matchType == rhs.matchType && lhs.canonicalTeamKeys == rhs.canonicalTeamKeys
    }
}

nonisolated extension MatchCandidate: Hashable {
    /// Hashes the player groupings without making team side or `Team` identity significant.
    func hash(into hasher: inout Hasher) {
        hasher.combine(matchType)
        hasher.combine(canonicalTeamKeys)
    }
}

nonisolated private extension MatchCandidate {
    var canonicalTeamKeys: [String] {
        [teamKey(for: teamA), teamKey(for: teamB)].sorted()
    }

    func teamKey(for team: Team) -> String {
        team.playerIDs.map(\.uuidString).sorted().joined(separator: ":")
    }
}
