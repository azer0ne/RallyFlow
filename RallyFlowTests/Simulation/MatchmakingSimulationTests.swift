import Foundation
import Testing
@testable import RallyFlow

@Suite(.serialized)
nonisolated struct MatchmakingSimulationTests {
    @Test(arguments: Array(SimulationConfiguration.stableScenarios.indices))
    func stableSessionsStayWithinGeometryBasedAlarms(scenarioIndex: Int) throws {
        let configuration = SimulationConfiguration.stableScenarios[scenarioIndex]
        let result = try MatchmakingSimulator().run(configuration)
        let metrics = result.metrics
        #expect(metrics.completedMatches == configuration.steps * configuration.actualCapacity / configuration.matchType.playersPerMatch)
        #expect(metrics.minimumMatches > 0)
        #expect(metrics.maximumMatchCountSpread <= 2)
        #expect(metrics.maximumWait < 2 * configuration.coverageCycle)
        #expect(!metrics.starvationObserved)
        if configuration.actualCapacity == configuration.playerCount {
            #expect(metrics.spread == 0)
            #expect(metrics.maximumWait == 0)
            #expect(metrics.maximumPlay == configuration.steps)
        } else {
            let restingPlaces = configuration.playerCount - configuration.actualCapacity
            let balancedRun = (configuration.actualCapacity + restingPlaces - 1) / restingPlaces
            #expect(metrics.maximumPlay <= 2 * balancedRun)
        }
        if configuration.matchType == .doubles {
            let pairs = configuration.playerCount * (configuration.playerCount - 1) / 2
            let partnerMeanCeiling = (metrics.completedMatches * 2 + pairs - 1) / pairs
            let opponentMeanCeiling = (metrics.completedMatches * 4 + pairs - 1) / pairs
            #expect(metrics.mostRepeatedPartner <= 3 * partnerMeanCeiling)
            #expect(metrics.mostRepeatedOpponent <= 3 * opponentMeanCeiling)
            for player in metrics.players.values {
                #expect(player.partners.count >= (configuration.playerCount - 1) / 2)
                #expect(player.opponents.count >= (configuration.playerCount - 1) / 2)
            }
        }
        for (playerID, value) in metrics.players {
            #expect(value.matchesPlayed + value.totalWaiting == configuration.steps)
            #expect(result.history.matchesPlayed(for: playerID) == value.matchesPlayed)
            for (otherID, count) in value.partners {
                #expect(result.history.partnerCount(between: playerID, and: otherID) == count)
            }
            for (otherID, count) in value.opponents {
                #expect(result.history.opponentCount(between: playerID, and: otherID) == count)
            }
        }
    }

    @Test(arguments: [SimulationStrategy.fairSocial, .seededRandom])
    func sameSeedAndInputReproduceHistoryAndEveryMetric(strategy: SimulationStrategy) throws {
        let configuration = SimulationConfiguration(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 50)
        let first = try MatchmakingSimulator().run(configuration, strategy: strategy)
        let second = try MatchmakingSimulator().run(configuration, strategy: strategy)
        #expect(first.history == second.history)
        #expect(first.metrics == second.metrics)
        #expect(first.trace == second.trace)
    }

    @Test
    func fairSocialImprovesParticipationAgainstThreeSeededBaselines() throws {
        var configuration = SimulationConfiguration(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 50)
        let fair = try MatchmakingSimulator().run(configuration)
        for seed: UInt64 in [1, 42, 2026] {
            configuration.seed = seed
            let random = try MatchmakingSimulator().run(configuration, strategy: .seededRandom)
            #expect(fair.metrics.spread <= random.metrics.spread)
            #expect(fair.metrics.maximumWait <= random.metrics.maximumWait)
            #expect(random.metrics.completedMatches == fair.metrics.completedMatches)
            #expect(random.history.entries.allSatisfy { Set($0.candidate.playerIDs).count == 4 })
        }
    }

    @Test(arguments: [5, 6, 7])
    func upcomingProjectionEvolvesWithoutRecordingActiveMatchesTwice(playerCount: Int) throws {
        let configuration = SimulationConfiguration(playerCount: playerCount, matchType: .doubles,
            courtCount: 1, steps: 40, context: .upcoming)
        let result = try MatchmakingSimulator().run(configuration)
        #expect(result.history.entries.count == 40)
        #expect(result.metrics.maximumMatchCountSpread <= 2)
        #expect(result.metrics.maximumWait < 2 * configuration.coverageCycle)
        #expect(!result.metrics.starvationObserved)
        for pair in zip(result.trace, result.trace.dropFirst()) {
            let firstIDs = Set(pair.0.matches.flatMap(\.playerIDs))
            let nextIDs = Set(pair.1.matches.flatMap(\.playerIDs))
            #expect(firstIDs.intersection(nextIDs).count >= 8 - playerCount)
        }
    }

    @Test
    func upcomingMultiCourtSessionPreservesOpportunityAccounting() throws {
        let result = try MatchmakingSimulator().run(.init(playerCount: 10, matchType: .doubles,
            courtCount: 2, steps: 25, context: .upcoming))
        #expect(result.history.entries.count == 50)
        #expect(result.metrics.maximumMatchCountSpread <= 2)
        #expect(result.metrics.maximumWait <= 3)
        #expect(!result.metrics.starvationObserved)
        #expect(result.trace.allSatisfy { Set($0.matches.flatMap(\.playerIDs)).count == 8 })
    }

    @Test
    func voluntaryRestReturnAndDepartureHaveDistinctEligibility() throws {
        let configuration = SimulationConfiguration(playerCount: 7, matchType: .doubles, courtCount: 1, steps: 30,
            availabilityChanges: [.init(step: 5, playerNumber: 1, status: .resting),
                                  .init(step: 8, playerNumber: 1, status: .ready),
                                  .init(step: 14, playerNumber: 7, status: .left)])
        let result = try MatchmakingSimulator().run(configuration)
        let waitingBeforeRest = result.trace[4].playerMetrics[simulationID(1)]!.totalWaiting
        for step in 5..<8 {
            let value = try #require(result.trace[step].playerMetrics[simulationID(1)])
            #expect(value.totalWaiting == waitingBeforeRest)
            #expect(value.consecutiveRests == 0)
            #expect(!result.trace[step].eligibleIDs.contains(simulationID(1)))
        }
        #expect(result.trace[8..<12].contains { $0.matches.contains { $0.contains(playerID: simulationID(1)) } })
        #expect(result.trace[14...].allSatisfy { !$0.eligibleIDs.contains(simulationID(7)) })
        #expect(result.metrics.players[simulationID(1)]!.eligibleOpportunities == 27)
        #expect(result.metrics.players[simulationID(7)]!.eligibleOpportunities == 14)
        #expect(!result.metrics.starvationObserved)
    }

    @Test(arguments: [MatchType.singles, .doubles])
    func diagnosticReproducesTwoCohortLockInDespiteBalancedParticipation(type: MatchType) throws {
        // A known policy limitation, not a variety acceptance criterion. M3.9 must review this witness.
        let configuration = SimulationConfiguration(playerCount: type.playersPerMatch * 2,
            matchType: type, courtCount: 1, steps: 40)
        let result = try MatchmakingSimulator().run(configuration)
        #expect(result.metrics.spread == 0)
        #expect(result.metrics.maximumWait == 1)
        #expect(result.metrics.relationshipComponentCount == 2)
        #expect(Set(result.trace.map { Set($0.matches[0].playerIDs) }).count == 2)
    }

    @Test
    func seededMultiCourtBaselineAlsoMaintainsExclusiveAssignments() throws {
        let configuration = SimulationConfiguration(playerCount: 10, matchType: .doubles, courtCount: 2, steps: 25)
        let result = try MatchmakingSimulator().run(configuration, strategy: .seededRandom)
        #expect(result.history.entries.count == 50)
        #expect(result.trace.allSatisfy { Set($0.matches.flatMap(\.playerIDs)).count == 8 })
    }

    @Test
    func traceMetricsCountEachRelationshipAndOpportunityOnce() throws {
        var metrics = SimulationMetrics(playerIDs: (1...5).map(simulationID))
        let first = try MatchCandidate(matchType: .doubles,
            teamA: Team(playerIDs: [1, 2].map(simulationID)), teamB: Team(playerIDs: [3, 4].map(simulationID)))
        let second = try MatchCandidate(matchType: .doubles,
            teamA: Team(playerIDs: [1, 3].map(simulationID)), teamB: Team(playerIDs: [2, 5].map(simulationID)))
        let eligible = Set((1...5).map(simulationID))
        metrics.record(matches: [first], eligibleIDs: eligible, coverageCycle: 2)
        metrics.record(matches: [second], eligibleIDs: eligible, coverageCycle: 2)
        #expect(metrics.completedMatches == 2)
        #expect(metrics.repeatedPartnerships == 0)
        #expect(metrics.repeatedOpponents == 1)
        #expect(metrics.uniquePartnerships == 4)
        #expect(metrics.uniqueOpponentPairs == 7)
        #expect(metrics.players[simulationID(5)]!.totalWaiting == 1)
        #expect(metrics.maximumPlay == 2)
        #expect(metrics.maximumWait == 1)
        #expect(!metrics.starvationObserved)
    }

    @Test
    func starvationAlarmRequiresBothProlongedWaitAndParticipationDeficit() throws {
        let match = try MatchCandidate(matchType: .singles,
            teamA: Team(playerIDs: [simulationID(1)]), teamB: Team(playerIDs: [simulationID(2)]))
        var metrics = SimulationMetrics(playerIDs: (1...3).map(simulationID))
        for _ in 0..<3 { metrics.record(matches: [match], eligibleIDs: Set((1...3).map(simulationID)), coverageCycle: 2) }
        #expect(!metrics.starvationObserved)
        metrics.record(matches: [match], eligibleIDs: Set((1...3).map(simulationID)), coverageCycle: 2)
        #expect(metrics.starvationObserved)
    }

    @Test
    func configurationRejectsUnsupportedMidMatchAvailabilityChanges() throws {
        #expect(throws: SimulationError.self) {
            try MatchmakingSimulator().run(.init(playerCount: 7, matchType: .doubles, courtCount: 1,
                steps: 30, context: .upcoming, availabilityChanges: [.init(step: 4, playerNumber: 1, status: .left)]))
        }
    }
}
