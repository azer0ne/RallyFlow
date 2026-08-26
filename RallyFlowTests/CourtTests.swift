//
//  CourtTests.swift
//  RallyFlowTests
//
//  Created by Arez on 24/08/26.
//

import Foundation
import Testing
@testable import RallyFlow

struct CourtTests {

    @Test
    func defaultInitializerGeneratesIDAndPreservesName() {
        let court = Court(name: "Court 1")
        let zeroID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        #expect(court.id != zeroID)
        #expect(court.name == "Court 1")
    }
}
