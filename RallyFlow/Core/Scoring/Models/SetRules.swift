//
//  SetRules.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

/// The rules that determine how a set is completed.
nonisolated struct SetRules: Codable, Hashable, Sendable {
    /// The number of games a team must win to be eligible to win the set.
    let gamesToWin: Int

    /// The game lead required to win the set.
    let winByGames: Int

    /// The tied game score at which a tiebreak begins, when applicable.
    let tiebreakAt: Int?

    /// The point target for the tiebreak, when applicable.
    let tiebreakTarget: Int?

    /// The point lead required to win the tiebreak, when applicable.
    let tiebreakWinBy: Int?

    /// Creates a set-rules value.
    ///
    /// - Parameters:
    ///   - gamesToWin: The number of games needed to be eligible to win.
    ///   - winByGames: The required lead in games.
    ///   - tiebreakAt: The tied game score that begins a tiebreak.
    ///   - tiebreakTarget: The target number of tiebreak points.
    ///   - tiebreakWinBy: The lead required to win the tiebreak.
    init(
        gamesToWin: Int,
        winByGames: Int,
        tiebreakAt: Int? = nil,
        tiebreakTarget: Int? = nil,
        tiebreakWinBy: Int? = nil
    ) {
        self.gamesToWin = gamesToWin
        self.winByGames = winByGames
        self.tiebreakAt = tiebreakAt
        self.tiebreakTarget = tiebreakTarget
        self.tiebreakWinBy = tiebreakWinBy
    }
}
