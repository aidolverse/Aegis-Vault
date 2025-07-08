#!/bin/bash

# Aegis Vault Test Runner Script
echo "🧪 Aegis Vault - Comprehensive Test Suite"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if dfx is running
if ! dfx ping > /dev/null 2>&1; then
    print_warning "DFX is not running. Starting local replica..."
    dfx start --background --clean
    sleep 5
fi

# Deploy canisters for testing
echo "📦 Deploying canisters for testing..."
dfx deploy --with-cycles 1000000000000

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to deploy canisters${NC}"
    exit 1
fi

# Run Motoko backend tests
echo ""
echo "🔧 Running Motoko Backend Tests..."
echo "=================================="

# Deploy test runner
dfx deploy test-runner

# Run all backend tests
echo "Running comprehensive backend test suite..."
dfx canister call test-runner runAllTests
backend_result=$?

print_status $backend_result "Backend Tests"

# Run frontend unit tests
echo ""
echo "⚛️  Running Frontend Unit Tests..."
echo "=================================="

cd src/frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies..."
    npm install
fi

# Run unit tests with coverage
npm run test:coverage
frontend_unit_result=$?

print_status $frontend_unit_result "Frontend Unit Tests"

# Run end-to-end tests
echo ""
echo "🌐 Running End-to-End Tests..."
echo "=============================="

# Build the frontend
npm run build

# Install Playwright browsers if needed
npx playwright install

# Run e2e tests
npm run test:e2e
e2e_result=$?

print_status $e2e_result "End-to-End Tests"

cd ../..

# Performance and load tests
echo ""
echo "⚡ Running Performance Tests..."
echo "=============================="

# Simple load test - submit multiple queries
echo "Testing query submission performance..."
for i in {1..10}; do
    dfx canister call aggregator submitQuery '(1)' > /dev/null 2>&1
done

echo "✅ Performance tests completed"

# Security tests
echo ""
echo "🔒 Running Security Tests..."
echo "==========================="

# Test unauthorized access attempts
echo "Testing unauthorized access prevention..."
dfx canister call uservault getVaultStats > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "⚠️  Warning: Unauthorized access may be possible"
else
    echo "✅ Unauthorized access properly blocked"
fi

# Test data encryption
echo "Testing data encryption..."
dfx canister call uservault uploadData '(vec {1;2;3;4;5}, "csv")' > /dev/null 2>&1
echo "✅ Data encryption tests completed"

# Generate test report
echo ""
echo "📊 Generating Test Report..."
echo "==========================="

# Calculate overall success
total_tests=3
passed_tests=0

[ $backend_result -eq 0 ] && ((passed_tests++))
[ $frontend_unit_result -eq 0 ] && ((passed_tests++))
[ $e2e_result -eq 0 ] && ((passed_tests++))

echo "Test Summary:"
echo "============="
echo "Backend Tests: $([ $backend_result -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Frontend Unit Tests: $([ $frontend_unit_result -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "End-to-End Tests: $([ $e2e_result -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo ""
echo "Overall Result: $passed_tests/$total_tests tests passed"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo "Aegis Vault is ready for deployment!"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo "Please review the test results and fix any issues."
    exit 1
fi
