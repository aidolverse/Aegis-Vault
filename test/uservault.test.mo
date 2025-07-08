import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Text "mo:base/Text";

// Import the UserVault for testing
import UserVault "../src/uservault/main";

actor UserVaultTest {
    
    // Test data
    private let testOwner = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    private let testData = Blob.fromArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    private let largeTestData = Blob.fromArray(Array.tabulate<Nat8>(1000, func(i) = Nat8.fromNat(i % 256)));
    
    // Test vault instance
    private let vault = await UserVault.UserVault();
    
    // Test vault initialization
    public func testVaultInitialization() : async Bool {
        Debug.print("Testing vault initialization...");
        
        // Test successful initialization
        let result1 = await vault.initialize();
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Vault initialization failed");
            return false;
        };
        
        // Test duplicate initialization (should fail)
        let result2 = await vault.initialize();
        let duplicateHandled = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not duplicateHandled) {
            Debug.print("❌ Duplicate initialization should fail");
            return false;
        };
        
        // Verify owner is set
        let owner = await vault.getOwner();
        if (Principal.isAnonymous(owner)) {
            Debug.print("❌ Owner should not be anonymous");
            return false;
        };
        
        Debug.print("✅ Vault initialization tests passed");
        return true;
    };
    
    // Test data upload
    public func testDataUpload() : async Bool {
        Debug.print("Testing data upload...");
        
        // Ensure vault is initialized
        let _ = await vault.initialize();
        
        // Test successful data upload
        let result1 = await vault.uploadData(testData, "csv");
        let dataId = switch (result1) {
            case (#ok(id)) { id };
            case (#err(msg)) { 
                Debug.print("❌ Data upload failed: " # msg);
                return false;
            };
        };
        
        if (dataId == 0) {
            Debug.print("❌ Data ID should be greater than 0");
            return false;
        };
        
        // Test empty data upload (should fail)
        let emptyData = Blob.fromArray([]);
        let result2 = await vault.uploadData(emptyData, "csv");
        let emptyHandled = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not emptyHandled) {
            Debug.print("❌ Empty data upload should fail");
            return false;
        };
        
        // Verify vault has data
        let hasData = await vault.hasData();
        if (not hasData) {
            Debug.print("❌ Vault should have data after upload");
            return false;
        };
        
        // Test data count
        let dataCount = await vault.getDataCount();
        if (dataCount == 0) {
            Debug.print("❌ Data count should be greater than 0");
            return false;
        };
        
        Debug.print("✅ Data upload tests passed");
        return true;
    };
    
    // Test large data upload
    public func testLargeDataUpload() : async Bool {
        Debug.print("Testing large data upload...");
        
        // Test large data upload
        let result = await vault.uploadData(largeTestData, "csv");
        let success = switch (result) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success) {
            Debug.print("❌ Large data upload failed");
            return false;
        };
        
        Debug.print("✅ Large data upload tests passed");
        return true;
    };
    
    // Test query reception
    public func testQueryReception() : async Bool {
        Debug.print("Testing query reception...");
        
        let testQuery = {
            id = 1;
            recipeId = 1;
            description = "Test query";
            timestamp = Time.now();
            requester = testOwner;
            status = #active;
            expiresAt = Time.now() + (24 * 60 * 60 * 1_000_000_000); // 24 hours
        };
        
        // Test successful query reception
        let result1 = await vault.receiveQuery(testQuery);
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Query reception failed");
            return false;
        };
        
        // Test duplicate query reception (should fail)
        let result2 = await vault.receiveQuery(testQuery);
        let duplicateHandled = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not duplicateHandled) {
            Debug.print("❌ Duplicate query reception should fail");
            return false;
        };
        
        // Test getting pending queries
        let pendingResult = await vault.getPendingQueries();
        let hasPending = switch (pendingResult) {
            case (#ok(queries)) { queries.size() > 0 };
            case (#err(_)) { false };
        };
        
        if (not hasPending) {
            Debug.print("❌ Should have pending queries");
            return false;
        };
        
        Debug.print("✅ Query reception tests passed");
        return true;
    };
    
    // Test expired query handling
    public func testExpiredQueryHandling() : async Bool {
        Debug.print("Testing expired query handling...");
        
        let expiredQuery = {
            id = 999;
            recipeId = 1;
            description = "Expired test query";
            timestamp = Time.now() - (48 * 60 * 60 * 1_000_000_000); // 48 hours ago
            requester = testOwner;
            status = #active;
            expiresAt = Time.now() - (24 * 60 * 60 * 1_000_000_000); // Expired 24 hours ago
        };
        
        // Test expired query reception (should fail)
        let result = await vault.receiveQuery(expiredQuery);
        let expiredHandled = switch (result) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not expiredHandled) {
            Debug.print("❌ Expired query should be rejected");
            return false;
        };
        
        Debug.print("✅ Expired query handling tests passed");
        return true;
    };
    
    // Test query approval
    public func testQueryApproval() : async Bool {
        Debug.print("Testing query approval...");
        
        // Ensure we have data and a pending query
        let _ = await vault.uploadData(testData, "csv");
        
        let testQuery = {
            id = 2;
            recipeId = 1;
            description = "Approval test query";
            timestamp = Time.now();
            requester = testOwner;
            status = #active;
            expiresAt = Time.now() + (24 * 60 * 60 * 1_000_000_000);
        };
        
        let _ = await vault.receiveQuery(testQuery);
        
        // Test successful approval
        let result1 = await vault.approveRequest(2);
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Query approval failed");
            return false;
        };
        
        // Test approving non-existent query (should fail)
        let result2 = await vault.approveRequest(999);
        let notFoundHandled = switch (result2) {
            case (#ok(_)) { false }; // Should fail
            case (#err(_)) { true }; // Should succeed (error expected)
        };
        
        if (not notFoundHandled) {
            Debug.print("❌ Non-existent query approval should fail");
            return false;
        };
        
        Debug.print("✅ Query approval tests passed");
        return true;
    };
    
    // Test query rejection
    public func testQueryRejection() : async Bool {
        Debug.print("Testing query rejection...");
        
        let testQuery = {
            id = 3;
            recipeId = 1;
            description = "Rejection test query";
            timestamp = Time.now();
            requester = testOwner;
            status = #active;
            expiresAt = Time.now() + (24 * 60 * 60 * 1_000_000_000);
        };
        
        let _ = await vault.receiveQuery(testQuery);
        
        // Test successful rejection
        let result1 = await vault.rejectRequest(3);
        let success1 = switch (result1) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };
        
        if (not success1) {
            Debug.print("❌ Query rejection failed");
            return false;
        };
        
        // Verify query is no longer pending
        let pendingResult = await vault.getPendingQueries();
        let noPendingForRejected = switch (pendingResult) {
            case (#ok(queries)) { 
                not Array.find<{id: Nat; recipeId: Nat; description: Text; timestamp: Int; requester: Principal; status: {#pending; #active; #completed; #expired}; expiresAt: Int}>(queries, func(q) = q.id == 3) != null
            };
            case (#err(_)) { false };
        };
        
        if (not noPendingForRejected) {
            Debug.print("❌ Rejected query should not be in pending list");
            return false;
        };
        
        Debug.print("✅ Query rejection tests passed");
        return true;
    };
    
    // Test vault statistics
    public func testVaultStatistics() : async Bool {
        Debug.print("Testing vault statistics...");
        
        let statsResult = await vault.getVaultStats();
        let stats = switch (statsResult) {
            case (#ok(s)) { s };
            case (#err(msg)) { 
                Debug.print("❌ Failed to get vault stats: " # msg);
                return false;
            };
        };
        
        if (stats.dataEntries == 0) {
            Debug.print("❌ Should have data entries from previous tests");
            return false;
        };
        
        if (stats.totalQueries == 0) {
            Debug.print("❌ Should have processed queries from previous tests");
            return false;
        };
        
        if (stats.vaultVersion == 0) {
            Debug.print("❌ Vault version should be greater than 0");
            return false;
        };
        
        Debug.print("✅ Vault statistics tests passed");
        return true;
    };
    
    // Test access logs
    public func testAccessLogs() : async Bool {
        Debug.print("Testing access logs...");
        
        let logsResult = await vault.getAccessLogs(?5);
        let logs = switch (logsResult) {
            case (#ok(l)) { l };
            case (#err(msg)) { 
                Debug.print("❌ Failed to get access logs: " # msg);
                return false;
            };
        };
        
        if (logs.size() == 0) {
            Debug.print("❌ Should have access logs from previous operations");
            return false;
        };
        
        // Verify log structure
        let firstLog = logs[0];
        if (firstLog.action == "" or firstLog.timestamp == 0) {
            Debug.print("❌ Access log structure invalid");
            return false;
        };
        
        Debug.print("✅ Access logs tests passed");
        return true;
    };
    
    // Test health check
    public func testHealthCheck() : async Bool {
        Debug.print("Testing health check...");
        
        let health = await vault.healthCheck();
        
        if (health.status != "healthy") {
            Debug.print("❌ Health status should be healthy");
            return false;
        };
        
        if (health.version == 0) {
            Debug.print("❌ Version should be greater than 0");
            return false;
        };
        
        if (Principal.isAnonymous(health.owner)) {
            Debug.print("❌ Owner should not be anonymous");
            return false;
        };
        
        Debug.print("✅ Health check tests passed");
        return true;
    };
    
    // Run all tests
    public func runAllTests() : async Bool {
        Debug.print("🧪 Starting UserVault Tests...");
        
        let tests = [
            testVaultInitialization,
            testDataUpload,
            testLargeDataUpload,
            testQueryReception,
            testExpiredQueryHandling,
            testQueryApproval,
            testQueryRejection,
            testVaultStatistics,
            testAccessLogs,
            testHealthCheck,
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
        
        Debug.print("📊 UserVault Test Results: " # debug_show(passedCount) # "/" # debug_show(testCount) # " passed");
        
        if (allPassed) {
            Debug.print("🎉 All UserVault tests passed!");
        } else {
            Debug.print("❌ Some UserVault tests failed");
        };
        
        return allPassed;
    };
}
