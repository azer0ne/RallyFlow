import Testing
@testable import RallyFlow

nonisolated struct TennisTiebreakEngineTests {

    @Test
    func awardsFirstPointToTeamA() throws {
        let progress = try apply(
            .teamAWonRally,
            to: TiebreakScore(startingServer: .teamA)
        )

        #expect(score(from: progress).teamAPoints == 1)
        #expect(score(from: progress).teamBPoints == 0)
    }

    @Test
    func awardsFirstPointToTeamB() throws {
        let progress = try apply(
            .teamBWonRally,
            to: TiebreakScore(startingServer: .teamA)
        )

        #expect(score(from: progress).teamAPoints == 0)
        #expect(score(from: progress).teamBPoints == 1)
    }

    @Test
    func teamACompletesTiebreakAtSevenFive() throws {
        let initial = TiebreakScore(
            teamAPoints: 6,
            teamBPoints: 5,
            startingServer: .teamA
        )

        let progress = try apply(.teamAWonRally, to: initial)

        #expect(
            progress == .completed(
                score: TiebreakScore(
                    teamAPoints: 7,
                    teamBPoints: 5,
                    startingServer: .teamA
                ),
                winner: .teamA
            )
        )
    }

    @Test
    func teamBCompletesTiebreakAtFiveSeven() throws {
        let initial = TiebreakScore(
            teamAPoints: 5,
            teamBPoints: 6,
            startingServer: .teamB
        )

        let progress = try apply(.teamBWonRally, to: initial)

        #expect(
            progress == .completed(
                score: TiebreakScore(
                    teamAPoints: 5,
                    teamBPoints: 7,
                    startingServer: .teamB
                ),
                winner: .teamB
            )
        )
    }

    @Test
    func continuesAtSevenSixAndCompletesAtEightSix() throws {
        let sixAll = TiebreakScore(
            teamAPoints: 6,
            teamBPoints: 6,
            startingServer: .teamA
        )

        let sevenSix = try apply(.teamAWonRally, to: sixAll)
        #expect(sevenSix == .inProgress(
            TiebreakScore(teamAPoints: 7, teamBPoints: 6, startingServer: .teamA)
        ))

        let eightSix = try apply(.teamAWonRally, to: score(from: sevenSix))
        #expect(eightSix == .completed(
            score: TiebreakScore(teamAPoints: 8, teamBPoints: 6, startingServer: .teamA),
            winner: .teamA
        ))
    }

    @Test
    func supportsExtendedTenEightCompletion() throws {
        let initial = TiebreakScore(
            teamAPoints: 9,
            teamBPoints: 8,
            startingServer: .teamA
        )

        let progress = try apply(.teamAWonRally, to: initial)

        #expect(progress == .completed(
            score: TiebreakScore(teamAPoints: 10, teamBPoints: 8, startingServer: .teamA),
            winner: .teamA
        ))
    }

    @Test
    func supportsExtendedFifteenThirteenCompletion() throws {
        let initial = TiebreakScore(
            teamAPoints: 14,
            teamBPoints: 13,
            startingServer: .teamB
        )

        let progress = try apply(.teamAWonRally, to: initial)

        #expect(progress == .completed(
            score: TiebreakScore(teamAPoints: 15, teamBPoints: 13, startingServer: .teamB),
            winner: .teamA
        ))
    }

    @Test
    func supportsTargetTenWithWinByTwo() throws {
        let tenEight = try apply(
            .teamAWonRally,
            to: TiebreakScore(teamAPoints: 9, teamBPoints: 8, startingServer: .teamA),
            target: 10
        )
        #expect(tenEight == .completed(
            score: TiebreakScore(teamAPoints: 10, teamBPoints: 8, startingServer: .teamA),
            winner: .teamA
        ))

        let tenNine = try apply(
            .teamAWonRally,
            to: TiebreakScore(teamAPoints: 9, teamBPoints: 9, startingServer: .teamA),
            target: 10
        )
        #expect(tenNine == .inProgress(
            TiebreakScore(teamAPoints: 10, teamBPoints: 9, startingServer: .teamA)
        ))

        let elevenNine = try apply(
            .teamAWonRally,
            to: score(from: tenNine),
            target: 10
        )
        #expect(elevenNine == .completed(
            score: TiebreakScore(teamAPoints: 11, teamBPoints: 9, startingServer: .teamA),
            winner: .teamA
        ))
    }

    @Test
    func entersTiebreakFromRequiredPhaseAndRecordsRally() throws {
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            setPhase: .tiebreakRequired,
            tiebreakStartingServer: .teamA
        )

        let updated = try applyToMatch(.teamAWonRally, state: state)

        guard case let .tiebreak(score) = updated.setPhase else {
            Issue.record("Expected active tiebreak state")
            return
        }
        #expect(score.teamAPoints == 1)
        #expect(score.teamBPoints == 0)
        #expect(score.startingServer == .teamA)
        #expect(score.servingSide == .teamB)
        #expect(updated.currentGame == .points(teamA: .love, teamB: .love))
    }

    @Test
    func teamATiebreakWinCompletesSetSevenSix() throws {
        let finalInput = TiebreakScore(
            teamAPoints: 6,
            teamBPoints: 5,
            startingServer: .teamA
        )
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            currentSetIndex: 0,
            setPhase: .tiebreak(finalInput)
        )

        let updated = try applyToMatch(.teamAWonRally, state: state)

        #expect(updated.completedSets == [
            SetScore(
                teamAGames: 7,
                teamBGames: 6,
                tiebreakScore: TiebreakScore(
                    teamAPoints: 7,
                    teamBPoints: 5,
                    startingServer: .teamA
                )
            )
        ])
        expectFreshStateAfterTiebreak(updated)
    }

    @Test
    func teamBTiebreakWinCompletesSetSixSeven() throws {
        let finalInput = TiebreakScore(
            teamAPoints: 5,
            teamBPoints: 6,
            startingServer: .teamB
        )
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            setPhase: .tiebreak(finalInput),
            tiebreakStartingServer: .teamB
        )

        let updated = try applyToMatch(.teamBWonRally, state: state)

        #expect(updated.completedSets == [
            SetScore(
                teamAGames: 6,
                teamBGames: 7,
                tiebreakScore: TiebreakScore(
                    teamAPoints: 5,
                    teamBPoints: 7,
                    startingServer: .teamB
                )
            )
        ])
        expectFreshStateAfterTiebreak(updated)
    }

    @Test
    func preservesEarlierCompletedSetWhenTiebreakCompletes() throws {
        let firstSet = SetScore(teamAGames: 6, teamBGames: 3)
        let finalInput = TiebreakScore(
            teamAPoints: 6,
            teamBPoints: 4,
            startingServer: .teamA
        )
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            completedSets: [firstSet],
            currentSetIndex: 1,
            setPhase: .tiebreak(finalInput)
        )

        let updated = try applyToMatch(.teamAWonRally, state: state)

        #expect(updated.completedSets.count == 2)
        #expect(updated.completedSets[0] == firstSet)
        #expect(updated.completedSets[1].teamAGames == 7)
        #expect(updated.completedSets[1].teamBGames == 6)
        #expect(updated.completedSets[1].tiebreakScore?.teamAPoints == 7)
        #expect(updated.completedSets[1].tiebreakScore?.teamBPoints == 4)
        #expect(updated.currentSetIndex == 2)
        #expect(!updated.isMatchComplete)
    }

    @Test
    func rotatesServeFromTeamAInStandardSequence() throws {
        let sides = try servingSequence(startingServer: .teamA, pointCount: 9)

        #expect(sides == [
            .teamA, .teamB, .teamB, .teamA, .teamA,
            .teamB, .teamB, .teamA, .teamA
        ])
    }

    @Test
    func rotatesServeFromTeamBInStandardSequence() throws {
        let sides = try servingSequence(startingServer: .teamB, pointCount: 9)

        #expect(sides == [
            .teamB, .teamA, .teamA, .teamB, .teamB,
            .teamA, .teamA, .teamB, .teamB
        ])
    }

    @Test
    func rejectsInvalidTiebreakConfiguration() {
        let score = TiebreakScore(startingServer: .teamA)

        #expect(throws: ScoringEngineError.invalidTiebreakConfiguration) {
            try TennisTiebreakEngine().apply(
                event: .teamAWonRally,
                to: score,
                target: 0,
                winBy: 2
            )
        }
        #expect(throws: ScoringEngineError.invalidTiebreakConfiguration) {
            try TennisTiebreakEngine().apply(
                event: .teamAWonRally,
                to: score,
                target: 7,
                winBy: 0
            )
        }
    }

    @Test
    func rejectsMissingTiebreakRulesDuringIntegration() throws {
        let configuration = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 3,
                setRules: SetRules(gamesToWin: 6, winByGames: 2)
            ),
            deuceRule: .advantage,
            servingRule: .standard
        )
        let state = TennisMatchScoreState(
            teamAGames: 6,
            teamBGames: 6,
            setPhase: .tiebreakRequired
        )

        #expect(throws: ScoringEngineError.invalidTiebreakConfiguration) {
            try TennisScoringEngine().apply(
                event: .teamAWonRally,
                to: .tennis(state),
                configuration: configuration
            )
        }
    }

    @Test
    func rejectsScoringAfterSuppliedTiebreakIsComplete() {
        let completedScore = TiebreakScore(
            teamAPoints: 7,
            teamBPoints: 5,
            startingServer: .teamA
        )

        #expect(throws: ScoringEngineError.tiebreakAlreadyComplete) {
            try TennisTiebreakEngine().apply(
                event: .teamAWonRally,
                to: completedScore,
                target: 7,
                winBy: 2
            )
        }
    }
}

private extension TennisTiebreakEngineTests {
    /// Applies one event to a standalone configurable tiebreak.
    nonisolated func apply(
        _ event: ScoreEvent,
        to score: TiebreakScore,
        target: Int = 7,
        winBy: Int = 2
    ) throws -> TiebreakProgress {
        try TennisTiebreakEngine().apply(
            event: event,
            to: score,
            target: target,
            winBy: winBy
        )
    }

    /// Returns the score carried by either tiebreak progress case.
    nonisolated func score(from progress: TiebreakProgress) -> TiebreakScore {
        switch progress {
        case .inProgress(let score), .completed(let score, _):
            return score
        }
    }

    /// Applies one event through the integrated tennis scoring entry point.
    nonisolated func applyToMatch(
        _ event: ScoreEvent,
        state: TennisMatchScoreState
    ) throws -> TennisMatchScoreState {
        let updated = try TennisScoringEngine().apply(
            event: event,
            to: .tennis(state),
            configuration: try standardTiebreakConfiguration()
        )

        guard case let .tennis(tennisState) = updated else {
            Issue.record("Expected tennis score state")
            return state
        }
        return tennisState
    }

    /// Creates standard set rules with a seven-point tiebreak at six-all.
    nonisolated func standardTiebreakConfiguration() throws -> ScoringConfiguration {
        try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 3,
                setRules: SetRules(
                    gamesToWin: 6,
                    winByGames: 2,
                    tiebreakAt: 6,
                    tiebreakTarget: 7,
                    tiebreakWinBy: 2
                )
            ),
            deuceRule: .advantage,
            servingRule: .standard
        )
    }

    /// Returns serving sides before each requested tiebreak point.
    nonisolated func servingSequence(
        startingServer: TeamSide,
        pointCount: Int
    ) throws -> [TeamSide] {
        var score = TiebreakScore(startingServer: startingServer)
        var sequence: [TeamSide] = []

        for _ in 0..<pointCount {
            sequence.append(score.servingSide)
            let progress = try apply(
                .teamAWonRally,
                to: score,
                target: 100,
                winBy: 2
            )
            score = self.score(from: progress)
        }
        return sequence
    }

    /// Records expectations shared by every completed tiebreak transition.
    nonisolated func expectFreshStateAfterTiebreak(_ state: TennisMatchScoreState) {
        #expect(state.teamAGames == 0)
        #expect(state.teamBGames == 0)
        #expect(state.currentGame == .points(teamA: .love, teamB: .love))
        #expect(state.setPhase == .regularGame)
        #expect(state.currentSetIndex == 1)
        #expect(!state.isMatchComplete)
    }
}
