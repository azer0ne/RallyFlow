//
//  TennisPointEngine.swift
//  RallyFlow
//
//  Created by Arez on 10/09/26.
//

nonisolated struct TennisPointEngine: Sendable {
    nonisolated func score(
        afterRallyWonBy rallyWinner: TeamSide,
        currentScore: TennisGameScore,
        deuceRule: DeuceRule
    ) throws -> TennisGameScore {
        switch currentScore {
        case let .points(teamAPoint, teamBPoint):
            return scoreFromPoints(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                rallyWinner: rallyWinner,
                deuceRule: deuceRule
            )
            
        case .deuce:
            switch deuceRule {
            case .advantage:
                return .advantage(rallyWinner)
            case .noAd:
                return .game(rallyWinner)
            }
            
        case .advantage(let advantageSide):
            if advantageSide == rallyWinner {
                return .game(rallyWinner)
            }
            return .deuce
            
        case .game:
            throw ScoringEngineError.gameAlreadyComplete
        }
    }
    
    nonisolated func scoreFromPoints(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        rallyWinner: TeamSide,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch rallyWinner {
        case .teamA:
            return scoreAfterTeamAWins(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                deuceRule: deuceRule
            )
        case .teamB:
            return scoreAfterTeamBWins(
                teamAPoint: teamAPoint,
                teamBPoint: teamBPoint,
                deuceRule: deuceRule
            )
        }
    }
    
    nonisolated func scoreAfterTeamAWins(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch teamAPoint {
        case .love:
            return .points(teamA: .fifteen, teamB: teamBPoint)
        case .fifteen:
            return .points(teamA: .thirty, teamB: teamBPoint)
        case .thirty:
            if teamBPoint == .forty {
                return .deuce
            }
            return .points(teamA: .forty, teamB: teamBPoint)
        case .forty:
            if teamBPoint == .forty {
                return deuceRule == .advantage ? .advantage(.teamA) : .game(.teamA)
            }
            return .game(.teamA)
        }
    }
    
    nonisolated func scoreAfterTeamBWins(
        teamAPoint: TennisPoint,
        teamBPoint: TennisPoint,
        deuceRule: DeuceRule
    ) -> TennisGameScore {
        switch teamBPoint {
        case .love:
            return .points(teamA: teamAPoint, teamB: .fifteen)
        case .fifteen:
            return .points(teamA: teamAPoint, teamB: .thirty)
        case .thirty:
            if teamAPoint == .forty {
                return .deuce
            }
            return .points(teamA: teamAPoint, teamB: .forty)
        case .forty:
            if teamAPoint == .forty {
                return deuceRule == .advantage ? .advantage(.teamB) : .game(.teamB)
            }
            return .game(.teamB)
        }
    }
}
