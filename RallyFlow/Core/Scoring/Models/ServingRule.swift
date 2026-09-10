//
//  ServingRule.swift
//  RallyFlow
//
//  Created by Arez on 24/08/26.
//

nonisolated enum ServingRule: Codable, Hashable, Sendable {
    case standard
    case eachDoublesPlayerServesOnce
    case pickleballDoubles
    case manual
}
