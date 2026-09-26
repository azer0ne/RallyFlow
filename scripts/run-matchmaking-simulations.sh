#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
simulation_build_dir=$(mktemp -d /tmp/RallyFlow-simulation.XXXXXX)
swiftc -O -swift-version 6 -D MATCHMAKING_DIAGNOSTICS \
  -module-cache-path "$simulation_build_dir/module-cache" \
  RallyFlow/Core/Models/*.swift \
  RallyFlow/Core/Matchmaking/Models/*.swift \
  RallyFlow/Core/Matchmaking/Engines/*.swift \
  RallyFlowTests/Simulation/SimulationConfiguration.swift \
  RallyFlowTests/Simulation/SimulationMetrics.swift \
  RallyFlowTests/Simulation/BaselineScheduler.swift \
  RallyFlowTests/Simulation/MatchmakingSimulator.swift \
  RallyFlowTests/Simulation/SimulationDiagnostics.swift \
  -o "$simulation_build_dir/simulate"
"$simulation_build_dir/simulate" "${1:-1}"
