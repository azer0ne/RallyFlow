//
//  TennisScoringEngineTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

nonisolated struct TennisScoringEngineTests {

    @Test
    func progressesTeamAFromLoveToGame() throws {
        var state = MatchScoreState.tennis(TennisMatchScoreState())

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .fifteen, teamB: .love))

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .thirty, teamB: .love))

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .forty, teamB: .love))

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: state).teamAGames == 1)
        #expect(tennisState(from: state).teamBGames == 0)
    }

    @Test
    func progressesTeamBFromLoveToGame() throws {
        var state = MatchScoreState.tennis(TennisMatchScoreState())

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .fifteen))

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .thirty))

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .forty))

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: state).teamAGames == 0)
        #expect(tennisState(from: state).teamBGames == 1)
    }

    @Test
    func teamAForcesDeuceFromThirtyForty() throws {
        let state = tennisMatchState(currentGame: .points(teamA: .thirty, teamB: .forty))

        let updated = try apply(.teamAWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .deuce)
    }

    @Test
    func teamBForcesDeuceFromFortyThirty() throws {
        let state = tennisMatchState(currentGame: .points(teamA: .forty, teamB: .thirty))

        let updated = try apply(.teamBWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .deuce)
    }

    @Test
    func teamAGainsAdvantageFromDeuce() throws {
        let state = tennisMatchState(currentGame: .deuce)

        let updated = try apply(.teamAWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .advantage(.teamA))
    }

    @Test
    func teamBGainsAdvantageFromDeuce() throws {
        let state = tennisMatchState(currentGame: .deuce)

        let updated = try apply(.teamBWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .advantage(.teamB))
    }

    @Test
    func advantageTeamAWinsGameWhenTeamAWinsRally() throws {
        let state = tennisMatchState(currentGame: .advantage(.teamA))

        let updated = try apply(.teamAWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: updated).teamAGames == 1)
    }

    @Test
    func advantageTeamAReturnsToDeuceWhenTeamBWinsRally() throws {
        let state = tennisMatchState(currentGame: .advantage(.teamA))

        let updated = try apply(.teamBWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .deuce)
    }

    @Test
    func advantageTeamBWinsGameWhenTeamBWinsRally() throws {
        let state = tennisMatchState(currentGame: .advantage(.teamB))

        let updated = try apply(.teamBWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: updated).teamBGames == 1)
    }

    @Test
    func advantageTeamBReturnsToDeuceWhenTeamAWinsRally() throws {
        let state = tennisMatchState(currentGame: .advantage(.teamB))

        let updated = try apply(.teamAWonRally, to: state)

        #expect(tennisState(from: updated).currentGame == .deuce)
    }

    @Test
    func noAdTeamAWinsDecidingPoint() throws {
        let state = tennisMatchState(currentGame: .points(teamA: .forty, teamB: .forty))

        let updated = try apply(.teamAWonRally, to: state, deuceRule: .noAd)

        #expect(tennisState(from: updated).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: updated).teamAGames == 1)
    }

    @Test
    func noAdTeamBWinsDecidingPoint() throws {
        let state = tennisMatchState(currentGame: .points(teamA: .forty, teamB: .forty))

        let updated = try apply(.teamBWonRally, to: state, deuceRule: .noAd)

        #expect(tennisState(from: updated).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: updated).teamBGames == 1)
    }

    @Test
    func noAdNeverCreatesAdvantageAfterDecidingPoint() throws {
        let state = tennisMatchState(currentGame: .deuce)

        let updated = try apply(.teamAWonRally, to: state, deuceRule: .noAd)

        #expect(tennisState(from: updated).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: updated).teamAGames == 1)
    }

    @Test
    func supportsRepeatedDeuceAndAlternatingAdvantage() throws {
        var state = tennisMatchState(currentGame: .deuce)

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .advantage(.teamA))

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .deuce)

        state = try apply(.teamBWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .advantage(.teamB))

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .deuce)

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .advantage(.teamA))

        state = try apply(.teamAWonRally, to: state)
        #expect(tennisState(from: state).currentGame == .points(teamA: .love, teamB: .love))
        #expect(tennisState(from: state).teamAGames == 1)
    }

    @Test
    func preservesStateOutsideCurrentGame() throws {
        let completedSets = [SetScore(teamAGames: 6, teamBGames: 4)]
        let initialState = TennisMatchScoreState(
            currentGame: .points(teamA: .love, teamB: .love),
            teamAGames: 2,
            teamBGames: 3,
            completedSets: completedSets,
            currentGameIndex: 5,
            currentSetIndex: 1,
            isMatchComplete: false
        )

        let updated = try apply(.teamAWonRally, to: .tennis(initialState))
        let result = tennisState(from: updated)

        #expect(result.currentGame == .points(teamA: .fifteen, teamB: .love))
        #expect(result.teamAGames == 2)
        #expect(result.teamBGames == 3)
        #expect(result.completedSets == completedSets)
        #expect(result.currentGameIndex == 5)
        #expect(result.currentSetIndex == 1)
        #expect(!result.isMatchComplete)
    }

    @Test
    func rejectsIncompatiblePointSystem() throws {
        let configuration = try ScoringConfiguration(
            style: .rally,
            pointSystem: .rally,
            matchStructure: .raceToPoints(target: 21, winBy: 2, cap: nil),
            servingRule: .standard
        )

        #expect(throws: ScoringEngineError.incompatiblePointSystem) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: .tennis(TennisMatchScoreState()),
                configuration: configuration
            )
        }
    }

    @Test
    func rejectsIncompatibleScoreState() throws {
        let configuration = try tennisConfiguration(deuceRule: .advantage)

        #expect(throws: ScoringEngineError.incompatibleScoreState) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: .rally(RallyMatchScoreState()),
                configuration: configuration
            )
        }
    }

    @Test
    func rejectsMissingDeuceRule() throws {
        let configuration = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 1,
                setRules: SetRules(gamesToWin: 6, winByGames: 2)
            ),
            servingRule: .standard
        )

        #expect(throws: ScoringEngineError.missingDeuceRule) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: .tennis(TennisMatchScoreState()),
                configuration: configuration
            )
        }
    }

    @Test
    func rejectsUndo() throws {
        let configuration = try tennisConfiguration(deuceRule: .advantage)

        #expect(throws: ScoringEngineError.unsupportedEvent) {
            try TennisScoringEngine().apply(
                event: .undo,
                to: .tennis(TennisMatchScoreState()),
                configuration: configuration
            )
        }
    }

    @Test
    func rejectsRallyAfterGameCompletion() throws {
        let configuration = try tennisConfiguration(deuceRule: .advantage)

        #expect(throws: ScoringEngineError.gameAlreadyComplete) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: tennisMatchState(currentGame: .game(.teamA)),
                configuration: configuration
            )
        }
    }
}

private extension TennisScoringEngineTests {
    /// Applies one event using a valid tennis configuration.
    nonisolated func apply(
        _ event: ScoreEvent,
        to state: MatchScoreState,
        deuceRule: DeuceRule = .advantage
    ) throws -> MatchScoreState {
        try TennisScoringEngine().apply(
            event: event,
            to: state,
            configuration: tennisConfiguration(deuceRule: deuceRule)
        )
    }

    /// Creates a valid configuration for single-game tennis point tests.
    nonisolated func tennisConfiguration(deuceRule: DeuceRule) throws -> ScoringConfiguration {
        try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 1,
                setRules: SetRules(gamesToWin: 6, winByGames: 2)
            ),
            deuceRule: deuceRule,
            servingRule: .standard
        )
    }

    /// Creates a tennis match state containing the supplied current-game score.
    nonisolated func tennisMatchState(currentGame: TennisGameScore) -> MatchScoreState {
        .tennis(TennisMatchScoreState(currentGame: currentGame))
    }

    /// Extracts tennis-specific state from a match score.
    nonisolated func tennisState(from state: MatchScoreState) -> TennisMatchScoreState {
        guard case let .tennis(tennisState) = state else {
            Issue.record("Expected tennis score state")
            return TennisMatchScoreState()
        }
        return tennisState
    }
}
