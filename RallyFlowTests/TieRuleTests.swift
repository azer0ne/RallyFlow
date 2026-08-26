//
//  TieRuleTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

struct TieRuleTests {

    @Test
    func preservesTiebreakValues() {
        let rule = TieRule.tiebreak(target: 10, winBy: 2)

        guard case let .tiebreak(target, winBy) = rule else {
            Issue.record("Expected a tiebreak rule")
            return
        }

        #expect(target == 10)
        #expect(winBy == 2)
    }

    @Test
    func preservesRequiredLead() {
        let rule = TieRule.continueUntilLead(by: 2)

        guard case let .continueUntilLead(lead) = rule else {
            Issue.record("Expected a continue-until-lead rule")
            return
        }

        #expect(lead == 2)
    }
}
