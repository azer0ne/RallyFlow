//
//  MatchCandidateGenerator.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

import Foundation

nonisolated struct MatchCandidateGenerator: Sendable {
    func candidates(for request: MatchmakingRequest) -> [MatchCandidate] {
        let playerIDs = eligiblePlayerIDs(for: request)
        
        switch request.matchType {
        case .singles:
            return singlesCandidates(from: playerIDs)
        case .doubles:
            return doublesCandidates(from: playerIDs)
        }
    }
    
    private func eligiblePlayerIDs(for request: MatchmakingRequest) -> [Player.ID] {
        var seenPlayerIDs: Set<Player.ID> = []
        
        return request.participants.compactMap { participant in
            guard request.isEligible(participant),
                  seenPlayerIDs.insert(participant.playerID).inserted else {
                return nil
            }
            return participant.playerID
        }
    }
    
    private func singlesCandidates(from playerIDs: [Player.ID]) -> [MatchCandidate] {
        guard playerIDs.count >= MatchType.singles.playersPerMatch else { return [] }
        
        var candidates: [MatchCandidate] = []
        for firstIndex in 0..<(playerIDs.count - 1) {
            for secondIndex in (firstIndex + 1)..<playerIDs.count {
                candidates.append(
                    makeCandidate(
                        matchType: .singles,
                        teamAPlayerIDs: [playerIDs[firstIndex]],
                        teamBPlayerIDs: [playerIDs[secondIndex]]
                    )
                )
            }
        }
        return candidates
    }
    
    private func doublesCandidates(from playerIDs: [Player.ID]) -> [MatchCandidate] {
        guard playerIDs.count >= MatchType.doubles.playersPerMatch else { return [] }
        
        var candidates: [MatchCandidate] = []
        for firstIndex in 0..<(playerIDs.count - 3) {
            for secondIndex in (firstIndex + 1)..<(playerIDs.count - 2) {
                for thirdIndex in (secondIndex + 1)..<(playerIDs.count - 1) {
                    for fourthIndex in (thirdIndex + 1)..<playerIDs.count {
                        let first = playerIDs[firstIndex]
                        let second = playerIDs[secondIndex]
                        let third = playerIDs[thirdIndex]
                        let fourth = playerIDs[fourthIndex]
                        
                        candidates.append(
                            makeCandidate(
                                matchType: .doubles,
                                teamAPlayerIDs: [first, second],
                                teamBPlayerIDs: [third, fourth]
                            )
                        )
                        candidates.append(
                            makeCandidate(
                                matchType: .doubles,
                                teamAPlayerIDs: [first, third],
                                teamBPlayerIDs: [second, fourth]
                            )
                        )
                        candidates.append(
                            makeCandidate(
                                matchType: .doubles,
                                teamAPlayerIDs: [first, fourth],
                                teamBPlayerIDs: [second, third]
                            )
                        )
                    }
                }
            }
        }
        return candidates
    }
    
    private func makeCandidate(
        matchType: MatchType,
        teamAPlayerIDs: [Player.ID],
        teamBPlayerIDs: [Player.ID]
    ) -> MatchCandidate {
        do {
            return try MatchCandidate(
                matchType: matchType,
                teamA: Team(playerIDs: teamAPlayerIDs),
                teamB: Team(playerIDs: teamBPlayerIDs)
            )
        } catch {
            preconditionFailure("Candidate enumeration produced an invalid player grouping.")
        }
    }
}
