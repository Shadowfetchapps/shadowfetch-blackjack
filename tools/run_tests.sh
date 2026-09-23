#!/usr/bin/env bash
# Headless test suite: engine/feature/persistence unit tests, the randomized
# simulation, and an end-to-end smoke run of the real game scene.
#   SF_BJ_SIM_HANDS=0   skip the long simulation (default 200000 hands)
#   SF_BJ_SMOKE=0       skip the game-scene smoke run
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
BASE="${SHADOWFETCH_BJ_HOME:-${TMPDIR:-/tmp}/shadowfetch-blackjack-tests}"
rm -rf "$BASE"
mkdir -p "$BASE/unit" "$BASE/smoke"

# Refresh the global class cache and imports (needed on fresh clones / CI).
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

SHADOWFETCH_BJ_HOME="$BASE/unit" timeout 1200 "$GODOT" --headless --path "$ROOT" --script res://tests/test_runner.gd

if [[ "${SF_BJ_SMOKE:-1}" != "0" ]]; then
  echo "Running game-scene smoke test..."
  LOG="$BASE/smoke.log"
  SHADOWFETCH_BJ_HOME="$BASE/smoke" SF_BJ_QA=smoke timeout 300 \
    "$GODOT" --headless --path "$ROOT" >"$LOG" 2>&1 || true
  if grep -q "SCRIPT ERROR" "$LOG" || ! grep -q "\[qa\] smoke ok" "$LOG"; then
    echo "Smoke test FAILED:"
    grep -E "SCRIPT ERROR|ERROR|at: " "$LOG" | head -40 || tail -40 "$LOG"
    exit 1
  fi
  grep "\[qa\] smoke ok" "$LOG"
fi
