import Foundation
import Testing
@testable import RallyFlow

nonisolated struct ParticipantMatchHistoryTests {
    @Test
    func simultaneousCourtsAdvanceOneEligibleOpportunity() throws {
        let eligible = Set((1...9).map { id(UInt8($0)) })
        let history = try ParticipantMatchHistory(entries: [
            MatchHistoryEntry(sequence: 0, candidate: doublesCandidate([1, 2], [3, 4]),
                              eligiblePlayerIDs: eligible, opportunitySequence: 0),
            MatchHistoryEntry(sequence: 1, candidate: doublesCandidate([5, 6], [7, 8]),
                              eligiblePlayerIDs: eligible, opportunitySequence: 0)
        ])
        #expect(history.statistics(for: id(9)).consecutiveRests == 1)
        #expect(history.statistics(for: id(1)).consecutiveMatches == 1)
        #expect(history.statistics(for: id(1)).consecutiveRests == 0)
        #expect(history.statistics(for: id(5)).consecutiveMatches == 1)
        #expect(history.statistics(for: id(5)).lastPlayedSequence == 1)
        #expect(try JSONDecoder().decode(ParticipantMatchHistory.self, from: JSONEncoder().encode(history)) == history)
    }

    @Test
    func simultaneousGroupsRejectAmbiguousOrOverlappingInput() throws {
        let first = try doublesCandidate([1, 2], [3, 4])
        let second = try doublesCandidate([5, 6], [7, 8])
        let eligible = Set((1...9).map { id(UInt8($0)) })
        let a = try MatchHistoryEntry(sequence: 0, candidate: first, eligiblePlayerIDs: eligible, opportunitySequence: 0)
        #expect(throws: ParticipantMatchHistoryError.overlappingOpportunityParticipants(0)) {
            try ParticipantMatchHistory(entries: [a, MatchHistoryEntry(sequence: 1, candidate: first,
                eligiblePlayerIDs: eligible, opportunitySequence: 0)])
        }
        #expect(throws: ParticipantMatchHistoryError.inconsistentOpportunityEligibility(0)) {
            try ParticipantMatchHistory(entries: [a, MatchHistoryEntry(sequence: 1, candidate: second, opportunitySequence: 0)])
        }
        #expect(throws: ParticipantMatchHistoryError.noncontiguousOpportunity(0)) {
            try ParticipantMatchHistory(entries: [a, MatchHistoryEntry(sequence: 1, candidate: second),
                MatchHistoryEntry(sequence: 2, candidate: second, eligiblePlayerIDs: eligible, opportunitySequence: 0)])
        }
        #expect(throws: MatchHistoryEntryError.negativeOpportunitySequence) {
            try MatchHistoryEntry(sequence: 0, candidate: first, opportunitySequence: -1)
        }
    }

    @Test
    func legacyHistoryStillTreatsEachEntryAsAnOpportunity() throws {
        let eligible = Set((1...9).map { id(UInt8($0)) })
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4], eligiblePlayerIDs: eligible),
            entry(1, [5, 6], [7, 8], eligiblePlayerIDs: eligible)
        ])
        #expect(history.statistics(for: id(9)).consecutiveRests == 2)
        let data = try JSONEncoder().encode(history)
        #expect(!String(decoding: data, as: UTF8.self).contains("opportunitySequence"))
        #expect(try JSONDecoder().decode(ParticipantMatchHistory.self, from: data) == history)
    }

    @Test
    func derivesMatchCountsAndLastPlayedSequence() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]),
            entry(1, [1, 3], [5, 6])
        ])

        #expect(history.matchesPlayed(for: id(1)) == 2)
        #expect(history.matchesPlayed(for: id(2)) == 1)
        #expect(history.matchesPlayed(for: id(3)) == 2)
        #expect(history.matchesPlayed(for: id(4)) == 1)
        #expect(history.matchesPlayed(for: id(5)) == 1)
        #expect(history.matchesPlayed(for: id(6)) == 1)
        #expect(history.lastPlayedSequence(for: id(1)) == 1)
        #expect(history.lastPlayedSequence(for: id(2)) == 0)
        #expect(history.lastPlayedSequence(for: id(9)) == nil)
    }

    @Test
    func partnerCountsAreSymmetricAndCountRepetition() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]),
            entry(1, [1, 3], [2, 4]),
            entry(2, [1, 2], [5, 6])
        ])

        #expect(history.partnerCount(between: id(1), and: id(2)) == 2)
        #expect(history.partnerCount(between: id(2), and: id(1)) == 2)
        #expect(history.partnerCount(between: id(1), and: id(3)) == 1)
        #expect(history.partnerCount(between: id(1), and: id(6)) == 0)
        #expect(history.partnerCount(between: id(1), and: id(1)) == 0)
    }

    @Test
    func opponentCountsAreSymmetricAndExcludePartners() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]),
            entry(1, [1, 3], [2, 4])
        ])

        #expect(history.opponentCount(between: id(1), and: id(3)) == 1)
        #expect(history.opponentCount(between: id(3), and: id(1)) == 1)
        #expect(history.opponentCount(between: id(1), and: id(4)) == 2)
        #expect(history.opponentCount(between: id(1), and: id(2)) == 1)
        #expect(history.opponentCount(between: id(1), and: id(1)) == 0)
    }

    @Test
    func recentRelationshipUsesMostRecentSharedMatch() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4]),
            entry(1, [1, 3], [2, 4]),
            entry(2, [1, 5], [6, 7])
        ])

        #expect(history.wereOpponentsInMostRecentSharedMatch(id(1), id(2)))
        #expect(!history.werePartnersInMostRecentSharedMatch(id(1), id(2)))
        #expect(history.werePartnersInMostRecentSharedMatch(id(1), id(5)))
        #expect(!history.wereOpponentsInMostRecentSharedMatch(id(1), id(5)))
        #expect(!history.werePartnersInMostRecentSharedMatch(id(1), id(9)))
    }

    @Test
    func statisticsDistinguishSelectionWaitingAndVoluntaryAbsence() throws {
        let allPlayers = Set((1...6).map { id(UInt8($0)) })
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4], eligiblePlayerIDs: allPlayers),
            entry(1, [1, 3], [2, 4], eligiblePlayerIDs: allPlayers),
            entry(2, [1, 2], [3, 4], eligiblePlayerIDs: Set((1...5).map { id(UInt8($0)) }))
        ])

        let selected = history.statistics(for: id(1))
        #expect(selected.matchesPlayed == 3)
        #expect(selected.waitingRounds == 0)
        #expect(selected.consecutiveMatches == 3)
        #expect(selected.consecutiveRests == 0)
        #expect(selected.lastPlayedSequence == 2)

        let eligibleButNotSelected = history.statistics(for: id(5))
        #expect(eligibleButNotSelected.matchesPlayed == 0)
        #expect(eligibleButNotSelected.waitingRounds == 3)
        #expect(eligibleButNotSelected.consecutiveMatches == 0)
        #expect(eligibleButNotSelected.consecutiveRests == 3)

        let voluntarilyAbsent = history.statistics(for: id(6))
        #expect(voluntarilyAbsent.matchesPlayed == 0)
        #expect(voluntarilyAbsent.waitingRounds == 2)
        #expect(voluntarilyAbsent.consecutiveMatches == 0)
        #expect(voluntarilyAbsent.consecutiveRests == 0)
    }

    @Test
    func laterSelectionResetsRestStreakAndStartsPlayStreak() throws {
        let eligible = Set((1...5).map { id(UInt8($0)) })
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4], eligiblePlayerIDs: eligible),
            entry(1, [1, 3], [2, 4], eligiblePlayerIDs: eligible),
            entry(2, [1, 5], [3, 4], eligiblePlayerIDs: eligible)
        ])

        let statistics = history.statistics(for: id(5))
        #expect(statistics.matchesPlayed == 1)
        #expect(statistics.waitingRounds == 2)
        #expect(statistics.consecutiveMatches == 1)
        #expect(statistics.consecutiveRests == 0)
    }

    @Test
    func historyOrdersEntriesBySequence() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(2, [1, 2], [3, 4]),
            entry(0, [1, 3], [2, 4]),
            entry(1, [1, 4], [2, 3])
        ])

        #expect(history.entries.map(\.sequence) == [0, 1, 2])
    }

    @Test
    func historyRejectsDuplicateSequences() throws {
        let entries = [
            try entry(0, [1, 2], [3, 4]),
            try entry(0, [1, 3], [2, 4])
        ]

        #expect(throws: ParticipantMatchHistoryError.duplicateSequence(0)) {
            try ParticipantMatchHistory(entries: entries)
        }
    }

    @Test
    func entryRejectsSelectedPlayerMissingFromEligibility() throws {
        let candidate = try doublesCandidate([1, 2], [3, 4])

        #expect(throws: MatchHistoryEntryError.selectedPlayerWasNotEligible) {
            try MatchHistoryEntry(
                sequence: 0,
                candidate: candidate,
                eligiblePlayerIDs: [id(1), id(2), id(3)]
            )
        }
    }

    @Test
    func historyRoundTripsThroughCodable() throws {
        let history = try ParticipantMatchHistory(entries: [
            entry(0, [1, 2], [3, 4], eligiblePlayerIDs: Set((1...5).map { id(UInt8($0)) }))
        ])
        let data = try JSONEncoder().encode(history)

        #expect(try JSONDecoder().decode(ParticipantMatchHistory.self, from: data) == history)
    }

    @Test
    func decodingCannotBypassUniqueHistorySequences() throws {
        let history = try ParticipantMatchHistory(entries: [entry(0, [1, 2], [3, 4])])
        let data = try JSONEncoder().encode(history)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(object["entries"] as? [[String: Any]])
        object["entries"] = entries + entries
        let malformedData = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ParticipantMatchHistory.self, from: malformedData)
        }
    }

    private func entry(
        _ sequence: Int,
        _ teamA: [UInt8],
        _ teamB: [UInt8],
        eligiblePlayerIDs: Set<Player.ID>? = nil
    ) throws -> MatchHistoryEntry {
        try MatchHistoryEntry(
            sequence: sequence,
            candidate: doublesCandidate(teamA, teamB),
            eligiblePlayerIDs: eligiblePlayerIDs
        )
    }

    private func doublesCandidate(
        _ teamA: [UInt8],
        _ teamB: [UInt8]
    ) throws -> MatchCandidate {
        try MatchCandidate(
            matchType: .doubles,
            teamA: Team(playerIDs: teamA.map(id)),
            teamB: Team(playerIDs: teamB.map(id))
        )
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
