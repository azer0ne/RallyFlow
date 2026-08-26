//
//  MatchmakingFormat.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

/// A strategy category for arranging participants into matches.
enum MatchmakingFormat: String, Codable, CaseIterable, Sendable {
    /// Balances play and rest opportunities socially.
    case fairSocialRotation

    /// Rotates every available partner combination.
    case fullPartnerRotation

    /// Rotates participants according to ranking.
    case rankingBasedRotation

    /// Rotates partners across mixed participant groups.
    case mixedPartnerRotation

    /// Rotates mixed participant groups according to ranking.
    case mixedRankingRotation

    /// Arranges singles players in a round robin.
    case singlesRoundRobin

    /// Arranges fixed teams in a round robin.
    case fixedTeamRoundRobin

    /// Arranges fixed teams according to ranking.
    case rankingBasedTeamPlay

    /// Keeps winners on court for successive matches.
    case kingOfTheCourt

    /// Leaves match arrangement to the session host.
    case manual
}
