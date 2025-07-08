import Principal "mo:base/Principal";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";

// Import the UserVault interface for inter-canister calls
import UserVault "./UserVault";

actor Aggregator {
    
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
    
    public type QueryResult = {
        queryId: Nat;
        trueCount: Nat;
        falseCount: Nat;
        totalResponses: Nat;
        participationRate: Float;
        completedAt: ?Int;
    };
    
    public type VaultInfo = {
        principal: Principal;
        registeredAt: Int;
        lastActive: Int;
        dataStatus: Bool;
    };
    
    public type AnalysisRecipe = {
        id: Nat;
        name: Text;
        description: Text;
        category: Text;
        parameters: [(Text, Text)];
    };
    
    // Enhanced stable state with better organization
    private stable var registeredVaultsEntries : [(Principal, VaultInfo)] = [];
    private stable var activeQueriesEntries : [(Nat, Query)] = [];
    private stable var queryResultsEntries : [(Nat, QueryResult)] = [];
    private stable var queryResponsesEntries : [(Nat, [(Principal, Bool)])] = [];
    private stable var nextQueryId : Nat = 1;
    private stable var totalQueries : Nat = 0;
    private stable var canisterVersion : Nat = 1;
    
    // Runtime state with enhanced HashMap usage
    private var registeredVaults = HashMap.fromIter<Principal, VaultInfo>(
        registeredVaultsEntries.vals(), 
        registeredVaultsEntries.size(), 
        Principal.equal, 
        Principal.hash
    );
    
    private var activeQueries = HashMap.fromIter<Nat, Query>(
        activeQueriesEntries.vals(), 
        activeQueriesEntries.size(), 
        func(a: Nat, b: Nat) : Bool { a == b }, 
        func(a: Nat) : Nat { a }
    );
    
    private var queryResults = HashMap.fromIter<Nat, QueryResult>(
        queryResultsEntries.vals(), 
        queryResultsEntries.size(), 
        func(a: Nat, b: Nat) : Bool { a == b }, 
        func(a: Nat) : Nat { a }
    );
    
    private var queryResponses = HashMap.fromIter<Nat, [(Principal, Bool)]>(
        queryResponsesEntries.vals(), 
        queryResponsesEntries.size(), 
        func(a: Nat, b: Nat) : Bool { a == b }, 
        func(a: Nat) : Nat { a }
    );
    
    // Predefined analysis recipes
    private let analysisRecipes : [AnalysisRecipe] = [
        {
            id = 1;
            name = "Food Spending Analysis";
            description = "Analisis: Persentase pengguna dengan pengeluaran 'Makanan' > $50";
            category = "spending";
            parameters = [("category", "Makanan"), ("threshold", "50")];
        },
        {
            id = 2;
            name = "Transportation Budget";
            description = "Analisis: Pengguna dengan pengeluaran transportasi > $100";
            category = "spending";
            parameters = [("category", "Transportasi"), ("threshold", "100")];
        },
        {
            id = 3;
            name = "Entertainment Spending";
            description = "Analisis: Rata-rata pengeluaran hiburan per bulan";
            category = "spending";
            parameters = [("category", "Hiburan"), ("period", "monthly")];
        }
    ];
    
    // Enhanced system hooks for upgrades
    system func preupgrade() {
        Debug.print("Aggregator: Starting pre-upgrade");
        registeredVaultsEntries := Iter.toArray(registeredVaults.entries());
        activeQueriesEntries := Iter.toArray(activeQueries.entries());
        queryResultsEntries := Iter.toArray(queryResults.entries());
        queryResponsesEntries := Iter.toArray(queryResponses.entries());
        Debug.print("Aggregator: Pre-upgrade completed");
    };
    
    system func postupgrade() {
        Debug.print("Aggregator: Starting post-upgrade");
        registeredVaultsEntries := [];
        activeQueriesEntries := [];
        queryResultsEntries := [];
        queryResponsesEntries := [];
        canisterVersion += 1;
        Debug.print("Aggregator: Post-upgrade completed, version: " # debug_show(canisterVersion));
    };
    
    // Enhanced vault registration with better validation
    public shared(msg) func registerMyVault() : async Result.Result<Text, Text> {
        let caller = msg.caller;
        
        // Enhanced security checks
        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous principals cannot register vaults");
        };
        
        if (Principal.toText(caller) == "2vxsx-fae") {
            return #err("Invalid principal for vault registration");
        };
        
        let now = Time.now();
        let vaultInfo : VaultInfo = {
            principal = caller;
            registeredAt = now;
            lastActive = now;
            dataStatus = false;
        };
        
        registeredVaults.put(caller, vaultInfo);
        
        Debug.print("Vault registered: " # Principal.toText(caller));
        #ok("Vault registered successfully at " # debug_show(now))
    };
    
    // Enhanced query submission with better validation and inter-canister calls
    public shared(msg) func submitQuery(recipeId: Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;
        let now = Time.now();
        
        // Validate recipe exists
        let recipe = Array.find<AnalysisRecipe>(analysisRecipes, func(r) = r.id == recipeId);
        switch (recipe) {
            case null { return #err("Invalid recipe ID: " # debug_show(recipeId)) };
            case (?validRecipe) {
                let queryId = nextQueryId;
                nextQueryId += 1;
                totalQueries += 1;
                
                let query : Query = {
                    id = queryId;
                    recipeId = recipeId;
                    description = validRecipe.description;
                    timestamp = now;
                    requester = caller;
                    status = #active;
                    expiresAt = now + (24 * 60 * 60 * 1_000_000_000); // 24 hours in nanoseconds
                };
                
                activeQueries.put(queryId, query);
                
                // Initialize query result
                let initialResult : QueryResult = {
                    queryId = queryId;
                    trueCount = 0;
                    falseCount = 0;
                    totalResponses = 0;
                    participationRate = 0.0;
                    completedAt = null;
                };
                queryResults.put(queryId, initialResult);
                queryResponses.put(queryId, []);
                
                // Broadcast query to all registered vaults
                await broadcastQueryToVaults(query);
                
                Debug.print("Query submitted: " # debug_show(queryId) # " by " # Principal.toText(caller));
                #ok(queryId)
            };
        }
    };
    
    // Enhanced inter-canister communication
    private func broadcastQueryToVaults(query: Query) : async () {
        let vaults = Iter.toArray(registeredVaults.entries());
        
        for ((principal, vaultInfo) in vaults.vals()) {
            try {
                let userVault : UserVault.UserVault = actor(Principal.toText(principal));
                let result = await userVault.receiveQuery(query);
                
                // Update vault's last active time
                let updatedVaultInfo = {
                    vaultInfo with lastActive = Time.now()
                };
                registeredVaults.put(principal, updatedVaultInfo);
                
                Debug.print("Query sent to vault: " # Principal.toText(principal));
            } catch (error) {
                Debug.print("Failed to send query to vault: " # Principal.toText(principal) # " Error: " # debug_show(error));
            };
        };
    };
    
    // Enhanced result submission with validation
    public shared(msg) func submitAnonymousResult(queryId: Nat, result: Bool) : async Result.Result<Text, Text> {
        let caller = msg.caller;
        
        // Verify caller is a registered vault
        switch (registeredVaults.get(caller)) {
            case null { return #err("Caller is not a registered vault") };
            case (?vaultInfo) {
                // Check if query exists and is active
                switch (activeQueries.get(queryId)) {
                    case null { return #err("Query not found") };
                    case (?query) {
                        if (query.status != #active) {
                            return #err("Query is not active");
                        };
                        
                        if (Time.now() > query.expiresAt) {
                            // Mark query as expired
                            let expiredQuery = { query with status = #expired };
                            activeQueries.put(queryId, expiredQuery);
                            return #err("Query has expired");
                        };
                        
                        // Check if this vault has already responded
                        let currentResponses = switch (queryResponses.get(queryId)) {
                            case null { [] };
                            case (?responses) { responses };
                        };
                        
                        let alreadyResponded = Array.find<(Principal, Bool)>(currentResponses, func((p, _)) = Principal.equal(p, caller));
                        if (alreadyResponded != null) {
                            return #err("Vault has already responded to this query");
                        };
                        
                        // Add response
                        let newResponses = Array.append<(Principal, Bool)>(currentResponses, [(caller, result)]);
                        queryResponses.put(queryId, newResponses);
                        
                        // Update query results
                        switch (queryResults.get(queryId)) {
                            case null { return #err("Query results not initialized") };
                            case (?currentResults) {
                                let totalVaults = registeredVaults.size();
                                let newResults = if (result) {
                                    {
                                        currentResults with 
                                        trueCount = currentResults.trueCount + 1;
                                        totalResponses = currentResults.totalResponses + 1;
                                        participationRate = Float.fromInt(currentResults.totalResponses + 1) / Float.fromInt(totalVaults);
                                    }
                                } else {
                                    {
                                        currentResults with 
                                        falseCount = currentResults.falseCount + 1;
                                        totalResponses = currentResults.totalResponses + 1;
                                        participationRate = Float.fromInt(currentResults.totalResponses + 1) / Float.fromInt(totalVaults);
                                    }
                                };
                                
                                queryResults.put(queryId, newResults);
                                
                                // Update vault's last active time
                                let updatedVaultInfo = {
                                    vaultInfo with lastActive = Time.now()
                                };
                                registeredVaults.put(caller, updatedVaultInfo);
                                
                                Debug.print("Result submitted for query " # debug_show(queryId) # " by " # Principal.toText(caller));
                                #ok("Result submitted successfully")
                            };
                        };
                    };
                };
            };
        }
    };
    
    // Enhanced query results with additional metrics
    public query func getQueryResults(queryId: Nat) : async Result.Result<QueryResult, Text> {
        switch (queryResults.get(queryId)) {
            case (?result) { #ok(result) };
            case null { #err("Query results not found") };
        }
    };
    
    // New function to get all available analysis recipes
    public query func getAnalysisRecipes() : async [AnalysisRecipe] {
        analysisRecipes
    };
    
    // Enhanced query to get active queries with filtering
    public query func getActiveQueries(?status: ?QueryStatus) : async [Query] {
        let allQueries = Iter.toArray(activeQueries.vals());
        switch (status) {
            case null { allQueries };
            case (?filterStatus) {
                Array.filter<Query>(allQueries, func(q) = q.status == filterStatus)
            };
        }
    };
    
    // New function to get vault statistics
    public query func getVaultStatistics() : async {
        totalVaults: Nat;
        activeVaults: Nat;
        totalQueries: Nat;
        canisterVersion: Nat;
    } {
        let now = Time.now();
        let dayInNanos = 24 * 60 * 60 * 1_000_000_000;
        let activeVaults = Array.filter<(Principal, VaultInfo)>(
            Iter.toArray(registeredVaults.entries()),
            func((_, info)) = (now - info.lastActive) < dayInNanos
        );
        
        {
            totalVaults = registeredVaults.size();
            activeVaults = activeVaults.size();
            totalQueries = totalQueries;
            canisterVersion = canisterVersion;
        }
    };
    
    // Enhanced function to get registered vault count with details
    public query func getRegisteredVaultCount() : async Nat {
        registeredVaults.size()
    };
    
    // New function for canister health check
    public query func healthCheck() : async {
        status: Text;
        version: Nat;
        cyclesBalance: Nat;
        memoryUsage: Nat;
    } {
        {
            status = "healthy";
            version = canisterVersion;
            cyclesBalance = Cycles.balance();
            memoryUsage = 0; // Would need additional implementation for actual memory usage
        }
    };
    
    // Cleanup expired queries (called periodically)
    public func cleanupExpiredQueries() : async Nat {
        let now = Time.now();
        let allQueries = Iter.toArray(activeQueries.entries());
        var cleanedCount = 0;
        
        for ((queryId, query) in allQueries.vals()) {
            if (now > query.expiresAt and query.status == #active) {
                let expiredQuery = { query with status = #expired };
                activeQueries.put(queryId, expiredQuery);
                cleanedCount += 1;
            };
        };
        
        Debug.print("Cleaned up " # debug_show(cleanedCount) # " expired queries");
        cleanedCount
    };
}
