//
//  AdaptiveWaitingPolicy.swift
//  RallyFlow
//
//  Created by Arez on 22/09/26.
//

nonisolated enum AdaptiveWaitingPolicyError: Error, Equatable, Sendable {
    case invalidEligibleParticipantCount(Int)
    case invalidPlayersPerMatch(Int)
    case invalidUsableCourtCount(Int)
    case capacityOverflow
}

nonisolated struct AdaptiveWaitingPolicy: Sendable {
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
