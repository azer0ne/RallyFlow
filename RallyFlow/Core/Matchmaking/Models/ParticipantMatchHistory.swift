import Foundation

/// An error caused by an invalid collection of completed-match entries.
nonisolated enum ParticipantMatchHistoryError: Error, Equatable, Sendable {
    /// Two entries use the same session sequence.
    case duplicateSequence(Int)
}

/// Ordered completed-match facts used by future matchmaking decisions.
nonisolated struct ParticipantMatchHistory: Codable, Hashable, Sendable {
    /// Completed matches in ascending sequence order.
    let entries: [MatchHistoryEntry]

    /// Creates empty match history.
    init() {
        entries = []
    }

    /// Creates match history and orders entries by sequence.
    ///
    /// - Throws: `ParticipantMatchHistoryError` when sequences are not unique.
    init(entries: [MatchHistoryEntry]) throws {
        var sequences: Set<Int> = []
        for entry in entries {
            guard sequences.insert(entry.sequence).inserted else {
                throw ParticipantMatchHistoryError.duplicateSequence(entry.sequence)
            }
        }
        self.entries = entries.sorted { $0.sequence < $1.sequence }
    }

    /// Returns the number of completed matches containing the player.
    ///
    /// - Complexity: O(m), where `m` is the number of history entries.
    func matchesPlayed(for playerID: Player.ID) -> Int {
        entries.count { $0.candidate.contains(playerID: playerID) }
    }

    /// Returns how often two distinct players completed a match on the same team.
    ///
    /// - Complexity: O(m), where `m` is the number of history entries.
    func partnerCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        guard firstPlayerID != secondPlayerID else { return 0 }
        return entries.count {
            arePartners(firstPlayerID, secondPlayerID, in: $0.candidate)
        }
    }

    /// Returns how often two distinct players completed a match on opposing teams.
    ///
    /// - Complexity: O(m), where `m` is the number of history entries.
    func opponentCount(between firstPlayerID: Player.ID, and secondPlayerID: Player.ID) -> Int {
        guard firstPlayerID != secondPlayerID else { return 0 }
        return entries.count {
            areOpponents(firstPlayerID, secondPlayerID, in: $0.candidate)
        }
    }

    /// Returns the sequence of the player's most recent completed match.
    ///
    /// - Complexity: O(m), where `m` is the number of history entries.
    func lastPlayedSequence(for playerID: Player.ID) -> Int? {
        entries.last { $0.candidate.contains(playerID: playerID) }?.sequence
    }

    /// Returns whether two players partnered in their most recent shared match.
    ///
    /// Matches involving only one of the players are irrelevant to this relationship.
    /// - Complexity: O(m), where `m` is the number of history entries.
    func werePartnersInMostRecentSharedMatch(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID
    ) -> Bool {
        guard let candidate = mostRecentSharedCandidate(firstPlayerID, secondPlayerID) else {
            return false
        }
        return arePartners(firstPlayerID, secondPlayerID, in: candidate)
    }

    /// Returns whether two players opposed each other in their most recent shared match.
    ///
    /// Matches involving only one of the players are irrelevant to this relationship.
    /// - Complexity: O(m), where `m` is the number of history entries.
    func wereOpponentsInMostRecentSharedMatch(
        _ firstPlayerID: Player.ID,
        _ secondPlayerID: Player.ID
    ) -> Bool {
        guard let candidate = mostRecentSharedCandidate(firstPlayerID, secondPlayerID) else {
            return false
        }
        return areOpponents(firstPlayerID, secondPlayerID, in: candidate)
    }

    /// Returns participation and waiting facts derived from every recorded rotation.
    ///
    /// Eligible nonselection adds a waiting round and extends the rest streak. Absence
    /// from eligibility adds no waiting and breaks both streaks. Selection extends the
    /// play streak and resets the rest streak.
    /// - Complexity: O(m), where `m` is the number of history entries.
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

    /// Decodes and revalidates ordered completed-match history.
    ///
    /// - Throws: `DecodingError` when decoded entries contain duplicate sequences.
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

    /// Encodes completed-match entries in sequence order.
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
