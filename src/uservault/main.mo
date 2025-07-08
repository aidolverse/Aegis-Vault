import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";

actor UserVault {
    
    // Enhanced types with latest SDK features
    public type Query = {
        id: Nat;
        recipeId: Nat;
        description: Text;
        timestamp: Int;
        requester: Principal;
        status: QueryStatus;
        expiresAt: Int;
    };
    
    public type QueryStatus = {
        #pending;
        #active;
        #completed;
        #expired;
    };
    
    public type DataEntry = {
        id: Nat;
        encryptedData: Blob;
        dataType: Text;
        uploadedAt: Int;
        lastAccessed: Int;
        checksum: Text;
    };
    
    public type AccessLog = {
        timestamp: Int;
        action: Text;
        queryId: ?Nat;
        success: Bool;
    };
    
    public type VaultStats = {
        owner: Principal;
        dataEntries: Nat;
        totalQueries: Nat;
        approvedQueries: Nat;
        rejectedQueries: Nat;
        lastActivity: Int;
        vaultVersion: Nat;
    };
    
    // Enhanced stable state
    private stable var owner : Principal = Principal.fromText("2vxsx-fae");
    private stable var dataEntries : [(Nat, DataEntry)] = [];
    private stable var pendingRequests : [(Nat, Query)] = [];
    private stable var accessLogs : [AccessLog] = [];
    private stable var isInitialized : Bool = false;
    private stable var nextDataId : Nat = 1;
    private stable var totalQueries : Nat = 0;
    private stable var approvedQueries : Nat = 0;
    private stable var rejectedQueries : Nat = 0;
    private stable var vaultVersion : Nat = 1;
    private stable var createdAt : Int = 0;
    
    // Runtime state
    private var dataStorage = Buffer.fromArray<(Nat, DataEntry)>(dataEntries);
    private var pendingRequestsBuffer = Buffer.fromArray<(Nat, Query)>(pendingRequests);
    private var accessLogBuffer = Buffer.fromArray<AccessLog>(accessLogs);
    
    // Enhanced system hooks
    system func preupgrade() {
        Debug.print("UserVault: Starting pre-upgrade for " # Principal.toText(owner));
        dataEntries := Buffer.toArray(dataStorage);
        pendingRequests := Buffer.toArray(pendingRequestsBuffer);
        accessLogs := Buffer.toArray(accessLogBuffer);
        Debug.print("UserVault: Pre-upgrade completed");
    };
    
    system func postupgrade() {
        Debug.print("UserVault: Starting post-upgrade for " # Principal.toText(owner));
        dataStorage := Buffer.fromArray<(Nat, DataEntry)>(dataEntries);
        pendingRequestsBuffer := Buffer.fromArray<(Nat, Query)>(pendingRequests);
        accessLogBuffer := Buffer.fromArray<AccessLog>(accessLogs);
        dataEntries := [];
        pendingRequests := [];
        accessLogs := [];
        vaultVersion += 1;
        Debug.print("UserVault: Post-upgrade completed, version: " # debug_show(vaultVersion));
    };
    
    // Enhanced initialization with better security
    public shared(msg) func initialize() : async Result.Result<Text, Text> {
        if (isInitialized) {
            return #err("Vault already initialized");
        };
        
        let caller = msg.caller;
        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous principals cannot initialize vaults");
        };
        
        owner := caller;
        isInitialized := true;
        createdAt := Time.now();
        
        // Log initialization
        let initLog : AccessLog = {
            timestamp = Time.now();
            action = "vault_initialized";
            queryId = null;
            success = true;
        };
        accessLogBuffer.add(initLog);
        
        Debug.print("Vault initialized for: " # Principal.toText(owner));
        #ok("Vault initialized successfully at " # debug_show(createdAt))
    };
    
    // Enhanced data upload with metadata and validation
    public shared(msg) func uploadData(data: Blob, dataType: Text) : async Result.Result<Nat, Text> {
        if (msg.caller != owner) {
            let failLog : AccessLog = {
                timestamp = Time.now();
                action = "upload_failed_unauthorized";
                queryId = null;
                success = false;
            };
            accessLogBuffer.add(failLog);
            return #err("Only vault owner can upload data");
        };
        
        if (data.size() == 0) {
            return #err("Cannot upload empty data");
        };
        
        if (data.size() > 10_000_000) { // 10MB limit
            return #err("Data size exceeds maximum limit of 10MB");
        };
        
        let dataId = nextDataId;
        nextDataId += 1;
        
        let now = Time.now();
        let checksum = generateChecksum(data);
        
        let dataEntry : DataEntry = {
            id = dataId;
            encryptedData = data;
            dataType = dataType;
            uploadedAt = now;
            lastAccessed = now;
            checksum = checksum;
        };
        
        dataStorage.add((dataId, dataEntry));
        
        // Log successful upload
        let uploadLog : AccessLog = {
            timestamp = now;
            action = "data_uploaded";
            queryId = null;
            success = true;
        };
        accessLogBuffer.add(uploadLog);
        
        Debug.print("Data uploaded: ID " # debug_show(dataId) # " for " # Principal.toText(owner));
        #ok(dataId)
    };
    
    // Enhanced query reception with validation
    public shared(msg) func receiveQuery(query: Query) : async Result.Result<Text, Text> {
        // In production, verify the caller is the aggregator canister
        totalQueries += 1;
        
        // Check if query already exists
        let existingQuery = Buffer.find<(Nat, Query)>(pendingRequestsBuffer, func((id, q)) = q.id == query.id);
        if (existingQuery != null) {
            return #err("Query already received");
        };
        
        // Check if query has expired
        if (Time.now() > query.expiresAt) {
            return #err("Query has expired");
        };
        
        pendingRequestsBuffer.add((query.id, query));
        
        // Log query reception
        let queryLog : AccessLog = {
            timestamp = Time.now();
            action = "query_received";
            queryId = ?query.id;
            success = true;
        };
        accessLogBuffer.add(queryLog);
        
        Debug.print("Query received: " # debug_show(query.id) # " for " # Principal.toText(owner));
        #ok("Query received and pending approval")
    };
    
    // Enhanced pending query retrieval
    public shared(msg) func getPendingQueries() : async Result.Result<[Query], Text> {
        if (msg.caller != owner) {
            return #err("Only vault owner can view pending queries");
        };
        
        let now = Time.now();
        let validQueries = Buffer.Buffer<Query>(0);
        
        // Filter out expired queries
        for ((queryId, query) in pendingRequestsBuffer.vals()) {
            if (now <= query.expiresAt) {
                validQueries.add(query);
            };
        };
        
        #ok(Buffer.toArray(validQueries))
    };
    
    // Enhanced query approval with detailed analysis
    public shared(msg) func approveRequest(queryId: Nat) : async Result.Result<Bool, Text> {
        if (msg.caller != owner) {
            let failLog : AccessLog = {
                timestamp = Time.now();
                action = "approve_failed_unauthorized";
                queryId = ?queryId;
                success = false;
            };
            accessLogBuffer.add(failLog);
            return #err("Only vault owner can approve requests");
        };
        
        // Find and remove the pending query
        let queryIndex = Buffer.indexOf<(Nat, Query)>((queryId, { 
            id = 0; recipeId = 0; description = ""; timestamp = 0; 
            requester = owner; status = #pending; expiresAt = 0 
        }), pendingRequestsBuffer, func((id1, _), (id2, _)) = id1 == id2);
        
        switch (queryIndex) {
            case null {
                return #err("Query not found in pending requests");
            };
            case (?index) {
                let (_, query) = pendingRequestsBuffer.get(index);
                let _ = pendingRequestsBuffer.remove(index);
                
                // Check if query has expired
                if (Time.now() > query.expiresAt) {
                    return #err("Query has expired");
                };
                
                // Execute analysis
                let analysisResult = await executeAnalysis(query);
                approvedQueries += 1;
                
                // Log approval and analysis
                let approveLog : AccessLog = {
                    timestamp = Time.now();
                    action = "query_approved_and_analyzed";
                    queryId = ?queryId;
                    success = true;
                };
                accessLogBuffer.add(approveLog);
                
                // In a real implementation, send result back to aggregator
                // For now, we'll return the result
                Debug.print("Query approved and analyzed: " # debug_show(queryId) # " Result: " # debug_show(analysisResult));
                #ok(analysisResult)
            };
        }
    };
    
    // Enhanced query rejection
    public shared(msg) func rejectRequest(queryId: Nat) : async Result.Result<Text, Text> {
        if (msg.caller != owner) {
            return #err("Only vault owner can reject requests");
        };
        
        let queryIndex = Buffer.indexOf<(Nat, Query)>((queryId, { 
            id = 0; recipeId = 0; description = ""; timestamp = 0; 
            requester = owner; status = #pending; expiresAt = 0 
        }), pendingRequestsBuffer, func((id1, _), (id2, _)) = id1 == id2);
        
        switch (queryIndex) {
            case null {
                return #err("Query not found in pending requests");
            };
            case (?index) {
                let _ = pendingRequestsBuffer.remove(index);
                rejectedQueries += 1;
                
                // Log rejection
                let rejectLog : AccessLog = {
                    timestamp = Time.now();
                    action = "query_rejected";
                    queryId = ?queryId;
                    success = true;
                };
                accessLogBuffer.add(rejectLog);
                
                Debug.print("Query rejected: " # debug_show(queryId));
                #ok("Query rejected successfully")
            };
        }
    };
    
    // Enhanced analysis execution with multiple recipes
    private func executeAnalysis(query: Query) : async Bool {
        let dataArray = Buffer.toArray(dataStorage);
        
        if (dataArray.size() == 0) {
            return false;
        };
        
        // Update last accessed time for data entries
        for (i in dataStorage.keys()) {
            let (dataId, entry) = dataStorage.get(i);
            let updatedEntry = {
                entry with lastAccessed = Time.now()
            };
            dataStorage.put(i, (dataId, updatedEntry));
        };
        
        switch (query.recipeId) {
            case (1) { await runAnalysis_Recipe1(dataArray) };
            case (2) { await runAnalysis_Recipe2(dataArray) };
            case (3) { await runAnalysis_Recipe3(dataArray) };
            case (_) { false };
        }
    };
    
    // Enhanced analysis recipes with better simulation
    private func runAnalysis_Recipe1(data: [(Nat, DataEntry)]) : async Bool {
        // Food spending analysis: Check if food expenses > $50
        // In a real implementation, this would decrypt and parse CSV data
        
        var totalFoodSpending = 0;
        var foodEntries = 0;
        
        for ((_, entry) in data.vals()) {
            if (Text.contains(entry.dataType, #text "csv")) {
                // Simulate parsing encrypted CSV data
                let simulatedFoodSpending = (entry.encryptedData.size() % 100) + 10;
                if (simulatedFoodSpending > 30) { // Simulate food category detection
                    totalFoodSpending += simulatedFoodSpending;
                    foodEntries += 1;
                };
            };
        };
        
        if (foodEntries > 0) {
            let averageFoodSpending = totalFoodSpending / foodEntries;
            averageFoodSpending > 50
        } else {
            false
        }
    };
    
    private func runAnalysis_Recipe2(data: [(Nat, DataEntry)]) : async Bool {
        // Transportation spending analysis: Check if transport expenses > $100
        var totalTransportSpending = 0;
        var transportEntries = 0;
        
        for ((_, entry) in data.vals()) {
            if (Text.contains(entry.dataType, #text "csv")) {
                let simulatedTransportSpending = (entry.encryptedData.size() % 150) + 20;
                if (simulatedTransportSpending > 50) { // Simulate transport category detection
                    totalTransportSpending += simulatedTransportSpending;
                    transportEntries += 1;
                };
            };
        };
        
        if (transportEntries > 0) {
            let averageTransportSpending = totalTransportSpending / transportEntries;
            averageTransportSpending > 100
        } else {
            false
        }
    };
    
    private func runAnalysis_Recipe3(data: [(Nat, DataEntry)]) : async Bool {
        // Entertainment spending analysis
        var totalEntertainmentSpending = 0;
        var entertainmentEntries = 0;
        
        for ((_, entry) in data.vals()) {
            if (Text.contains(entry.dataType, #text "csv")) {
                let simulatedEntertainmentSpending = (entry.encryptedData.size() % 80) + 5;
                if (simulatedEntertainmentSpending > 20) { // Simulate entertainment category detection
                    totalEntertainmentSpending += simulatedEntertainmentSpending;
                    entertainmentEntries += 1;
                };
            };
        };
        
        entertainmentEntries > 0 and (totalEntertainmentSpending / entertainmentEntries) > 30
    };
    
    // Utility function to generate checksum
    private func generateChecksum(data: Blob) : Text {
        let hash = Hash.hash(data.size());
        debug_show(hash)
    };
    
    // Enhanced query functions
    public query func getOwner() : async Principal {
        owner
    };
    
    public query func hasData() : async Bool {
        dataStorage.size() > 0
    };
    
    public query func getDataCount() : async Nat {
        dataStorage.size()
    };
    
    public shared(msg) func getVaultStats() : async Result.Result<VaultStats, Text> {
        if (msg.caller != owner) {
            return #err("Only vault owner can view statistics");
        };
        
        let stats : VaultStats = {
            owner = owner;
            dataEntries = dataStorage.size();
            totalQueries = totalQueries;
            approvedQueries = approvedQueries;
            rejectedQueries = rejectedQueries;
            lastActivity = Time.now();
            vaultVersion = vaultVersion;
        };
        
        #ok(stats)
    };
    
    public shared(msg) func getAccessLogs(limit: ?Nat) : async Result.Result<[AccessLog], Text> {
        if (msg.caller != owner) {
            return #err("Only vault owner can view access logs");
        };
        
        let logs = Buffer.toArray(accessLogBuffer);
        let logLimit = switch (limit) {
            case null { logs.size() };
            case (?l) { if (l > logs.size()) logs.size() else l };
        };
        
        let recentLogs = Array.tabulate<AccessLog>(logLimit, func(i) = logs[logs.size() - 1 - i]);
        #ok(recentLogs)
    };
    
    // Health check function
    public query func healthCheck() : async {
        status: Text;
        owner: Principal;
        dataEntries: Nat;
        pendingQueries: Nat;
        version: Nat;
        cyclesBalance: Nat;
    } {
        {
            status = if (isInitialized) "healthy" else "uninitialized";
            owner = owner;
            dataEntries = dataStorage.size();
            pendingQueries = pendingRequestsBuffer.size();
            version = vaultVersion;
            cyclesBalance = Cycles.balance();
        }
    };
}
