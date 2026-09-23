/// Errors produced when a waiting threshold cannot be calculated safely.
nonisolated enum AdaptiveWaitingPolicyError: Error, Equatable, Sendable {
    /// A waiting expectation cannot be derived for an empty participant pool.
    case invalidEligibleParticipantCount(Int)

    /// A match must require at least one player.
    case invalidPlayersPerMatch(Int)

    /// At least one usable court is required.
    case invalidUsableCourtCount(Int)

    /// The supplied match size and court count cannot be represented by `Int`.
    case capacityOverflow
}

/// Derives a capacity-relative baseline for consecutive eligible rests.
nonisolated struct AdaptiveWaitingPolicy: Sendable {
    /// Calculates the synchronized-round waiting approximation for a participant pool.
    ///
    /// The result is a capacity heuristic, not a wall-clock guarantee or a hard limit.
    func threshold(
        eligibleParticipantCount: Int,
        playersPerMatch: Int,
        usableCourtCount: Int
    ) throws -> WaitingThreshold {
        guard eligibleParticipantCount > 0 else {
            throw AdaptiveWaitingPolicyError.invalidEligibleParticipantCount(
                eligibleParticipantCount
            )
        }
        guard playersPerMatch > 0 else {
            throw AdaptiveWaitingPolicyError.invalidPlayersPerMatch(playersPerMatch)
        }
        guard usableCourtCount > 0 else {
            throw AdaptiveWaitingPolicyError.invalidUsableCourtCount(usableCourtCount)
        }

        let (rawCapacity, overflowed) = playersPerMatch.multipliedReportingOverflow(
            by: usableCourtCount
        )
        guard !overflowed else {
            throw AdaptiveWaitingPolicyError.capacityOverflow
        }

        let simultaneousPlayerCapacity = min(eligibleParticipantCount, rawCapacity)
        let synchronizedRounds = ((eligibleParticipantCount - 1) / simultaneousPlayerCapacity) + 1

        return WaitingThreshold(
            eligibleParticipantCount: eligibleParticipantCount,
            simultaneousPlayerCapacity: simultaneousPlayerCapacity,
            expectedRestRounds: synchronizedRounds - 1
        )
    }
}
