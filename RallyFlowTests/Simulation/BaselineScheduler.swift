import Foundation
#if canImport(RallyFlow)
@testable import RallyFlow
#endif

/// Uniform random choice from the remaining legal candidate pool; not uniform over whole batches.
nonisolated struct BaselineScheduler {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func matches(request: MatchmakingRequest, activeMatches: [ActiveMatchSnapshot]) throws -> [MatchCandidate] {
        let resolved = request.schedulingContext == .upcoming
            ? try UpcomingMatchGenerator().prepare(request: request, activeMatches: activeMatches).request : request
        var candidates = MatchCandidateGenerator().candidates(for: resolved)
        var selected: [MatchCandidate] = []
        for _ in 0..<(request.capacity?.usableCourtCount ?? 0) {
            guard !candidates.isEmpty else { break }
            let candidate = candidates[Int(bounded(UInt64(candidates.count)))]
            selected.append(candidate)
            let ids = Set(candidate.playerIDs)
            candidates.removeAll { !ids.isDisjoint(with: $0.playerIDs) }
        }
        return selected
    }

    // SplitMix64 uses fixed wrapping arithmetic; rejection sampling removes modulo bias.
    private mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    private mutating func bounded(_ upperBound: UInt64) -> UInt64 {
        let threshold = (0 &- upperBound) % upperBound
        var value = next()
        while value < threshold { value = next() }
        return value % upperBound
    }
}
