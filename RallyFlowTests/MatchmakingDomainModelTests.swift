import Foundation
import Testing
@testable import RallyFlow

nonisolated struct MatchmakingDomainModelTests {
    @Test
    func singlesCandidateRepresentsOnePlayerPerTeam() throws {
        let candidate = try candidate(.singles, [id(1)], [id(2)])

        #expect(candidate.matchType == .singles)
        #expect(candidate.teamA.playerIDs == [id(1)])
        #expect(candidate.teamB.playerIDs == [id(2)])
    }

    @Test
    func doublesCandidateRepresentsTwoPlayersPerTeam() throws {
        let candidate = try candidate(.doubles, [id(1), id(2)], [id(3), id(4)])

        #expect(candidate.teamA.playerIDs == [id(1), id(2)])
        #expect(candidate.teamB.playerIDs == [id(3), id(4)])
        #expect(Set(candidate.playerIDs).count == 4)
    }

    @Test
    func candidateRejectsRepeatedPlayerAcrossTeams() {
        #expect(throws: MatchCandidateError.duplicatePlayer) {
            try candidate(.doubles, [id(1), id(2)], [id(1), id(3)])
        }
    }

    @Test
    func candidateRejectsRepeatedPlayerWithinTeam() {
        #expect(throws: MatchCandidateError.duplicatePlayer) {
            try candidate(.doubles, [id(1), id(1)], [id(2), id(3)])
        }
    }

    @Test
    func candidateRejectsTeamWithWrongSize() {
        #expect(throws: MatchCandidateError.invalidTeamSize(expected: 2, actual: 1)) {
            try candidate(.doubles, [id(1)], [id(2), id(3)])
        }
    }

    @Test
    func mirroredCandidatesAreEquivalentRegardlessOfTeamIdentity() throws {
        let first = try candidate(.doubles, [id(1), id(2)], [id(3), id(4)])
        let mirrored = try candidate(.doubles, [id(4), id(3)], [id(2), id(1)])

        #expect(first == mirrored)
        #expect(Set([first, mirrored]).count == 1)
    }

    @Test
    func suggestionPreservesSemanticReasonsAndWarnings() throws {
        let match = try candidate(.singles, [id(1)], [id(2)])
        let suggestion = MatchSuggestion(
            candidate: match,
            reasons: [.fewerMatchesPlayed, .longerWaiting],
            warnings: [.consecutivePlay]
        )

        #expect(suggestion.candidate == match)
        #expect(suggestion.reasons == [.fewerMatchesPlayed, .longerWaiting])
        #expect(suggestion.warnings == [.consecutivePlay])
    }

    @Test(arguments: [SchedulingContext.immediate, .upcoming])
    func requestRepresentsSchedulingContext(_ schedulingContext: SchedulingContext) {
        let request = MatchmakingRequest(
            matchType: .singles,
            schedulingContext: schedulingContext,
            participants: []
        )

        #expect(request.schedulingContext == schedulingContext)
    }

    @Test
    func domainModelsRoundTripThroughCodable() throws {
        let suggestion = MatchSuggestion(
            candidate: try candidate(.doubles, [id(1), id(2)], [id(3), id(4)]),
            reasons: [.newPartnerCombination],
            warnings: [.repeatedOpponent]
        )
        let request = MatchmakingRequest(
            matchType: .doubles,
            schedulingContext: .upcoming,
            participants: [SessionParticipant(playerID: id(1), status: .playing)],
            eligibility: .explicit(playerIDs: [id(1)])
        )

        #expect(try roundTrip(suggestion) == suggestion)
        #expect(try roundTrip(request) == request)
    }

    @Test
    func decodingCannotBypassCandidatePlayerUniqueness() throws {
        let match = try candidate(.singles, [id(1)], [id(2)])
        let data = try JSONEncoder().encode(match)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var teamB = try #require(object["teamB"] as? [String: Any])
        teamB["playerIDs"] = [id(1).uuidString]
        object["teamB"] = teamB
        let malformedData = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MatchCandidate.self, from: malformedData)
        }
    }

    private func candidate(
        _ matchType: MatchType,
        _ teamAPlayerIDs: [Player.ID],
        _ teamBPlayerIDs: [Player.ID]
    ) throws -> MatchCandidate {
        try MatchCandidate(
            matchType: matchType,
            teamA: Team(playerIDs: teamAPlayerIDs),
            teamB: Team(playerIDs: teamBPlayerIDs)
        )
    }

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(value))
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
