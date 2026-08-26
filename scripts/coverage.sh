#!/bin/bash
#
# scripts/coverage.sh
# Runs unit + UI tests with code coverage and exports a report.
# Usage: ./scripts/coverage.sh [output-dir]
#

set -euo pipefail

SCHEME="Illuminate-Coverage"
PROJECT="Illuminate.xcodeproj"
DESTINATION="platform=macOS"
OUTPUT_DIR="${1:-build/coverage}"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"
TEST_RESULT="$OUTPUT_DIR/Illuminate-tests.xcresult"

mkdir -p "$OUTPUT_DIR"

echo "==> Running tests with coverage (unit + UI)..."
xcodebuild test \
  -scheme "$SCHEME" \
  -project "$PROJECT" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -enableCodeCoverage YES \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  -resultBundlePath "$TEST_RESULT" \
  2>&1 | xcbeautify || true

echo "==> Exporting coverage report..."
xcrun xccov view --report --json "$TEST_RESULT" > "$OUTPUT_DIR/coverage.json"
xcrun xccov view --report "$TEST_RESULT" > "$OUTPUT_DIR/coverage.txt"

echo "==> Coverage summary:"
cat "$OUTPUT_DIR/coverage.txt"
echo "Report written to $OUTPUT_DIR/coverage.{json,txt}"
