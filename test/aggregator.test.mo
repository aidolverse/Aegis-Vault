import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";

// Import the aggregator for testing
import Aggregator "../src/aggregator/main";

actor AggregatorTest {
    
    // Test data
    private let testPrincipal1 = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    private let testPrincipal2 = Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai");
    
    // Test aggregator instance
    private let aggregator = await Aggregator.Aggregator();
    
    // Test vault registration
    public func testVaultRegistration() : async Bool {
        Debug.print("Testing vault registration...");
        
        // Test successful registration
        let result1 = await aggregator.registerMyVault();
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Vault registration failed");
            return false;
        };
        
        // Test duplicate registration (should still succeed)
        let result2 = await aggregator.registerMyVault();
        let success2 = switch (result2) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success2) {
            Debug.print("❌ Duplicate vault registration failed");
            return false;
        };
        
        // Verify vault count
        let vaultCount = await aggregator.getRegisteredVaultCount();
        if (vaultCount == 0) {
            Debug.print("❌ Vault count should be greater than 0");
            return false;
        };
        
        Debug.print("✅ Vault registration tests passed");
        return true;
    };
    
    // Test query submission
    public func testQuerySubmission() : async Bool {
        Debug.print("Testing query submission...");
        
        // Test valid recipe submission
        let result1 = await aggregator.submitQuery(1);
        let queryId = switch (result1) {
            case (#ok(id)) { id };
            case (#err(msg)) { 
                Debug.print("❌ Query submission failed: " # msg);
                return false;
            };
        };
        
        // Test invalid recipe submission
        let result2 = await aggregator.submitQuery(999);
        let invalidResult = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not invalidResult) {
            Debug.print("❌ Invalid recipe should have failed");
            return false;
        };
        
        // Test getting query results
        let resultsResult = await aggregator.getQueryResults(queryId);
        let hasResults = switch (resultsResult) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not hasResults) {
            Debug.print("❌ Should be able to get query results");
            return false;
        };
        
        Debug.print("✅ Query submission tests passed");
        return true;
    };
    
    // Test result submission
    public func testResultSubmission() : async Bool {
        Debug.print("Testing result submission...");
        
        // First register a vault
        let _ = await aggregator.registerMyVault();
        
        // Submit a query
        let queryResult = await aggregator.submitQuery(1);
        let queryId = switch (queryResult) {
            case (#ok(id)) { id };
            case (#err(_)) { return false };
        };
        
        // Submit anonymous result
        let result1 = await aggregator.submitAnonymousResult(queryId, true);
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Result submission failed");
            return false;
        };
        
        // Test duplicate result submission (should fail)
        let result2 = await aggregator.submitAnonymousResult(queryId, false);
        let duplicateHandled = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not duplicateHandled) {
            Debug.print("❌ Duplicate result submission should fail");
            return false;
        };
        
        // Verify results were recorded
        let finalResults = await aggregator.getQueryResults(queryId);
        let resultsValid = switch (finalResults) {
            case (#ok(results)) { 
                results.totalResponses == 1 and results.trueCount == 1
            };
            case (#err(_)) { false };
        };
        
        if (not resultsValid) {
            Debug.print("❌ Query results not properly recorded");
            return false;
        };
        
        Debug.print("✅ Result submission tests passed");
        return true;
    };
    
    // Test analysis recipes
    public func testAnalysisRecipes() : async Bool {
        Debug.print("Testing analysis recipes...");
        
        let recipes = await aggregator.getAnalysisRecipes();
        
        if (recipes.size() == 0) {
            Debug.print("❌ Should have analysis recipes");
            return false;
        };
        
        // Verify recipe structure
        let firstRecipe = recipes[0];
        if (firstRecipe.id == 0 or firstRecipe.name == "" or firstRecipe.description == "") {
            Debug.print("❌ Recipe structure invalid");
            return false;
        };
        
        Debug.print("✅ Analysis recipes tests passed");
        return true;
    };
    
    // Test health check
    public func testHealthCheck() : async Bool {
        Debug.print("Testing health check...");
        
        let health = await aggregator.healthCheck();
        
        if (health.status != "healthy") {
            Debug.print("❌ Health status should be healthy");
            return false;
        };
        
        if (health.version == 0) {
            Debug.print("❌ Version should be greater than 0");
            return false;
        };
        
        Debug.print("✅ Health check tests passed");
        return true;
    };
    
    // Test vault statistics
    public func testVaultStatistics() : async Bool {
        Debug.print("Testing vault statistics...");
        
        let stats = await aggregator.getVaultStatistics();
        
        // Should have at least the vaults we registered in previous tests
        if (stats.totalVaults == 0) {
            Debug.print("❌ Should have registered vaults");
            return false;
        };
        
        if (stats.canisterVersion == 0) {
            Debug.print("❌ Canister version should be greater than 0");
            return false;
        };
        
        Debug.print("✅ Vault statistics tests passed");
        return true;
    };
    
    // Run all tests
    public func runAllTests() : async Bool {
        Debug.print("🧪 Starting Aggregator Tests...");
        
        let tests = [
            testVaultRegistration,
            testAnalysisRecipes,
            testHealthCheck,
            testQuerySubmission,
            testResultSubmission,
            testVaultStatistics,
        ];
        
        var allPassed = true;
        var testCount = 0;
        var passedCount = 0;
        
        for (test in tests.vals()) {
            testCount += 1;
            let result = await test();
            if (result) {
                passedCount += 1;
            } else {
                allPassed := false;
            };
        };
        
        Debug.print("📊 Aggregator Test Results: " # debug_show(passedCount) # "/" # debug_show(testCount) # " passed");
        
        if (allPassed) {
            Debug.print("🎉 All Aggregator tests passed!");
        } else {
            Debug.print("❌ Some Aggregator tests failed");
        };
        
        return allPassed;
    };
}
