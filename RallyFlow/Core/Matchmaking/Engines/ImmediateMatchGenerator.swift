//
//  ImmediateMatchGenerator.swift
//  RallyFlow
//
//  Created by Arez on 26/09/26.
//

nonisolated enum ImmediateMatchGenerationError: Error, Equatable, Sendable {
    case invalidSchedulingContext(SchedulingContext)
}

nonisolated struct ImmediateMatchGenerator: Sendable {
    func generate(request: MatchmakingRequest) throws -> MatchSuggestion? {
        guard request.schedulingContext == .immediate else {
            throw ImmediateMatchGenerationError.invalidSchedulingContext(request.schedulingContext)
        }
        guard request.capacity != nil else {
            throw FairRotationRankingError.missingCapacity
        }

        let candidates = MatchCandidateGenerator().candidates(for: request)
        return try FairRotationCandidateRanker().rank(
            candidates: candidates,
            request: request
        ).first
    }
}
