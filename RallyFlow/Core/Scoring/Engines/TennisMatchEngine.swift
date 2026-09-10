//
//  TennisMatchEngine.swift
//  RallyFlow
//
//  Created by Arez on 27/08/26.
//

/// A deterministic engine for evaluating completed sets in a tennis match.
nonisolated struct TennisMatchEngine: Sendable {
    /// Creates a stateless tennis match engine.
    init() {}

    /// Evaluates whether the latest completed set ends the configured match.
    ///
    /// Set wins are derived from completed set scores rather than stored separately.
    ///
    /// - Parameters:
    ///   - state: Tennis state containing the completed sets to evaluate.
    ///   - configuration: A tennis best-of-sets configuration.
    /// - Returns: State whose match-completion flag reflects the completed set scores.
    /// - Throws: ``ScoringEngineError`` when the configuration or completed sets are invalid.
    nonisolated func evaluateAfterCompletedSet(
        in state: TennisMatchScoreState,
        configuration: ScoringConfiguration
    ) throws -> TennisMatchScoreState {
        guard configuration.pointSystem == .tennis else {
            throw ScoringEngineError.incompatiblePointSystem
        }
        guard case .bestOfSets(let count, _) = configuration.matchStructure else {
            throw ScoringEngineError.missingSetRules
        }
        guard !state.completedSets.isEmpty, state.completedSets.count <= count else {
            throw ScoringEngineError.invalidMatchState
        }

        let setWins = try setWins(in: state.completedSets)
        let requiredSetsToWin = (count / 2) + 1
        guard !(setWins.teamA >= requiredSetsToWin && setWins.teamB >= requiredSetsToWin) else {
            throw ScoringEngineError.invalidMatchState
        }

        var updatedState = state
        updatedState.isMatchComplete = setWins.teamA >= requiredSetsToWin
            || setWins.teamB >= requiredSetsToWin
        return updatedState
    }

    /// Produces an immutable result for a completed tennis match.
    ///
    /// - Parameter state: A match score state that may represent a completed match.
    /// - Returns: The completed result, or `nil` while the match remains active.
    /// - Throws: ``ScoringEngineError`` when the state is incompatible or inconsistent.
    nonisolated func result(for state: MatchScoreState) throws -> MatchResult? {
        guard case .tennis(let tennisState) = state else {
            throw ScoringEngineError.incompatibleScoreState
        }
        guard tennisState.isMatchComplete else {
            return nil
        }

        let setWins = try setWins(in: tennisState.completedSets)
        let outcome: MatchOutcome
        if setWins.teamA > setWins.teamB {
            outcome = .teamAWin
        } else if setWins.teamB > setWins.teamA {
            outcome = .teamBWin
        } else {
            throw ScoringEngineError.invalidMatchState
        }

        return MatchResult(outcome: outcome, finalScore: state)
    }
}

private extension TennisMatchEngine {
    /// Returns the set-win totals derived from completed set scores.
    nonisolated func setWins(in completedSets: [SetScore]) throws -> (
        teamA: Int,
        teamB: Int
    ) {
        try completedSets.reduce(into: (teamA: 0, teamB: 0)) { setWins, setScore in
            if setScore.teamAGames > setScore.teamBGames {
                setWins.teamA += 1
            } else if setScore.teamBGames > setScore.teamAGames {
                setWins.teamB += 1
            } else {
                throw ScoringEngineError.invalidCompletedSet
            }
        }
    }
}
