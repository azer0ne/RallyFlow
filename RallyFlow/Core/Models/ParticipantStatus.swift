//
//  ParticipantStatus.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// A participant's availability within a session.
enum ParticipantStatus: String, Codable, Sendable {
    /// Eligible to play immediately.
    case ready

    /// Assigned to an active match.
    case playing

    /// Intentionally sitting out temporarily.
    case resting

    /// Temporarily ineligible to be scheduled.
    case unavailable

    /// Still participating but expected to leave soon.
    case leavingSoon

    /// No longer participating in the session.
    case left
}
