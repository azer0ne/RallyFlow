//
//  OneServeEachScoreState.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated struct OneServeEachScoreState: Codable, Hashable, Sendable {
    let serviceOrder: DoublesServiceOrder
    var completedGames: [TeamSide] = []
    var phase: OneServeEachPhase = .serviceGame(.points(teamA: .love, teamB: .love))

    var currentServiceGameIndex: Int? {
        guard case .serviceGame = phase, completedGames.count < 4 else { return nil }
        return completedGames.count
    }

    var currentGameNumber: Int? { currentServiceGameIndex.map { $0 + 1 } }
    var currentServer: ServicePlayer? {
        currentServiceGameIndex.map { serviceOrder.players[$0] }
    }
    var nextServer: ServicePlayer? {
        guard let index = currentServiceGameIndex, index < 3 else { return nil }
        return serviceOrder.players[index + 1]
    }
    var teamAGames: Int { completedGames.filter { $0 == .teamA }.count }
    var teamBGames: Int { completedGames.filter { $0 == .teamB }.count }
    var isMatchComplete: Bool {
        if case .completed = phase { return true }
        return false
    }
    var result: MatchResult? {
        guard case .completed(let outcome, _) = phase else { return nil }
        return MatchResult(outcome: outcome, finalScore: .oneServeEach(self))
    }
}
