/// The live numeric score and serving origin of a tennis tiebreak.
nonisolated struct TiebreakScore: Codable, Hashable, Sendable {
    /// Team A's tiebreak points.
    var teamAPoints: Int

    /// Team B's tiebreak points.
    var teamBPoints: Int

    /// The team that serves the first tiebreak point.
    let startingServer: TeamSide

    /// The total number of completed tiebreak points.
    nonisolated var pointsPlayed: Int {
        teamAPoints + teamBPoints
    }

    /// The team serving the next tiebreak point.
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

    /// Creates a tiebreak score, initially zero-zero by default.
    ///
    /// - Parameters:
    ///   - teamAPoints: Team A's current tiebreak points.
    ///   - teamBPoints: Team B's current tiebreak points.
    ///   - startingServer: The team serving the first point.
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
    /// Returns the team opposite the supplied side.
    nonisolated func opposite(of side: TeamSide) -> TeamSide {
        switch side {
        case .teamA:
            return .teamB
        case .teamB:
            return .teamA
        }
    }
}
