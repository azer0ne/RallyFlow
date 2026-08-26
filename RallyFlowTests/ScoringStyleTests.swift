//
//  ScoringStyleTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Testing
@testable import RallyFlow

struct ScoringStyleTests {

    @Test
    func containsEverySupportedScoringFamily() {
        #expect(
            ScoringStyle.allCases == [
                .tennis,
                .rally,
                .pickleballSideOut,
                .timed
            ]
        )
    }
}
