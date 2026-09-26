import Foundation

/// Serializable evidence excludes raw UI models and records timing separately from deterministic metrics.
nonisolated struct SimulationDiagnostic: Codable {
    let scenario: String
    let strategy: String
    let steps: Int
    let matches: Int
    let spread: Int
    let maximumPrefixSpread: Int
    let variance: Double
    let maximumWait: Int
    let maximumPlay: Int
    let repeatedPartners: Int
    let repeatedOpponents: Int
    let uniquePartners: Int
    let uniqueOpponents: Int
    let highestPartnerFrequency: Int
    let highestOpponentFrequency: Int
    let minimumPartnerVariety: Int
    let minimumOpponentVariety: Int
    let relationshipComponents: Int
    let starved: Bool
    let matchesByPlayer: [Int]
    let longestPlayByPlayer: [Int]
    let longestWaitByPlayer: [Int]
    let candidateCount: Int
    let schedulerTotalSeconds: Double
    let schedulerMedianSeconds: Double
    let schedulerMaximumSeconds: Double

    init(configuration: SimulationConfiguration, strategy: SimulationStrategy, result: SimulationResult) {
        scenario = configuration.label
        self.strategy = strategy.rawValue + (strategy == .seededRandom ? "-\(configuration.seed)" : "")
        steps = configuration.steps
        let metrics = result.metrics
        matches = metrics.completedMatches
        spread = metrics.spread
        maximumPrefixSpread = metrics.maximumMatchCountSpread
        variance = metrics.variance
        maximumWait = metrics.maximumWait
        maximumPlay = metrics.maximumPlay
        repeatedPartners = metrics.repeatedPartnerships
        repeatedOpponents = metrics.repeatedOpponents
        uniquePartners = metrics.uniquePartnerships
        uniqueOpponents = metrics.uniqueOpponentPairs
        highestPartnerFrequency = metrics.mostRepeatedPartner
        highestOpponentFrequency = metrics.mostRepeatedOpponent
        minimumPartnerVariety = metrics.players.values.map { $0.partners.count }.min() ?? 0
        minimumOpponentVariety = metrics.players.values.map { $0.opponents.count }.min() ?? 0
        relationshipComponents = metrics.relationshipComponentCount
        starved = metrics.starvationObserved
        let ordered = metrics.players.keys.sorted { $0.uuidString < $1.uuidString }.map { metrics.players[$0]! }
        matchesByPlayer = ordered.map(\.matchesPlayed)
        longestPlayByPlayer = ordered.map(\.longestPlay)
        longestWaitByPlayer = ordered.map(\.longestRest)
        candidateCount = result.candidateCount
        let times = result.schedulerSeconds.sorted()
        schedulerTotalSeconds = times.reduce(0, +)
        schedulerMedianSeconds = times.isEmpty ? 0 : times[times.count / 2]
        schedulerMaximumSeconds = times.last ?? 0
    }
}

#if MATCHMAKING_DIAGNOSTICS
@main
struct MatchmakingDiagnostics {
    static func main() throws {
        let multiplier = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 1
        guard (1...20).contains(multiplier) else { throw SimulationError.invalidConfiguration }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func run(_ configuration: SimulationConfiguration, _ strategy: SimulationStrategy) throws {
            let result = try MatchmakingSimulator().run(configuration, strategy: strategy)
            let record = SimulationDiagnostic(configuration: configuration, strategy: strategy, result: result)
            print(String(decoding: try encoder.encode(record), as: UTF8.self))
            fflush(stdout)
        }
        for original in SimulationConfiguration.stableScenarios {
            let configuration = SimulationConfiguration(playerCount: original.playerCount, matchType: original.matchType,
                courtCount: original.courtCount, steps: original.steps * multiplier)
            try run(configuration, .fairSocial)
        }
        for seed: UInt64 in [1, 42, 2026] {
            try run(.init(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 50 * multiplier, seed: seed), .seededRandom)
        }
        for count in [5, 6, 7] {
            try run(.init(playerCount: count, matchType: .doubles, courtCount: 1, steps: 40 * multiplier,
                          context: .upcoming), .fairSocial)
        }
        try run(.init(playerCount: 10, matchType: .doubles, courtCount: 2, steps: 25 * multiplier,
                      context: .upcoming), .fairSocial)
        try run(.init(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 30 * multiplier,
            availabilityChanges: [.init(step: 5, playerNumber: 1, status: .resting),
                                  .init(step: 8, playerNumber: 1, status: .ready),
                                  .init(step: 14, playerNumber: 7, status: .left)]), .fairSocial)
    }
}
#endif
