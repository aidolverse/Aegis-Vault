import Debug "mo:base/Debug";
import AggregatorTest "./aggregator.test";
import UserVaultTest "./uservault.test";
import IntegrationTest "./integration.test";

actor TestRunner {
    
    public func runAllTests() : async Bool {
        Debug.print("🚀 Starting Aegis Vault Test Suite...");
        Debug.print("=====================================");
        
        var allTestsPassed = true;
        var totalTests = 0;
        var passedTests = 0;
        
        // Run Aggregator Tests
        Debug.print("\n📦 Running Aggregator Tests...");
        let aggregatorTest = await AggregatorTest.AggregatorTest();
        let aggregatorResult = await aggregatorTest.runAllTests();
        totalTests += 1;
        if (aggregatorResult) {
            passedTests += 1;
        } else {
            allTestsPassed := false;
        };
        
        // Run UserVault Tests
        Debug.print("\n🔐 Running UserVault Tests...");
        let userVaultTest = await UserVaultTest.UserVaultTest();
        let userVaultResult = await userVaultTest.runAllTests();
        totalTests += 1;
        if (userVaultResult) {
            passedTests += 1;
        } else {
            allTestsPassed := false;
        };
        
        // Run Integration Tests
        Debug.print("\n🔗 Running Integration Tests...");
        let integrationTest = await IntegrationTest.IntegrationTest();
        let integrationResult = await integrationTest.runAllTests();
        totalTests += 1;
        if (integrationResult) {
            passedTests += 1;
        } else {
            allTestsPassed := false;
        };
        
        // Print final results
        Debug.print("\n=====================================");
        Debug.print("📊 Final Test Results:");
        Debug.print("Total Test Suites: " # debug_show(totalTests));
        Debug.print("Passed Test Suites: " # debug_show(passedTests));
        Debug.print("Failed Test Suites: " # debug_show(totalTests - passedTests));
        
        if (allTestsPassed) {
            Debug.print("🎉 ALL TESTS PASSED! 🎉");
        } else {
            Debug.print("❌ SOME TESTS FAILED ❌");
        };
        
        Debug.print("=====================================");
        
        return allTestsPassed;
    };
    
    // Individual test suite runners for CI/CD
    public func runAggregatorTests() : async Bool {
        let aggregatorTest = await AggregatorTest.AggregatorTest();
        await aggregatorTest.runAllTests()
    };
    
    public func runUserVaultTests() : async Bool {
        let userVaultTest = await UserVaultTest.UserVaultTest();
        await userVaultTest.runAllTests()
    };
    
    public func runIntegrationTests() : async Bool {
        let integrationTest = await IntegrationTest.IntegrationTest();
        await integrationTest.runAllTests()
    };
}
