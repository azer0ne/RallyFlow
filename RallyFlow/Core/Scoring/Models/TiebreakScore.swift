//
//  TiebreakScore.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated struct TiebreakScore: Codable, Hashable, Sendable {
    var teamAPoints: Int
    var teamBPoints: Int
    let startingServer: TeamSide
    
    nonisolated var pointsPlayed: Int {
        teamAPoints + teamBPoints
    }
    
    nonisolated var servingSide: TeamSide {
        guard pointsPlayed > 0 else {
            return startingServer
        }
        
        let twoPointServiceBlock = (pointsPlayed - 1) / 2
        if twoPointServiceBlock.isMultiple(of: 2) {
            return opposite(of: startingServer)
        }
        return startingServer
    }
    
    init(
        teamAPoints: Int = 0,
        teamBPoints: Int = 0,
        startingServer: TeamSide
    ) {
        self.teamAPoints = teamAPoints
        self.teamBPoints = teamBPoints
        self.startingServer = startingServer
    }
}

private extension TiebreakScore {
    
    nonisolated func opposite(of side: TeamSide) -> TeamSide {
        switch side {
        case .teamA:
            return .teamB
        case .teamB:
            return .teamA
        }
    }
}
