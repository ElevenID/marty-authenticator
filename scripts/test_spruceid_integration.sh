#!/bin/bash

# SpruceID Integration Test Runner
# This script runs comprehensive tests for the SpruceID integration

set -e

echo "🧪 Running SpruceID Integration Tests"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test_file() {
    local test_file=$1
    local test_name=$2

    echo -e "\n${BLUE}📋 Running: $test_name${NC}"
    echo "----------------------------------------"

    if flutter test $test_file --reporter compact; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

echo -e "${YELLOW}🔧 Setting up test environment...${NC}"

# Ensure Flutter is available
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

echo -e "\n${YELLOW}🚀 Starting SpruceID Integration Tests${NC}"

# Run individual test suites
run_test_file "test/integration/spruce_id/platform_channel_test.dart" "Platform Channel Tests"
run_test_file "test/integration/spruce_id/real_data_validation_test.dart" "Real Data Validation Tests"
run_test_file "test/integration/spruce_id/spruce_id_client_test.dart" "SpruceID Client Tests"
run_test_file "test/integration/spruce_id/end_to_end_test.dart" "End-to-End Integration Tests"

# Test Summary
echo -e "\n${BLUE}📊 Test Results Summary${NC}"
echo "========================================"
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All SpruceID integration tests passed!${NC}"
    echo -e "${GREEN}✨ SpruceID implementation is ready for production use${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed. Please review the output above.${NC}"
    echo -e "${YELLOW}📋 Check the following:${NC}"
    echo "   - Platform channel method signatures"
    echo "   - Mock data structures match real SDK expectations"
    echo "   - Error handling for edge cases"
    exit 1
fi
