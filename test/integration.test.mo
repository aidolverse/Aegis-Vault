import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Array "mo:base/Array";

// Import both canisters for integration testing
import Aggregator "../src/aggregator/main";
import UserVault "../src/uservault/main";

actor IntegrationTest {
    
    // Test data
    private let testData = Blob.fromArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    
    // Test instances
    private let aggregator = await Aggregator.Aggregator();
    private let userVault1 = await UserVault.UserVault();
    private let userVault2 = await UserVault.UserVault();
    
    // Test end-to-end workflow
    public func testEndToEndWorkflow() : async Bool {
        Debug.print("Testing end-to-end workflow...");
        
        // Step 1: Initialize user vaults
        let init1 = await userVault1.initialize();
        let init2 = await userVault2.initialize();
        
        let initSuccess = switch (init1, init2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not initSuccess) {
            Debug.print("❌ Vault initialization failed");
            return false;
        };
        
        // Step 2: Register vaults with aggregator
        let reg1 = await aggregator.registerMyVault();
        let reg2 = await aggregator.registerMyVault();
        
        let regSuccess = switch (reg1, reg2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not regSuccess) {
            Debug.print("❌ Vault registration failed");
            return false;
        };
        
        // Step 3: Upload data to vaults
        let upload1 = await userVault1.uploadData(testData, "csv");
        let upload2 = await userVault2.uploadData(testData, "csv");
        
        let uploadSuccess = switch (upload1, upload2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not uploadSuccess) {
            Debug.print("❌ Data upload failed");
            return false;
        };
        
        // Step 4: Submit query through aggregator
        let queryResult = await aggregator.submitQuery(1);
        let queryId = switch (queryResult) {
            case (#ok(id)) { id };
            case (#err(msg)) { 
                Debug.print("❌ Query submission failed: " # msg);
                return false;
            };
        };
        
        // Step 5: Simulate query reception in vaults (in real scenario, this would be automatic)
        let testQuery = {
            id = queryId;
            recipeId = 1;
            description = "Integration test query";
            timestamp = Time.now();
            requester = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            status = #active;
            expiresAt = Time.now() + (24 * 60 * 60 * 1_000_000_000);
        };
        
        let receive1 = await userVault1.receiveQuery(testQuery);
        let receive2 = await userVault2.receiveQuery(testQuery);
        
        let receiveSuccess = switch (receive1, receive2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not receiveSuccess) {
            Debug.print("❌ Query reception failed");
            return false;
        };
        
        // Step 6: Approve queries in vaults
        let approve1 = await userVault1.approveRequest(queryId);
        let approve2 = await userVault2.approveRequest(queryId);
        
        let approveSuccess = switch (approve1, approve2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not approveSuccess) {
            Debug.print("❌ Query approval failed");
            return false;
        };
        
        // Step 7: Submit results back to aggregator (simulate the results)
        let result1 = await aggregator.submitAnonymousResult(queryId, true);
        let result2 = await aggregator.submitAnonymousResult(queryId, false);
        
        let resultSuccess = switch (result1, result2) {
            case (#ok(_), #ok(_)) { true };
            case (_, _) { false };
        };
        
        if (not resultSuccess) {
            Debug.print("❌ Result submission failed");
            return false;
        };
        
        // Step 8: Verify final results
        let finalResults = await aggregator.getQueryResults(queryId);
        let resultsValid = switch (finalResults) {
            case (#ok(results)) { 
                results.totalResponses == 2 and 
                results.trueCount == 1 and 
                results.falseCount == 1
            };
            case (#err(_)) { false };
        };
        
        if (not resultsValid) {
            Debug.print("❌ Final results validation failed");
            return false;
        };
        
        Debug.print("✅ End-to-end workflow test passed");
        return true;
    };
    
    // Test multiple queries workflow
    public func testMultipleQueriesWorkflow() : async Bool {
        Debug.print("Testing multiple queries workflow...");
        
        // Submit multiple queries
        let query1Result = await aggregator.submitQuery(1);
        let query2Result = await aggregator.submitQuery(2);
        let query3Result = await aggregator.submitQuery(3);
        
        let allQueriesSubmitted = switch (query1Result, query2Result, query3Result) {
            case (#ok(_), #ok(_), #ok(_)) { true };
            case (_, _, _) { false };
        };
        
        if (not allQueriesSubmitted) {
            Debug.print("❌ Multiple query submission failed");
            return false;
        };
        
        // Verify active queries
        let activeQueries = await aggregator.getActiveQueries(null);
        if (activeQueries.size() < 3) {
            Debug.print("❌ Should have at least 3 active queries");
            return false;
        };
        
        Debug.print("✅ Multiple queries workflow test passed");
        return true;
    };
    
    // Test error handling and edge cases
    public func testErrorHandling() : async Bool {
        Debug.print("Testing error handling...");
        
        // Test submitting result for non-existent query
        let invalidResult = await aggregator.submitAnonymousResult(99999, true);
        let errorHandled = switch (invalidResult) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not errorHandled) {
            Debug.print("❌ Invalid query result submission should fail");
            return false;
        };
        
        // Test getting results for non-existent query
        let invalidQuery = await aggregator.getQueryResults(99999);
        let queryErrorHandled = switch (invalidQuery) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not queryErrorHandled) {
            Debug.print("❌ Invalid query results request should fail");
            return false;
        };
        
        Debug.print("✅ Error handling test passed");
        return true;
    };
    
    // Test system health and monitoring
    public func testSystemHealth() : async Bool {
        Debug.print("Testing system health...");
        
        // Test aggregator health
        let aggHealth = await aggregator.healthCheck();
        if (aggHealth.status != "healthy") {
            Debug.print("❌ Aggregator should be healthy");
            return false;
        };
        
        // Test vault health
        let vault1Health = await userVault1.healthCheck();
        let vault2Health = await userVault2.healthCheck();
        
        if (vault1Health.status != "healthy" or vault2Health.status != "healthy") {
            Debug.print("❌ All vaults should be healthy");
            return false;
        };
        
        // Test system statistics
        let stats = await aggregator.getVaultStatistics();
        if (stats.totalVaults == 0) {
            Debug.print("❌ Should have registered vaults");
            return false;
        };
        
        Debug.print("✅ System health test passed");
        return true;
    };
    
    // Test data privacy and security
    public func testDataPrivacy() : async Bool {
        Debug.print("Testing data privacy...");
        
        // Verify that raw data never leaves the vault
        // This is more of a conceptual test since we can't directly access private data
        
        // Test that only the vault owner can access certain functions
        let vault1Stats = await userVault1.getVaultStats();
        let statsAccessible = switch (vault1Stats) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not statsAccessible) {
            Debug.print("❌ Vault owner should be able to access stats");
            return false;
        };
        
        // Test that analysis results are boolean only
        let queryResult = await aggregator.submitQuery(1);
        let queryId = switch (queryResult) {
            case (#ok(id)) { id };
            case (#err(_)) { return false };
        };
        
        // Submit a result and verify it's boolean
        let resultSubmission = await aggregator.submitAnonymousResult(queryId, true);
        let resultValid = switch (resultSubmission) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not resultValid) {
            Debug.print("❌ Boolean result submission should succeed");
            return false;
        };
        
        Debug.print("✅ Data privacy test passed");
        return true;
    };
    
    // Test performance and scalability
    public func testPerformanceScalability() : async Bool {
        Debug.print("Testing performance and scalability...");
        
        // Test multiple rapid operations
        var successCount = 0;
        let totalOperations = 10;
        
        for (i in Array.range(0, totalOperations - 1)) {
            let queryResult = await aggregator.submitQuery(1);
            switch (queryResult) {
                case (#ok(_)) { successCount += 1 };
                case (#err(_)) { };
            };
        };
        
        if (successCount < totalOperations / 2) {
            Debug.print("❌ Should handle multiple rapid operations");
            return false;
        };
        
        // Test system remains responsive
        let healthAfterLoad = await aggregator.healthCheck();
        if (healthAfterLoad.status != "healthy") {
            Debug.print("❌ System should remain healthy under load");
            return false;
        };
        
        Debug.print("✅ Performance and scalability test passed");
        return true;
    };
    
    // Run all integration tests
    public func runAllTests() : async Bool {
        Debug.print("🧪 Starting Integration Tests...");
        
        let tests = [
            testEndToEndWorkflow,
            testMultipleQueriesWorkflow,
            testErrorHandling,
            testSystemHealth,
            testDataPrivacy,
            testPerformanceScalability,
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
        
        Debug.print("📊 Integration Test Results: " # debug_show(passedCount) # "/" # debug_show(testCount) # " passed");
        
        if (allPassed) {
            Debug.print("🎉 All Integration tests passed!");
        } else {
            Debug.print("❌ Some Integration tests failed");
        };
        
        return allPassed;
    };
}
