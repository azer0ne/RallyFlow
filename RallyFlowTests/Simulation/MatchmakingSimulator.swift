import Foundation
#if canImport(RallyFlow)
@testable import RallyFlow
#endif

nonisolated enum SimulationError: Error {
    case invalidConfiguration
    case invalidBatch(step: Int)
    case historyDisagreesWithTrace(step: Int, playerID: Player.ID)
}

nonisolated struct SimulationStep: Equatable, Sendable {
    let matches: [MatchCandidate]
    let eligibleIDs: Set<Player.ID>
    let playerMetrics: [Player.ID: SimulatedPlayerMetrics]
}

nonisolated struct SimulationResult: Sendable {
    let history: ParticipantMatchHistory
    let metrics: SimulationMetrics
    let trace: [SimulationStep]
    let schedulerSeconds: [Double]
    let candidateCount: Int
}

/// Synchronous test driver; all selections come from production engines or the legal random baseline.
nonisolated struct MatchmakingSimulator {
    func run(_ configuration: SimulationConfiguration, strategy: SimulationStrategy = .fairSocial) throws -> SimulationResult {
        guard configuration.playerCount >= configuration.matchType.playersPerMatch,
              configuration.playerCount < 100, configuration.courtCount > 0, configuration.steps > 0,
              configuration.context == .immediate || configuration.availabilityChanges.isEmpty,
              configuration.availabilityChanges.allSatisfy({
                  $0.step >= 0 && $0.step < configuration.steps && $0.playerNumber > 0
                      && $0.playerNumber <= configuration.playerCount && $0.status != .playing
              }) else { throw SimulationError.invalidConfiguration }
        var participants = (1...configuration.playerCount).map {
            SessionParticipant(id: simulationID(100 + $0), playerID: simulationID($0))
        }
        var history = ParticipantMatchHistory()
        var metrics = SimulationMetrics(playerIDs: participants.map(\.playerID))
        var trace: [SimulationStep] = []
        var timing: [Double] = []
        var baseline = BaselineScheduler(seed: configuration.seed)
        var active: [MatchCandidate] = []
        let capacity = try MatchmakingCapacity(usableCourtCount: configuration.courtCount)
        let slots = (0..<configuration.courtCount).map { MatchmakingSlot(courtID: simulationID(200 + $0)) }

        func request(_ context: SchedulingContext, _ roster: [SessionParticipant], _ completed: ParticipantMatchHistory) -> MatchmakingRequest {
            MatchmakingRequest(matchType: configuration.matchType, schedulingContext: context,
                               participants: roster, history: completed, capacity: capacity)
        }
        let candidateCount = MatchCandidateGenerator().candidates(for: request(.immediate, participants, history)).count

        func select(_ input: MatchmakingRequest, snapshots: [ActiveMatchSnapshot]) throws -> [MatchCandidate] {
            let started = ProcessInfo.processInfo.systemUptime
            defer { timing.append(ProcessInfo.processInfo.systemUptime - started) }
            if strategy == .seededRandom {
                return try baseline.matches(request: input, activeMatches: snapshots)
            }
            if configuration.courtCount > 1 {
                return try MultiCourtMatchScheduler().generate(request: input, slots: slots, activeMatches: snapshots)
                    .assignments.map(\.suggestion.candidate)
            }
            if input.schedulingContext == .upcoming {
                return try UpcomingMatchGenerator().generate(request: input, activeMatches: snapshots)
                    .map { [$0.suggestion.candidate] } ?? []
            }
            return try ImmediateMatchGenerator().generate(request: input).map { [$0.candidate] } ?? []
        }

        if configuration.context == .upcoming {
            active = try select(request(.immediate, participants, history), snapshots: [])
        }
        for step in 0..<configuration.steps {
            for change in configuration.availabilityChanges where change.step == step {
                participants[change.playerNumber - 1].status = change.status
            }
            let eligibleIDs = Set(participants.filter { $0.status == .ready }.map(\.playerID))
            let completed: [MatchCandidate]
            if configuration.context == .immediate {
                completed = try select(request(.immediate, participants, history), snapshots: [])
            } else {
                completed = active
                if step + 1 < configuration.steps {
                    let selectedIDs = Set(active.flatMap(\.playerIDs))
                    let playing = participants.map { participant in
                        var value = participant
                        if selectedIDs.contains(value.playerID) { value.status = .playing }
                        return value
                    }
                    active = try select(request(.upcoming, playing, history),
                                        snapshots: active.map { ActiveMatchSnapshot(candidate: $0) })
                }
            }
            let flatIDs = completed.flatMap(\.playerIDs)
            let expectedCount = min(configuration.courtCount, eligibleIDs.count / configuration.matchType.playersPerMatch)
            guard completed.count == expectedCount, Set(flatIDs).count == flatIDs.count,
                  Set(flatIDs).isSubset(of: eligibleIDs),
                  completed.allSatisfy({ $0.matchType == configuration.matchType }) else {
                throw SimulationError.invalidBatch(step: step)
            }
            // A single group marks the simultaneous opportunity, not a guessed global round from sequence order.
            let newEntries = try completed.enumerated().map { index, candidate in
                try MatchHistoryEntry(sequence: history.entries.count + index, candidate: candidate,
                                      eligiblePlayerIDs: eligibleIDs, opportunitySequence: step)
            }
            history = try ParticipantMatchHistory(entries: history.entries + newEntries)
            metrics.record(matches: completed, eligibleIDs: eligibleIDs, coverageCycle: configuration.coverageCycle)
            for participant in participants {
                let actual = history.statistics(for: participant.playerID)
                let measured = metrics.players[participant.playerID]!
                guard actual.matchesPlayed == measured.matchesPlayed,
                      actual.waitingRounds == measured.totalWaiting,
                      actual.consecutiveMatches == measured.consecutivePlay,
                      actual.consecutiveRests == measured.consecutiveRests else {
                    throw SimulationError.historyDisagreesWithTrace(step: step, playerID: participant.playerID)
                }
            }
            trace.append(SimulationStep(matches: completed, eligibleIDs: eligibleIDs, playerMetrics: metrics.players))
        }
        return SimulationResult(history: history, metrics: metrics, trace: trace,
                                schedulerSeconds: timing, candidateCount: candidateCount)
    }
}
