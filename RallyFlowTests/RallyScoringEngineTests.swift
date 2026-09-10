//
//  RallyScoringEngineTests.swift
//  RallyFlowTests
//
//  Created by Arez on 09/09/26.
//

import Testing
@testable import RallyFlow

nonisolated struct RallyScoringEngineTests {
    @Test
    func awardsOnePointPerRally() throws {
        var state = RallyMatchScoreState()
        state = try apply(.teamAWonRally, to: state)
        #expect(state.currentGame == GameScore(teamAPoints: 1, teamBPoints: 0))
        state = try apply(.teamBWonRally, to: state)
        #expect(state.currentGame == GameScore(teamAPoints: 1, teamBPoints: 1))
    }

    @Test(arguments: [11, 15, 21], [ScoreEvent.teamAWonRally, .teamBWonRally])
    func racesToConfiguredTarget(target: Int, event: ScoreEvent) throws {
        let configuration = try configuration(.raceToPoints(target: target, winBy: 2, cap: nil))
        var state = RallyMatchScoreState()
        for _ in 0..<(target - 1) { state = try apply(event, to: state, configuration: configuration) }
        #expect(!state.isMatchComplete)
        state = try apply(event, to: state, configuration: configuration)
        #expect(state.isMatchComplete)
        #expect(try RallyScoringEngine().result(for: .rally(state), configuration: configuration)?.outcome
            == (event == .teamAWonRally ? .teamAWin : .teamBWin))
        #expect(throws: ScoringEngineError.matchAlreadyCompleted) {
            try apply(event, to: state, configuration: configuration)
        }
    }

    @Test(arguments: [1, 2])
    func obeysWinningMargin(winBy: Int) throws {
        let configuration = try configuration(.raceToPoints(target: 21, winBy: winBy, cap: nil))
        var state = RallyMatchScoreState(currentGame: GameScore(teamAPoints: 20, teamBPoints: 20))
        state = try apply(.teamAWonRally, to: state, configuration: configuration)
        #expect(state.isMatchComplete == (winBy == 1))
        if winBy == 2 {
            state = try apply(.teamAWonRally, to: state, configuration: configuration)
            #expect(state.currentGame == GameScore(teamAPoints: 22, teamBPoints: 20))
            #expect(state.isMatchComplete)
        }
    }

    @Test(arguments: [ScoreEvent.teamAWonRally, .teamBWonRally])
    func extendedScoresHaveNoArtificialCap(event: ScoreEvent) throws {
        var state = RallyMatchScoreState(currentGame: GameScore(teamAPoints: 29, teamBPoints: 29))
        state = try apply(event, to: state)
        #expect(!state.isMatchComplete)
        state = try apply(event, to: state)
        #expect(state.isMatchComplete)
        #expect(max(state.currentGame.teamAPoints, state.currentGame.teamBPoints) == 31)
    }

    @Test(arguments: [ScoreEvent.teamAWonRally, .teamBWonRally])
    func capOverridesMargin(event: ScoreEvent) throws {
        let configuration = try configuration(.raceToPoints(target: 21, winBy: 2, cap: 30))
        let state = RallyMatchScoreState(currentGame: GameScore(teamAPoints: 29, teamBPoints: 29))
        let updated = try apply(event, to: state, configuration: configuration)
        #expect(updated.isMatchComplete)
        #expect(max(updated.currentGame.teamAPoints, updated.currentGame.teamBPoints) == 30)
    }

    @Test(arguments: [3, 5], [ScoreEvent.teamAWonRally, .teamBWonRally])
    func bestOfGamesPreservesGamesAndResetsPoints(count: Int, winningEvent: ScoreEvent) throws {
        let configuration = try configuration(.bestOfGames(count: count, pointsPerGame: 15, winBy: 2, cap: nil))
        var state = RallyMatchScoreState()
        let losingEvent: ScoreEvent = winningEvent == .teamAWonRally ? .teamBWonRally : .teamAWonRally
        for game in 0..<count {
            let event = game.isMultiple(of: 2) ? winningEvent : losingEvent
            for _ in 0..<15 { state = try apply(event, to: state, configuration: configuration) }
            #expect(state.completedGames.count == game + 1)
            #expect(state.currentGame == GameScore())
            #expect(state.isMatchComplete == (game == count - 1))
        }
        #expect(state.completedGames[0] == (winningEvent == .teamAWonRally
            ? GameScore(teamAPoints: 15, teamBPoints: 0) : GameScore(teamAPoints: 0, teamBPoints: 15)))
        #expect(try RallyScoringEngine().result(for: .rally(state), configuration: configuration)?.outcome
            == (winningEvent == .teamAWonRally ? .teamAWin : .teamBWin))
    }

    @Test
    func rejectsIncompatibleInputsAndUndo() throws {
        let engine = RallyScoringEngine()
        let configuration = try configuration()
        #expect(throws: ScoringEngineError.incompatibleScoreState) {
            try engine.apply(event: .teamAWonRally, to: .tennis(TennisMatchScoreState()), configuration: configuration)
        }
        #expect(throws: ScoringEngineError.incompatiblePointSystem) {
            try engine.apply(event: .teamAWonRally, to: .rally(RallyMatchScoreState()),
                configuration: OneServeEachTests().configuration())
        }
        #expect(throws: ScoringEngineError.unsupportedEvent) { try apply(.undo, to: RallyMatchScoreState()) }
        #expect(throws: ScoringEngineError.invalidMatchState) {
            try apply(.teamAWonRally, to: RallyMatchScoreState(currentGame: GameScore(teamAPoints: -1)))
        }
    }

    @Test(arguments: [0, -1, 2, 4])
    func rejectsInvalidBestOfCounts(count: Int) {
        #expect(throws: ScoringConfigurationError.self) {
            try configuration(.bestOfGames(count: count, pointsPerGame: 15, winBy: 2, cap: nil))
        }
    }

    func configuration(_ structure: MatchStructure = .raceToPoints(target: 21, winBy: 2, cap: nil)) throws -> ScoringConfiguration {
        try ScoringConfiguration(style: .rally, pointSystem: .rally, matchStructure: structure, servingRule: .standard)
    }

    func apply(_ event: ScoreEvent, to state: RallyMatchScoreState,
               configuration: ScoringConfiguration? = nil) throws -> RallyMatchScoreState {
        let updated = try RallyScoringEngine().apply(event: event, to: .rally(state),
            configuration: configuration ?? self.configuration())
        guard case .rally(let result) = updated else { throw ScoringEngineError.incompatibleScoreState }
        return result
    }
}
