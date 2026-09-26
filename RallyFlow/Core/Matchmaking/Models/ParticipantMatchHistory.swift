//
//  ParticipantMatchHistory.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated enum ParticipantMatchHistoryError: Error, Equatable, Sendable {
    case duplicateSequence(Int)
}

nonisolated struct ParticipantMatchHistory: Codable, Hashable, Sendable {
    let entries: [MatchHistoryEntry]
    
    init() {
        entries = []
    }
    
    init(entries: [MatchHistoryEntry]) throws {
        var sequences: Set<Int> = []
        for entry in entries {
            guard sequences.insert(entry.sequence).inserted else {
                throw ParticipantMatchHistoryError.duplicateSequence(entry.sequence)
            }
        }
        self.entries = entries.sorted { $0.sequence < $1.sequence }
    }
    
    func matchesPlayed(for playerID: Player.ID) -> Int {
        entries.count { $0.candidate.contains(playerID: playerID) }
    }
    
    func partnerCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        guard firstPlayerID != secondPlayerID else { return 0 }
        return entries.count {
            arePartners(firstPlayerID, secondPlayerID, in: $0.candidate)
        }
    }
    
    func opponentCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        guard firstPlayerID != secondPlayerID else { return 0 }
        return entries.count {
            areOpponents(firstPlayerID, secondPlayerID, in: $0.candidate)
        }
    }
    
    func lastPlayedSequence(for playerID: Player.ID) -> Int? {
        entries.last { $0.candidate.contains(playerID: playerID) }?.sequence
    }
    
    func werePartnersInMostRecentSharedMatch(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID
    ) -> Bool {
        guard let candidate = mostRecentSharedCandidate(firstPlayerID, secondPlayerID) else {
            return false
        }
        return arePartners(firstPlayerID, secondPlayerID, in: candidate)
    }
    
    func wereOpponentsInMostRecentSharedMatch(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID
    ) -> Bool {
        guard let candidate = mostRecentSharedCandidate(firstPlayerID, secondPlayerID) else {
            return false
        }
        return areOpponents(firstPlayerID, secondPlayerID, in: candidate)
    }
    
    func statistics(for playerID: Player.ID) -> ParticipantMatchStatistics {
        var matchesPlayed = 0
        var waitingRounds = 0
        var consecutiveMatches = 0
        var consecutiveRests = 0
        var lastPlayedSequence: Int?
        
        for entry in entries {
            if entry.candidate.contains(playerID: playerID) {
                matchesPlayed += 1
                consecutiveMatches += 1
                consecutiveRests = 0
                lastPlayedSequence = entry.sequence
            } else if entry.eligiblePlayerIDs.contains(playerID) {
                waitingRounds += 1
                consecutiveMatches = 0
                consecutiveRests += 1
            } else {
                consecutiveMatches = 0
                consecutiveRests = 0
            }
        }
        
        return ParticipantMatchStatistics(
            matchesPlayed: matchesPlayed,
            waitingRounds: waitingRounds,
            consecutiveMatches: consecutiveMatches,
            consecutiveRests: consecutiveRests,
            lastPlayedSequence: lastPlayedSequence
        )
    }
    
    private enum CodingKeys: String, CodingKey {
        case entries
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([MatchHistoryEntry].self, forKey: .entries)
        
        do {
            try self.init(entries: entries)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .entries,
                in: container,
                debugDescription: "Decoded match history contains duplicate sequences."
            )
        }
    }
    
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
    }
}

nonisolated private extension ParticipantMatchHistory {
    func mostRecentSharedCandidate(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID
    ) -> MatchCandidate? {
        guard firstPlayerID != secondPlayerID else { return nil }
        return entries.last {
            $0.candidate.contains(playerID: firstPlayerID)
            && $0.candidate.contains(playerID: secondPlayerID)
        }?.candidate
    }
    
    func arePartners(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID,
        in candidate: MatchCandidate
    ) -> Bool {
        let teamAPlayerIDs = candidate.teamA.playerIDs
        let teamBPlayerIDs = candidate.teamB.playerIDs
        return (teamAPlayerIDs.contains(firstPlayerID) && teamAPlayerIDs.contains(secondPlayerID))
        || (teamBPlayerIDs.contains(firstPlayerID) && teamBPlayerIDs.contains(secondPlayerID))
    }
    
    func areOpponents(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID,
        in candidate: MatchCandidate
    ) -> Bool {
        let firstIsOnTeamA = candidate.teamA.playerIDs.contains(firstPlayerID)
        let firstIsOnTeamB = candidate.teamB.playerIDs.contains(firstPlayerID)
        let secondIsOnTeamA = candidate.teamA.playerIDs.contains(secondPlayerID)
        let secondIsOnTeamB = candidate.teamB.playerIDs.contains(secondPlayerID)
        return (firstIsOnTeamA && secondIsOnTeamB) || (firstIsOnTeamB && secondIsOnTeamA)
    }
}
