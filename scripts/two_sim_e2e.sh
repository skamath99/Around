#!/bin/bash
# Two-simulator end-to-end conversation test.
#
# Boots two simulators, points both app instances at one shared transport
# directory on the host filesystem, and runs the A/B halves of
# TwoSimulatorConversationTests concurrently: A sends, B replies, both
# assert receipt. Screenshots land in screenshots/.
#
# Usage: scripts/two_sim_e2e.sh [SIM_A_NAME] [SIM_B_NAME]
set -euo pipefail
cd "$(dirname "$0")/.."

SIM_A="${1:-iPhone 17 Pro}"
SIM_B="${2:-iPhone 17}"
E2E_DIR="/tmp/around-e2e-$(date +%s)"
DERIVED="build"
LOG_DIR="$E2E_DIR/logs"
mkdir -p "$E2E_DIR" "$LOG_DIR"

echo "==> Transport dir: $E2E_DIR"
echo "==> Building for testing once..."
xcodebuild build-for-testing \
  -project Around.xcodeproj -scheme Around \
  -destination "platform=iOS Simulator,name=$SIM_A" \
  -derivedDataPath "$DERIVED" -quiet

run_role() {
  local role="$1" sim="$2"
  TEST_RUNNER_AROUND_E2E_ROLE="$role" \
  TEST_RUNNER_AROUND_E2E_DIR="$E2E_DIR" \
  TEST_RUNNER_AROUND_SCREENSHOT_DIR="$PWD/screenshots" \
  xcodebuild test-without-building \
    -project Around.xcodeproj -scheme Around \
    -destination "platform=iOS Simulator,name=$sim" \
    -derivedDataPath "$DERIVED" \
    -only-testing:AroundUITests/TwoSimulatorConversationTests \
    > "$LOG_DIR/$role.log" 2>&1
}

echo "==> Running role A on '$SIM_A' and role B on '$SIM_B' concurrently..."
run_role A "$SIM_A" & PID_A=$!
run_role B "$SIM_B" & PID_B=$!

STATUS=0
wait "$PID_A" || { echo "!! Role A failed (see $LOG_DIR/A.log)"; STATUS=1; }
wait "$PID_B" || { echo "!! Role B failed (see $LOG_DIR/B.log)"; STATUS=1; }

if [ "$STATUS" -eq 0 ]; then
  echo "==> ✅ Two-simulator conversation succeeded."
  echo "    Screenshots: screenshots/e2e-two-sim-*.png"
else
  echo "==> ❌ Two-simulator conversation failed."
  tail -5 "$LOG_DIR/A.log" "$LOG_DIR/B.log" || true
fi
exit "$STATUS"
