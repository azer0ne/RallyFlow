//
//  SchedulingContext.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// The time horizon for which a match is being scheduled.
enum SchedulingContext: Sendable {
    /// A match that can begin now.
    case immediate

    /// A match precomputed to follow the current match.
    case upcoming
}
