//
//  ScoringHistoryTests.swift
//  RallyFlowTests
//
//  Created by Arez on 10/09/26.
//

import Testing
@testable import RallyFlow

nonisolated struct ScoringHistoryTests {
    enum Boundary: CaseIterable, Sendable {
        case love, thirty, deuce, advantage, game, set, tiebreak, match
        case servicePoint, serviceGame, fourthGame, decidingTiebreak
        case rallyPoint, rallyGame, rallyMatch, fixedPoint, fixedMatch
    }

    @Test(arguments: Boundary.allCases)
    func undoRestoresWholeStateAcrossBoundary(boundary: Boundary) throws {
        let fixture = try fixture(for: boundary)
        var history = ScoringHistory(initialState: fixture.state, configuration: fixture.configuration)
        let after = try history.apply(event: fixture.event)
        #expect(after != fixture.state)
        try verifyBoundary(boundary, state: after, configuration: fixture.configuration)
        #expect(history.events == [fixture.event])
        let restored = try history.apply(event: .undo)
        #expect(restored == fixture.state)
        #expect(history.state == fixture.state)
        #expect(history.events.isEmpty)
        #expect(history.configuration == fixture.configuration)
        #expect(try history.replayedState() == restored)
        #expect(try history.apply(event: fixture.event) == after)
    }

    @Test
    func consecutiveUndosAndBranchingEqualReplay() throws {
        let configuration = try RallyScoringEngineTests().configuration()
        var history = ScoringHistory(initialState: .rally(RallyMatchScoreState()), configuration: configuration)
        for event in [ScoreEvent.teamAWonRally, .teamBWonRally, .teamAWonRally, .teamAWonRally] {
            try history.apply(event: event)
        }
        try history.apply(event: .undo)
        try history.apply(event: .undo)
        #expect(history.events == [.teamAWonRally, .teamBWonRally])
        #expect(try history.replayedState() == history.state)
        try history.apply(event: .teamBWonRally)
        #expect(history.events == [.teamAWonRally, .teamBWonRally, .teamBWonRally])
        #expect(try history.replayedState() == history.state)
        #expect(history.state == .rally(RallyMatchScoreState(currentGame: GameScore(teamAPoints: 1, teamBPoints: 2))))
        for _ in 0..<3 { try history.apply(event: .undo) }
        #expect(history.state == history.initialState)
        #expect(throws: ScoringEngineError.emptyHistory) { try history.apply(event: .undo) }
    }

    @Test
    func rejectedRallyDoesNotEnterHistory() throws {
        let fixture = try fixture(for: .fixedMatch)
        var history = ScoringHistory(initialState: fixture.state, configuration: fixture.configuration)
        let completed = try history.apply(event: fixture.event)
        #expect(throws: ScoringEngineError.matchAlreadyCompleted) { try history.apply(event: .teamAWonRally) }
        #expect(history.events == [fixture.event])
        #expect(history.state == completed)
        try history.apply(event: .undo)
        #expect(history.state == fixture.state)
        #expect(try FixedTotalScoringEngine().progress(for: history.state,
            configuration: history.configuration).pointsRemaining == 1)
    }

    @Test
    func historiesAndValueCopiesStayIndependent() throws {
        let configuration = try RallyScoringEngineTests().configuration()
        let original = ScoringHistory(initialState: .rally(RallyMatchScoreState()), configuration: configuration)
        var first = original
        var second = original
        try first.apply(event: .teamAWonRally)
        try second.apply(event: .teamBWonRally)
        try first.apply(event: .undo)
        #expect(original.events.isEmpty)
        #expect(first.state == original.state)
        #expect(second.events == [.teamBWonRally])
    }

    @Test
    func fullTennisMatchCanBeReplayedAndUndoneToStart() throws {
        let configuration = try tennisConfiguration(count: 3)
        var history = ScoringHistory(initialState: .tennis(TennisMatchScoreState()), configuration: configuration)
        for _ in 0..<48 { try history.apply(event: .teamAWonRally) }
        #expect(try MatchScoringEngine().result(for: history.state, configuration: configuration)?.outcome == .teamAWin)
        #expect(try history.replayedState() == history.state)
        for _ in 0..<48 {
            try history.apply(event: .undo)
            #expect(try history.replayedState() == history.state)
        }
        #expect(history.state == history.initialState)
    }

    private func tennisConfiguration(count: Int = 3) throws -> ScoringConfiguration {
        try ScoringConfiguration(style: .tennis, pointSystem: .tennis,
            matchStructure: .bestOfSets(count: count, setRules: SetRules(gamesToWin: 6, winByGames: 2,
                tiebreakAt: 6, tiebreakTarget: 7, tiebreakWinBy: 2)), deuceRule: .advantage, servingRule: .standard)
    }

    private func fixture(for boundary: Boundary) throws -> (state: MatchScoreState, configuration: ScoringConfiguration, event: ScoreEvent) {
        var tennis = TennisMatchScoreState()
        switch boundary {
        case .love: break
        case .thirty: tennis.currentGame = .points(teamA: .thirty, teamB: .love)
        case .deuce: tennis.currentGame = .points(teamA: .thirty, teamB: .forty)
        case .advantage: tennis.currentGame = .deuce
        case .game: tennis.currentGame = .advantage(.teamA)
        case .set, .match:
            tennis.currentGame = .points(teamA: .forty, teamB: .love)
            tennis.teamAGames = 5
            tennis.teamBGames = 4
        case .tiebreak:
            tennis.teamAGames = 6
            tennis.teamBGames = 6
            tennis.setPhase = .tiebreak(TiebreakScore(teamAPoints: 6, teamBPoints: 5, startingServer: .teamB))
        case .servicePoint, .serviceGame, .fourthGame, .decidingTiebreak:
            var service = try OneServeEachTests().initial(startingSide: .teamB)
            if boundary == .serviceGame { service.phase = .serviceGame(.advantage(.teamA)) }
            if boundary == .fourthGame {
                service.completedGames = [.teamB, .teamA, .teamB]
                service.phase = .serviceGame(.points(teamA: .forty, teamB: .love))
            }
            if boundary == .decidingTiebreak {
                service.completedGames = [.teamA, .teamB, .teamA, .teamB]
                service.phase = .tiebreak(TiebreakScore(teamAPoints: 6, teamBPoints: 5, startingServer: .teamB))
            }
            return (.oneServeEach(service), try OneServeEachTests().configuration(deuceRule: .advantage,
                tieRule: boundary == .decidingTiebreak ? .tiebreak(target: 7, winBy: 2) : .draw), .teamAWonRally)
        case .rallyPoint, .rallyGame, .rallyMatch:
            var rally = RallyMatchScoreState()
            if boundary != .rallyPoint { rally.currentGame = GameScore(teamAPoints: 14, teamBPoints: 9) }
            if boundary == .rallyMatch {
                rally.completedGames = [GameScore(teamAPoints: 15, teamBPoints: 10)]
                rally.teamAGames = 1
                rally.currentGameIndex = 1
            }
            return (.rally(rally), try RallyScoringEngineTests().configuration(
                .bestOfGames(count: 3, pointsPerGame: 15, winBy: 2, cap: nil)), .teamAWonRally)
        case .fixedPoint, .fixedMatch:
            let game = boundary == .fixedMatch ? GameScore(teamAPoints: 15, teamBPoints: 8) : GameScore()
            return (.rally(RallyMatchScoreState(currentGame: game)),
                try FixedTotalScoringEngineTests().configuration(total: 24), .teamBWonRally)
        }
        return (.tennis(tennis), try tennisConfiguration(count: boundary == .match ? 1 : 3), .teamAWonRally)
    }

    private func verifyBoundary(_ boundary: Boundary, state: MatchScoreState, configuration: ScoringConfiguration) throws {
        switch boundary {
        case .match, .fourthGame, .decidingTiebreak, .rallyMatch, .fixedMatch:
            #expect(try MatchScoringEngine().result(for: state, configuration: configuration) != nil)
        case .set, .tiebreak:
            guard case .tennis(let score) = state else { Issue.record("Expected tennis set"); return }
            #expect(score.completedSets.count == 1)
        case .game:
            guard case .tennis(let score) = state else { Issue.record("Expected tennis game"); return }
            #expect(score.teamAGames == 1)
        case .serviceGame:
            guard case .oneServeEach(let score) = state else { Issue.record("Expected service game"); return }
            #expect(score.currentServiceGameIndex == 1)
        case .rallyGame:
            guard case .rally(let score) = state else { Issue.record("Expected rally game"); return }
            #expect(score.completedGames.count == 1)
        default: break
        }
    }
}
