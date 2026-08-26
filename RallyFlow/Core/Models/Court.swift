//
//  Court.swift
//  RallyFlow
//
//  Created by Arez on 23/08/26.
//

import Foundation

struct Court: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    
    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }
}
