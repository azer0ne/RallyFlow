//
//  SetRules.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated struct SetRules: Codable, Hashable, Sendable {
    let gamesToWin: Int
    let winByGames: Int
    let tiebreakAt: Int?
    let tiebreakTarget: Int?
    let tiebreakWinBy: Int?
    
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
