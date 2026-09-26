//
//  MatchCandidate.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum MatchCandidateError: Error, Equatable, Sendable {
    case invalidTeamSize(expected: Int, actual: Int)
    case duplicatePlayer
}

nonisolated struct MatchCandidate: Codable, Sendable {
    let matchType: MatchType
    let teamA: Team
    let teamB: Team
    var playerIDs: [Player.ID] {
        teamA.playerIDs + teamB.playerIDs
    }
    
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
    
    func contains(playerID: Player.ID) -> Bool {
        teamA.playerIDs.contains(playerID) || teamB.playerIDs.contains(playerID)
    }
    
    private enum CodingKeys: String, CodingKey {
        case matchType
        case teamA
        case teamB
    }
    
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchType, forKey: .matchType)
        try container.encode(teamA, forKey: .teamA)
        try container.encode(teamB, forKey: .teamB)
    }
}

nonisolated extension MatchCandidate: Equatable {
    static func == (lhs: MatchCandidate, rhs: MatchCandidate) -> Bool {
        lhs.matchType == rhs.matchType && lhs.canonicalTeamKeys == rhs.canonicalTeamKeys
    }
}

nonisolated extension MatchCandidate: Hashable {
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
