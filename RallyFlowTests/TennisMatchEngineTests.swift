//
//  TennisMatchEngineTests.swift
//  RallyFlowTests
//
//  Created by Arez on 27/08/26.
//

import Testing
@testable import RallyFlow

nonisolated struct TennisMatchEngineTests {

    @Test
    func bestOfOneCompletesWhenTeamAWinsFirstSet() throws {
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 4),
            bestOfCount: 1
        )

        #expect(updated.completedSets == [SetScore(teamAGames: 6, teamBGames: 4)])
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamAWin)
    }

    @Test
    func bestOfOneCompletesWhenTeamBWinsFirstSet() throws {
        let updated = try completeSet(
            wonBy: .teamB,
            fromGames: (4, 5),
            bestOfCount: 1
        )

        #expect(updated.completedSets == [SetScore(teamAGames: 4, teamBGames: 6)])
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamBWin)
    }

    @Test
    func bestOfThreeCompletesInStraightSets() throws {
        let firstSet = SetScore(teamAGames: 6, teamBGames: 2)
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 4),
            completedSets: [firstSet],
            bestOfCount: 3
        )

        #expect(updated.completedSets == [firstSet, SetScore(teamAGames: 6, teamBGames: 4)])
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamAWin)
    }

    @Test
    func bestOfThreeContinuesAfterSplitSets() throws {
        let firstSet = SetScore(teamAGames: 6, teamBGames: 3)
        let updated = try completeSet(
            wonBy: .teamB,
            fromGames: (4, 5),
            completedSets: [firstSet],
            bestOfCount: 3
        )

        #expect(updated.completedSets == [firstSet, SetScore(teamAGames: 4, teamBGames: 6)])
        #expect(!updated.isMatchComplete)
        #expect(updated.teamAGames == 0)
        #expect(updated.teamBGames == 0)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
        #expect(updated.setPhase == .regularGame)
        #expect(try result(for: updated) == nil)
    }

    @Test
    func bestOfThreeCompletesForTeamAInDecidingSet() throws {
        let completedSets = [
            SetScore(teamAGames: 6, teamBGames: 3),
            SetScore(teamAGames: 4, teamBGames: 6)
        ]
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (6, 5),
            completedSets: completedSets,
            bestOfCount: 3
        )

        #expect(updated.completedSets == completedSets + [SetScore(teamAGames: 7, teamBGames: 5)])
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamAWin)
    }

    @Test
    func bestOfThreeCompletesForTeamBInDecidingSet() throws {
        let completedSets = [
            SetScore(teamAGames: 3, teamBGames: 6),
            SetScore(teamAGames: 6, teamBGames: 4)
        ]
        let updated = try completeSet(
            wonBy: .teamB,
            fromGames: (5, 6),
            completedSets: completedSets,
            bestOfCount: 3
        )

        #expect(updated.completedSets == completedSets + [SetScore(teamAGames: 5, teamBGames: 7)])
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamBWin)
    }

    @Test
    func bestOfFiveCompletesAtThreeLove() throws {
        let completedSets = [
            SetScore(teamAGames: 6, teamBGames: 0),
            SetScore(teamAGames: 6, teamBGames: 1)
        ]
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 2),
            completedSets: completedSets,
            bestOfCount: 5
        )

        #expect(updated.completedSets.count == 3)
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamAWin)
    }

    @Test
    func bestOfFiveCompletesAtThreeTwo() throws {
        let completedSets = [
            SetScore(teamAGames: 6, teamBGames: 0),
            SetScore(teamAGames: 0, teamBGames: 6),
            SetScore(teamAGames: 6, teamBGames: 2),
            SetScore(teamAGames: 3, teamBGames: 6)
        ]
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 4),
            completedSets: completedSets,
            bestOfCount: 5
        )

        #expect(updated.completedSets.count == 5)
        #expect(updated.isMatchComplete)
        #expect(try result(for: updated)?.outcome == .teamAWin)
    }

    @Test
    func bestOfFiveContinuesAtTwoAll() throws {
        let completedSets = [
            SetScore(teamAGames: 6, teamBGames: 0),
            SetScore(teamAGames: 6, teamBGames: 1),
            SetScore(teamAGames: 2, teamBGames: 6)
        ]
        let updated = try completeSet(
            wonBy: .teamB,
            fromGames: (4, 5),
            completedSets: completedSets,
            bestOfCount: 5
        )

        #expect(updated.completedSets.count == 4)
        #expect(!updated.isMatchComplete)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
        #expect(try result(for: updated) == nil)
    }

    @Test
    func tiebreakDecidedSetParticipatesInMatchCompletion() throws {
        let firstTiebreak = TiebreakScore(
            teamAPoints: 9,
            teamBPoints: 7,
            startingServer: .teamB
        )
        let firstSet = SetScore(
            teamAGames: 7,
            teamBGames: 6,
            tiebreakScore: firstTiebreak
        )
        let updated = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 4),
            completedSets: [firstSet],
            bestOfCount: 3
        )

        #expect(updated.isMatchComplete)
        #expect(updated.completedSets[0].tiebreakScore == firstTiebreak)
        #expect(updated.completedSets[1] == SetScore(teamAGames: 6, teamBGames: 4))
        #expect(try result(for: updated)?.finalScore == .tennis(updated))
    }

    @Test
    func matchWinningTiebreakCompletesMatchAndPreservesDetails() throws {
        let firstSet = SetScore(teamAGames: 6, teamBGames: 4)
        let inputTiebreak = TiebreakScore(
            teamAPoints: 6,
            teamBPoints: 5,
            startingServer: .teamA
        )
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            completedSets: [firstSet],
            currentSetIndex: 1,
            setPhase: .tiebreak(inputTiebreak)
        )

        let updated = try apply(
            .teamAWonRally,
            to: state,
            bestOfCount: 3,
            usesTiebreak: true
        )

        #expect(updated.isMatchComplete)
        #expect(updated.completedSets.count == 2)
        #expect(updated.completedSets[0] == firstSet)
        #expect(updated.completedSets[1].teamAGames == 7)
        #expect(updated.completedSets[1].teamBGames == 6)
        #expect(updated.completedSets[1].tiebreakScore?.teamAPoints == 7)
        #expect(updated.completedSets[1].tiebreakScore?.teamBPoints == 5)
    }

    @Test
    func scoringAfterMatchCompletionFailsPredictably() throws {
        let completed = try completeSet(
            wonBy: .teamA,
            fromGames: (5, 4),
            bestOfCount: 1
        )

        #expect(completed.isMatchComplete)
        #expect(throws: ScoringEngineError.matchAlreadyCompleted) {
            try apply(.teamAWonRally, to: completed, bestOfCount: 1)
        }
    }

    @Test
    func rejectsCompletedSetWithoutWinner() throws {
        let configuration = try tennisConfiguration(bestOfCount: 3)
        let state = TennisMatchScoreState(
            completedSets: [SetScore(teamAGames: 6, teamBGames: 6)]
        )

        #expect(throws: ScoringEngineError.invalidCompletedSet) {
            try TennisMatchEngine().evaluateAfterCompletedSet(
                in: state,
                configuration: configuration
            )
        }
    }
}

private extension TennisMatchEngineTests {
    /// Completes the current set through the unified tennis-scoring entry point.
    nonisolated func completeSet(
        wonBy winner: TeamSide,
        fromGames games: (teamA: Int, teamB: Int),
        completedSets: [SetScore] = [],
        bestOfCount: Int
    ) throws -> TennisMatchScoreState {
        let currentGame: TennisGameScore
        let event: ScoreEvent
        switch winner {
        case .teamA:
            currentGame = .points(teamA: .forty, teamB: .love)
            event = .teamAWonRally
        case .teamB:
            currentGame = .points(teamA: .love, teamB: .forty)
            event = .teamBWonRally
        }

        return try apply(
            event,
            to: TennisMatchScoreState(
                currentGame: currentGame,
                teamAGames: games.teamA,
                teamBGames: games.teamB,
                completedSets: completedSets,
                currentSetIndex: completedSets.count
            ),
            bestOfCount: bestOfCount
        )
    }

    /// Applies a rally through the unified tennis-scoring entry point.
    nonisolated func apply(
        _ event: ScoreEvent,
        to state: TennisMatchScoreState,
        bestOfCount: Int,
        usesTiebreak: Bool = false
    ) throws -> TennisMatchScoreState {
        let updated = try TennisScoringEngine().apply(
            event: event,
            to: .tennis(state),
            configuration: try tennisConfiguration(
                bestOfCount: bestOfCount,
                usesTiebreak: usesTiebreak
            )
        )

        guard case .tennis(let tennisState) = updated else {
            Issue.record("Expected tennis score state")
            return state
        }
        return tennisState
    }

    /// Produces a final result for a completed tennis state.
    nonisolated func result(for state: TennisMatchScoreState) throws -> MatchResult? {
        try TennisMatchEngine().result(for: .tennis(state))
    }

    /// Creates a validated best-of-sets tennis configuration.
    nonisolated func tennisConfiguration(
        bestOfCount: Int,
        usesTiebreak: Bool = false
    ) throws -> ScoringConfiguration {
        let setRules = usesTiebreak
            ? SetRules(
                gamesToWin: 6,
                winByGames: 2,
                tiebreakAt: 6,
                tiebreakTarget: 7,
                tiebreakWinBy: 2
            )
            : SetRules(gamesToWin: 6, winByGames: 2)

        return try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(count: bestOfCount, setRules: setRules),
            deuceRule: .advantage,
            servingRule: .standard
        )
    }
}
