import Foundation
#if canImport(RallyFlow)
@testable import RallyFlow
#endif

nonisolated struct SimulatedPlayerMetrics: Equatable, Sendable {
    var matchesPlayed = 0
    var eligibleOpportunities = 0
    var totalWaiting = 0
    var consecutiveRests = 0
    var consecutivePlay = 0
    var longestRest = 0
    var longestPlay = 0
    var partners: [Player.ID: Int] = [:]
    var opponents: [Player.ID: Int] = [:]
}

/// Engineering measurements derived independently from completed batch traces, not ranker scores.
nonisolated struct SimulationMetrics: Equatable, Sendable {
    var players: [Player.ID: SimulatedPlayerMetrics]
    var maximumMatchCountSpread = 0
    var starvationObserved = false
    var completedMatches = 0

    init(playerIDs: [Player.ID]) {
        players = Dictionary(uniqueKeysWithValues: playerIDs.map { ($0, SimulatedPlayerMetrics()) })
    }

    var minimumMatches: Int { players.values.map(\.matchesPlayed).min() ?? 0 }
    var maximumMatches: Int { players.values.map(\.matchesPlayed).max() ?? 0 }
    var spread: Int { maximumMatches - minimumMatches }
    var maximumWait: Int { players.values.map(\.longestRest).max() ?? 0 }
    var maximumPlay: Int { players.values.map(\.longestPlay).max() ?? 0 }
    var variance: Double {
        let counts = players.values.map { Double($0.matchesPlayed) }.sorted()
        let mean = counts.reduce(0, +) / Double(counts.count)
        return counts.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(counts.count)
    }
    var uniquePartnerships: Int { players.values.reduce(0) { $0 + $1.partners.count } / 2 }
    var uniqueOpponentPairs: Int { players.values.reduce(0) { $0 + $1.opponents.count } / 2 }
    var repeatedPartnerships: Int { players.values.reduce(0) { $0 + $1.partners.values.reduce(0) { $0 + max(0, $1 - 1) } } / 2 }
    var repeatedOpponents: Int { players.values.reduce(0) { $0 + $1.opponents.values.reduce(0) { $0 + max(0, $1 - 1) } } / 2 }
    var mostRepeatedPartner: Int { players.values.flatMap { $0.partners.values }.max() ?? 0 }
    var mostRepeatedOpponent: Int { players.values.flatMap { $0.opponents.values }.max() ?? 0 }

    /// Connected components of all observed relationships, in O(players + relationships).
    var relationshipComponentCount: Int {
        var remaining = Set(players.keys)
        var count = 0
        while let first = remaining.min(by: { $0.uuidString < $1.uuidString }) {
            count += 1
            var pending = [first]
            remaining.remove(first)
            while let playerID = pending.popLast() {
                let value = players[playerID]!
                let neighbors = Set(value.partners.keys).union(value.opponents.keys).intersection(remaining)
                remaining.subtract(neighbors)
                pending.append(contentsOf: neighbors)
            }
        }
        return count
    }

    mutating func record(matches: [MatchCandidate], eligibleIDs: Set<Player.ID>, coverageCycle: Int) {
        let selected = Set(matches.flatMap(\.playerIDs))
        for playerID in Array(players.keys) {
            var value = players[playerID]!
            if selected.contains(playerID) {
                value.matchesPlayed += 1
                value.eligibleOpportunities += 1
                value.consecutivePlay += 1
                value.consecutiveRests = 0
            } else if eligibleIDs.contains(playerID) {
                value.eligibleOpportunities += 1
                value.totalWaiting += 1
                value.consecutiveRests += 1
                value.consecutivePlay = 0
            } else {
                value.consecutiveRests = 0
                value.consecutivePlay = 0
            }
            value.longestRest = max(value.longestRest, value.consecutiveRests)
            value.longestPlay = max(value.longestPlay, value.consecutivePlay)
            players[playerID] = value
        }
        for match in matches {
            for team in [match.teamA, match.teamB] {
                for first in team.playerIDs {
                    for second in team.playerIDs where first != second {
                        players[first]!.partners[second, default: 0] += 1
                    }
                }
            }
            for first in match.teamA.playerIDs {
                for second in match.teamB.playerIDs {
                    players[first]!.opponents[second, default: 0] += 1
                    players[second]!.opponents[first, default: 0] += 1
                }
            }
        }
        completedMatches += matches.count
        maximumMatchCountSpread = max(maximumMatchCountSpread, spread)
        let eligibleMaximum = eligibleIDs.compactMap { players[$0]?.matchesPlayed }.max() ?? 0
        // Missing two full coverage cycles while at least two matches behind is an alarm, not a policy cap.
        starvationObserved = starvationObserved || eligibleIDs.contains {
            let value = players[$0]!
            return value.consecutiveRests >= 2 * coverageCycle && eligibleMaximum - value.matchesPlayed >= 2
        }
    }
}
