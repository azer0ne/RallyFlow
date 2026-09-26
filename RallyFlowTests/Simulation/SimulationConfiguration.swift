import Foundation
#if canImport(RallyFlow)
@testable import RallyFlow
#endif

nonisolated struct SimulationConfiguration: Sendable {
    let playerCount: Int
    let matchType: MatchType
    let courtCount: Int
    let steps: Int
    var context: SchedulingContext = .immediate
    var seed: UInt64 = 42
    var availabilityChanges: [AvailabilityChange] = []

    var label: String { "\(matchType.rawValue)-\(playerCount)p-\(courtCount)c-\(context.rawValue)" }
    var actualCapacity: Int { min(courtCount, playerCount / matchType.playersPerMatch) * matchType.playersPerMatch }
    var coverageCycle: Int { (playerCount + actualCapacity - 1) / actualCapacity }

    static let stableScenarios: [Self] = [
        .init(playerCount: 4, matchType: .doubles, courtCount: 1, steps: 40),
        .init(playerCount: 5, matchType: .doubles, courtCount: 1, steps: 40),
        .init(playerCount: 6, matchType: .doubles, courtCount: 1, steps: 40),
        .init(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 50),
        .init(playerCount: 8, matchType: .doubles, courtCount: 1, steps: 40),
        .init(playerCount: 8, matchType: .doubles, courtCount: 2, steps: 25),
        .init(playerCount: 9, matchType: .doubles, courtCount: 2, steps: 25),
        .init(playerCount: 10, matchType: .doubles, courtCount: 2, steps: 25),
        .init(playerCount: 12, matchType: .doubles, courtCount: 2, steps: 25),
        .init(playerCount: 12, matchType: .doubles, courtCount: 3, steps: 18),
        .init(playerCount: 3, matchType: .singles, courtCount: 1, steps: 40),
        .init(playerCount: 4, matchType: .singles, courtCount: 1, steps: 40),
        .init(playerCount: 4, matchType: .singles, courtCount: 2, steps: 25),
        .init(playerCount: 6, matchType: .singles, courtCount: 2, steps: 25)
    ]
}

nonisolated struct AvailabilityChange: Sendable {
    let step: Int
    let playerNumber: Int
    let status: ParticipantStatus
}

nonisolated enum SimulationStrategy: String, Sendable {
    case fairSocial
    case seededRandom
}

nonisolated func simulationID(_ number: Int) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(number / 256), UInt8(number % 256)))
}
