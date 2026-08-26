//
//  ScoringConfigurationTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

struct ScoringConfigurationTests {

    @Test
    func representsOneServeEach() throws {
        let configuration = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .fixedGames(count: 4),
            deuceRule: .noAd,
            tieRule: .draw,
            servingRule: .eachDoublesPlayerServesOnce
        )

        #expect(configuration.style == .tennis)
        #expect(configuration.pointSystem == .tennis)
        #expect(configuration.matchStructure == .fixedGames(count: 4))
        #expect(configuration.deuceRule == .noAd)
        #expect(configuration.tieRule == .draw)
        #expect(configuration.servingRule == .eachDoublesPlayerServesOnce)
    }

    @Test
    func representsRallyRaceTo21() throws {
        let configuration = try ScoringConfiguration(
            style: .rally,
            pointSystem: .rally,
            matchStructure: .raceToPoints(target: 21, winBy: 2, cap: nil),
            servingRule: .standard
        )

        #expect(configuration.style == .rally)
        #expect(configuration.pointSystem == .rally)
        #expect(
            configuration.matchStructure == .raceToPoints(
                target: 21,
                winBy: 2,
                cap: nil
            )
        )
        #expect(configuration.deuceRule == nil)
        #expect(configuration.tieRule == nil)
        #expect(configuration.servingRule == .standard)
    }

    @Test
    func representsTennisSetWithTiebreak() throws {
        let configuration = try ScoringConfiguration(
            style: .tennis,
            pointSystem: .tennis,
            matchStructure: .bestOfSets(
                count: 1,
                setRules: SetRules(
                    gamesToWin: 6,
                    winByGames: 2,
                    tiebreakAt: 6,
                    tiebreakTarget: 7,
                    tiebreakWinBy: 2
                )
            ),
            deuceRule: .advantage,
            servingRule: .standard
        )

        #expect(
            configuration.matchStructure == .bestOfSets(
                count: 1,
                setRules: SetRules(
                    gamesToWin: 6,
                    winByGames: 2,
                    tiebreakAt: 6,
                    tiebreakTarget: 7,
                    tiebreakWinBy: 2
                )
            )
        )
        #expect(configuration.deuceRule == .advantage)
    }

    @Test
    func rejectsNonpositivePointTarget() {
        #expect(throws: ScoringConfigurationError.invalidTarget) {
            try ScoringConfiguration(
                style: .rally,
                pointSystem: .rally,
                matchStructure: .raceToPoints(target: 0, winBy: 2, cap: nil),
                servingRule: .standard
            )
        }
    }

    @Test
    func rejectsCapBelowTarget() {
        #expect(throws: ScoringConfigurationError.invalidCap) {
            try ScoringConfiguration(
                style: .rally,
                pointSystem: .rally,
                matchStructure: .raceToPoints(target: 21, winBy: 2, cap: 15),
                servingRule: .standard
            )
        }
    }
}
