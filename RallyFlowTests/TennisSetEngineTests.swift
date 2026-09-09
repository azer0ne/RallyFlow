//
//  TennisSetEngineTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

nonisolated struct TennisSetEngineTests {

    @Test
    func completesStandardSetAtSixLove() throws {
        let updated = try winGame(for: .teamA, fromGames: (5, 0))

        #expect(updated.completedSets == [SetScore(teamAGames: 6, teamBGames: 0)])
        expectFreshSet(updated)
    }

    @Test
    func completesStandardSetAtSixFour() throws {
        let updated = try winGame(for: .teamA, fromGames: (5, 4))

        #expect(updated.completedSets == [SetScore(teamAGames: 6, teamBGames: 4)])
        expectFreshSet(updated)
    }

    @Test
    func continuesStandardSetAtSixFive() throws {
        let updated = try winGame(for: .teamA, fromGames: (5, 5))

        #expect(updated.teamAGames == 6)
        #expect(updated.teamBGames == 5)
        #expect(updated.completedSets.isEmpty)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
        #expect(updated.setPhase == .regularGame)
    }

    @Test
    func completesStandardSetAtSevenFive() throws {
        let updated = try winGame(for: .teamA, fromGames: (6, 5))

        #expect(updated.completedSets == [SetScore(teamAGames: 7, teamBGames: 5)])
        expectFreshSet(updated)
    }

    @Test
    func teamBCompletesStandardSetAtFourSix() throws {
        let updated = try winGame(for: .teamB, fromGames: (4, 5))

        #expect(updated.completedSets == [SetScore(teamAGames: 4, teamBGames: 6)])
        expectFreshSet(updated)
    }

    @Test
    func teamBCompletesStandardSetAtFiveSeven() throws {
        let updated = try winGame(for: .teamB, fromGames: (5, 6))

        #expect(updated.completedSets == [SetScore(teamAGames: 5, teamBGames: 7)])
        expectFreshSet(updated)
    }

    @Test
    func detectsTiebreakAtSixAll() throws {
        let rules = SetRules(
            gamesToWin: 6,
            winByGames: 2,
            tiebreakAt: 6,
            tiebreakTarget: 7,
            tiebreakWinBy: 2
        )

        let updated = try winGame(for: .teamA, fromGames: (5, 6), setRules: rules)

        #expect(updated.teamAGames == 6)
        #expect(updated.teamBGames == 6)
        #expect(updated.completedSets.isEmpty)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
        #expect(updated.setPhase == .tiebreakRequired)
        #expect(!updated.isMatchComplete)
    }

    @Test
    func beginsTiebreakWhenTiebreakIsRequired() throws {
        let rules = SetRules(
            gamesToWin: 6,
            winByGames: 2,
            tiebreakAt: 6,
            tiebreakTarget: 7,
            tiebreakWinBy: 2
        )
        let configuration = try tennisConfiguration(setRules: rules)
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            setPhase: .tiebreakRequired
        )

        let updated = try TennisScoringEngine().apply(
            event: .teamAWonRally,
            to: .tennis(state),
            configuration: configuration
        )

        guard case let .tennis(tennisState) = updated,
              case let .tiebreak(score) = tennisState.setPhase else {
            Issue.record("Expected an active tiebreak")
            return
        }

        #expect(score.teamAPoints == 1)
        #expect(score.teamBPoints == 0)
    }

    @Test
    func advantageSetContinuesAtSevenSix() throws {
        let updated = try winGame(for: .teamA, fromGames: (6, 6))

        #expect(updated.teamAGames == 7)
        #expect(updated.teamBGames == 6)
        #expect(updated.completedSets.isEmpty)
        #expect(updated.setPhase == .regularGame)
    }

    @Test
    func advantageSetCompletesAtEightSix() throws {
        let updated = try winGame(for: .teamA, fromGames: (7, 6))

        #expect(updated.completedSets == [SetScore(teamAGames: 8, teamBGames: 6)])
        expectFreshSet(updated)
    }

    @Test
    func teamBAdvantageSetContinuesAtSixSeven() throws {
        let updated = try winGame(for: .teamB, fromGames: (6, 6))

        #expect(updated.teamAGames == 6)
        #expect(updated.teamBGames == 7)
        #expect(updated.completedSets.isEmpty)
    }

    @Test
    func teamBAdvantageSetCompletesAtSixEight() throws {
        let updated = try winGame(for: .teamB, fromGames: (6, 7))

        #expect(updated.completedSets == [SetScore(teamAGames: 6, teamBGames: 8)])
        expectFreshSet(updated)
    }

    @Test
    func completesShortSetAtFourLove() throws {
        let updated = try winGame(
            for: .teamA,
            fromGames: (3, 0),
            setRules: shortSetRules
        )

        #expect(updated.completedSets == [SetScore(teamAGames: 4, teamBGames: 0)])
        expectFreshSet(updated)
    }

    @Test
    func completesShortSetAtFourTwo() throws {
        let updated = try winGame(
            for: .teamA,
            fromGames: (3, 2),
            setRules: shortSetRules
        )

        #expect(updated.completedSets == [SetScore(teamAGames: 4, teamBGames: 2)])
        expectFreshSet(updated)
    }

    @Test
    func continuesShortSetAtFourThree() throws {
        let updated = try winGame(
            for: .teamA,
            fromGames: (3, 3),
            setRules: shortSetRules
        )

        #expect(updated.teamAGames == 4)
        #expect(updated.teamBGames == 3)
        #expect(updated.completedSets.isEmpty)
    }

    @Test
    func completesShortSetAtFiveThree() throws {
        let updated = try winGame(
            for: .teamA,
            fromGames: (4, 3),
            setRules: shortSetRules
        )

        #expect(updated.completedSets == [SetScore(teamAGames: 5, teamBGames: 3)])
        expectFreshSet(updated)
    }

    @Test
    func detectsConfiguredShortSetTiebreak() throws {
        let rules = SetRules(
            gamesToWin: 4,
            winByGames: 2,
            tiebreakAt: 4,
            tiebreakTarget: 7,
            tiebreakWinBy: 2
        )

        let updated = try winGame(for: .teamA, fromGames: (3, 4), setRules: rules)

        #expect(updated.teamAGames == 4)
        #expect(updated.teamBGames == 4)
        #expect(updated.setPhase == .tiebreakRequired)
        #expect(updated.completedSets.isEmpty)
    }

    @Test
    func resetsFortyFifteenAfterGameWin() throws {
        let state = TennisMatchScoreState(
            currentGame: .points(teamA: .forty, teamB: .fifteen),
            teamAGames: 2,
            teamBGames: 1
        )

        let updated = try apply(.teamAWonRally, to: state)

        #expect(updated.teamAGames == 3)
        #expect(updated.teamBGames == 1)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
    }

    @Test
    func resetsAfterWinningFromDeuce() throws {
        var state = TennisMatchScoreState(currentGame: .deuce, teamAGames: 2, teamBGames: 1)

        state = try apply(.teamAWonRally, to: state)
        #expect(state.currentGame == .advantage(.teamA))

        state = try apply(.teamAWonRally, to: state)
        #expect(state.teamAGames == 3)
        #expect(state.currentGame == .points(teamA: .love, teamB: .love))
    }

    @Test
    func resetsAfterWinningFromAdvantage() throws {
        let state = TennisMatchScoreState(
            currentGame: .advantage(.teamB),
            teamAGames: 2,
            teamBGames: 1
        )

        let updated = try apply(.teamBWonRally, to: state)

        #expect(updated.teamAGames == 2)
        #expect(updated.teamBGames == 2)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
    }

    @Test
    func advancesExplicitCompletedGameRepresentation() throws {
        let state = TennisMatchScoreState(
            currentGame: .game(.teamA),
            teamAGames: 2,
            teamBGames: 1
        )
        let configuration = try tennisConfiguration(setRules: standardSetRules)

        let updated = try TennisSetEngine().advanceAfterCompletedGame(
            in: state,
            configuration: configuration
        )

        #expect(updated.teamAGames == 3)
        #expect(updated.teamBGames == 1)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
    }

    @Test
    func preservesEarlierSetWhenSecondSetCompletesMatch() throws {
        let firstSet = SetScore(teamAGames: 6, teamBGames: 4)
        let state = TennisMatchScoreState(
            currentGame: .points(teamA: .forty, teamB: .love),
            teamAGames: 5,
            teamBGames: 1,
            completedSets: [firstSet],
            currentGameIndex: 11,
            currentSetIndex: 1
        )

        let updated = try apply(.teamAWonRally, to: state)

        #expect(
            updated.completedSets == [
                firstSet,
                SetScore(teamAGames: 6, teamBGames: 1)
            ]
        )
        #expect(updated.teamAGames == 0)
        #expect(updated.teamBGames == 0)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
        #expect(updated.currentGameIndex == 12)
        #expect(updated.currentSetIndex == 2)
        #expect(updated.isMatchComplete)
    }

    @Test
    func preservesUnrelatedStateDuringRegularGameProgression() throws {
        let completedSets = [SetScore(teamAGames: 4, teamBGames: 6)]
        let state = TennisMatchScoreState(
            currentGame: .points(teamA: .love, teamB: .forty),
            teamAGames: 2,
            teamBGames: 3,
            completedSets: completedSets,
            currentGameIndex: 9,
            currentSetIndex: 1,
            isMatchComplete: false
        )

        let updated = try apply(.teamBWonRally, to: state)

        #expect(updated.teamAGames == 2)
        #expect(updated.teamBGames == 4)
        #expect(updated.completedSets == completedSets)
        #expect(updated.currentGameIndex == 10)
        #expect(updated.currentSetIndex == 1)
        #expect(updated.setPhase == .regularGame)
        #expect(!updated.isMatchComplete)
    }

    @Test
    func rejectsCompletedGameWithoutSetRules() throws {
        let configuration = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .fixedGames(count: 4),
            deuceRule: .advantage,
            servingRule: .standard
        )
        let state = TennisMatchScoreState(currentGame: .points(teamA: .forty, teamB: .love))

        #expect(throws: ScoringEngineError.missingSetRules) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: .tennis(state),
                configuration: configuration
            )
        }
    }
}

private extension TennisSetEngineTests {
    /// Standard advantage-set rules without a tiebreak.
    nonisolated var standardSetRules: SetRules {
        SetRules(gamesToWin: 6, winByGames: 2)
    }

    /// Short-set rules without a tiebreak.
    nonisolated var shortSetRules: SetRules {
        SetRules(gamesToWin: 4, winByGames: 2)
    }

    /// Applies a rally event to tennis state using standard advantage scoring.
    nonisolated func apply(
        _ event: ScoreEvent,
        to state: TennisMatchScoreState,
        setRules: SetRules? = nil
    ) throws -> TennisMatchScoreState {
        let configuration = try tennisConfiguration(setRules: setRules ?? standardSetRules)
        let updated = try TennisScoringEngine().apply(
            event: event,
            to: .tennis(state),
            configuration: configuration
        )

        guard case let .tennis(tennisState) = updated else {
            Issue.record("Expected tennis score state")
            return state
        }
        return tennisState
    }

    /// Awards a nearly completed game to a team from the supplied current-set score.
    nonisolated func winGame(
        for team: TeamSide,
        fromGames games: (teamA: Int, teamB: Int),
        setRules: SetRules? = nil
    ) throws -> TennisMatchScoreState {
        let currentGame: TennisGameScore
        let event: ScoreEvent
        switch team {
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
                teamBGames: games.teamB
            ),
            setRules: setRules
        )
    }

    /// Creates a validated tennis configuration using the supplied set rules.
    nonisolated func tennisConfiguration(setRules: SetRules) throws -> ScoringConfiguration {
        try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(count: 3, setRules: setRules),
            deuceRule: .advantage,
            servingRule: .standard
        )
    }

    /// Records expectations shared by every completed-set transition.
    nonisolated func expectFreshSet(_ state: TennisMatchScoreState) {
        #expect(state.teamAGames == 0)
        #expect(state.teamBGames == 0)
        #expect(state.currentGame == .points(teamA: .love, teamB: .love))
        #expect(state.setPhase == .regularGame)
        #expect(!state.isMatchComplete)
    }
}
