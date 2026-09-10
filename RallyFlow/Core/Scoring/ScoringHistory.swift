//
//  ScoringHistory.swift
//  RallyFlow
//
//  Created by Arez on 09/09/26.
//

nonisolated struct ScoringHistory: Sendable {
    let initialState: MatchScoreState
    let configuration: ScoringConfiguration
    private(set) var state: MatchScoreState
    private(set) var events: [ScoreEvent] = []
    private var previousStates: [MatchScoreState] = []
    private let engine: any ScoringEngine
    
    init(initialState: MatchScoreState, configuration: ScoringConfiguration,
         engine: any ScoringEngine = MatchScoringEngine()) {
        self.initialState = initialState
        self.state = initialState
        self.configuration = configuration
        self.engine = engine
    }
    
    @discardableResult
    mutating func apply(event: ScoreEvent) throws -> MatchScoreState {
        if event == .undo {
            guard let previous = previousStates.popLast() else { throw ScoringEngineError.emptyHistory }
            events.removeLast()
            state = previous
        } else {
            let updated = try engine.apply(event: event, to: state, configuration: configuration)
            previousStates.append(state)
            events.append(event)
            state = updated
        }
        return state
    }
    
    func replayedState() throws -> MatchScoreState {
        try events.reduce(initialState) { current, event in
            try engine.apply(event: event, to: current, configuration: configuration)
        }
    }
}
