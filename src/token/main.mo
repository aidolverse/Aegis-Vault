import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

// Aegis Vault Token (AVT) - Utility token untuk ecosystem
actor AegisToken {
    
    public type TokenInfo = {
        name: Text;
        symbol: Text;
        decimals: Nat8;
        totalSupply: Nat;
        fee: Nat;
    };
    
    public type TxRecord = {
        caller: ?Principal;
        op: Text;
        index: Nat;
        from: Principal;
        to: Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Int;
        status: Text;
    };
    
    // Token configuration
    private let token_info : TokenInfo = {
        name = "Aegis Vault Token";
        symbol = "AVT";
        decimals = 8;
        totalSupply = 1_000_000_000_00000000; // 1 billion tokens
        fee = 10000; // 0.0001 AVT
    };
    
    // State variables
    private stable var balanceEntries: [(Principal, Nat)] = [];
    private stable var allowanceEntries: [(Principal, [(Principal, Nat)])] = [];
    private stable var txIndex: Nat = 0;
    private stable var txEntries: [(Nat, TxRecord)] = [];
    
    // Runtime state
    private var balances = HashMap.fromIter<Principal, Nat>(
        balanceEntries.vals(), balanceEntries.size(), Principal.equal, Principal.hash
    );
    
    private var allowances = HashMap.fromIter<Principal, HashMap.HashMap<Principal, Nat>>(
        allowanceEntries.vals(), allowanceEntries.size(), Principal.equal, Principal.hash
    );
    
    private var transactions = HashMap.fromIter<Nat, TxRecord>(
        txEntries.vals(), txEntries.size(), func(a: Nat, b: Nat) : Bool { a == b }, func(a: Nat) : Nat { a }
    );
    
    // System hooks
    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        allowanceEntries := Iter.toArray(
            Iter.map(allowances.entries(), func (x : (Principal, HashMap.HashMap<Principal, Nat>)) : (Principal, [(Principal, Nat)]) {
                (x.0, Iter.toArray(x.1.entries()))
            })
        );
        txEntries := Iter.toArray(transactions.entries());
    };
    
    system func postupgrade() {
        balanceEntries := [];
        allowanceEntries := [];
        txEntries := [];
        
        allowances := HashMap.fromIter<Principal, HashMap.HashMap<Principal, Nat>>(
            Iter.map(allowanceEntries.vals(), func (x : (Principal, [(Principal, Nat)])) : (Principal, HashMap.HashMap<Principal, Nat>) {
                (x.0, HashMap.fromIter<Principal, Nat>(x.1.vals(), x.1.size(), Principal.equal, Principal.hash))
            }), allowanceEntries.size(), Principal.equal, Principal.hash
        );
    };
    
    // Token standard functions
    public query func name() : async Text { token_info.name };
    public query func symbol() : async Text { token_info.symbol };
    public query func decimals() : async Nat8 { token_info.decimals };
    public query func totalSupply() : async Nat { token_info.totalSupply };
    public query func fee() : async Nat { token_info.fee };
    
    public query func balanceOf(who: Principal) : async Nat {
        switch (balances.get(who)) {
            case (?balance) { balance };
            case (_) { 0 };
        }
    };
    
    public shared(msg) func transfer(to: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let from = msg.caller;
        await _transfer(from, to, amount)
    };
    
    public shared(msg) func approve(spender: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let owner = msg.caller;
        await _approve(owner, spender, amount)
    };
    
    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        switch (allowances.get(owner)) {
            case (?allowance_owner) {
                switch (allowance_owner.get(spender)) {
                    case (?allowance) { allowance };
                    case (_) { 0 };
                }
            };
            case (_) { 0 };
        }
    };
    
    // Aegis Vault specific functions
    public shared(msg) func rewardDataContribution(user: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        // Only aggregator canister can call this
        await _mint(user, amount)
    };
    
    public shared(msg) func payForQuery(amount: Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;
        // Burn tokens for query submission
        await _burn(caller, amount)
    };
    
    // Private functions
    private func _transfer(from: Principal, to: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let from_balance = switch (balances.get(from)) {
            case (?balance) { balance };
            case (_) { 0 };
        };
        
        if (from_balance < amount + token_info.fee) {
            return #err("Insufficient balance");
        };
        
        let to_balance = switch (balances.get(to)) {
            case (?balance) { balance };
            case (_) { 0 };
        };
        
        balances.put(from, from_balance - amount - token_info.fee);
        balances.put(to, to_balance + amount);
        
        let tx: TxRecord = {
            caller = ?from;
            op = "transfer";
            index = txIndex;
            from = from;
            to = to;
            amount = amount;
            fee = token_info.fee;
            timestamp = Time.now();
            status = "completed";
        };
        
        transactions.put(txIndex, tx);
        txIndex += 1;
        
        #ok(txIndex - 1)
    };
    
    private func _approve(owner: Principal, spender: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let owner_allowances = switch (allowances.get(owner)) {
            case (?allowance_owner) { allowance_owner };
            case (_) { 
                let new_allowances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
                allowances.put(owner, new_allowances);
                new_allowances;
            };
        };
        
        owner_allowances.put(spender, amount);
        
        let tx: TxRecord = {
            caller = ?owner;
            op = "approve";
            index = txIndex;
            from = owner;
            to = spender;
            amount = amount;
            fee = 0;
            timestamp = Time.now();
            status = "completed";
        };
        
        transactions.put(txIndex, tx);
        txIndex += 1;
        
        #ok(txIndex - 1)
    };
    
    private func _mint(to: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let to_balance = switch (balances.get(to)) {
            case (?balance) { balance };
            case (_) { 0 };
        };
        
        balances.put(to, to_balance + amount);
        
        let tx: TxRecord = {
            caller = null;
            op = "mint";
            index = txIndex;
            from = Principal.fromText("2vxsx-fae"); // System principal
            to = to;
            amount = amount;
            fee = 0;
            timestamp = Time.now();
            status = "completed";
        };
        
        transactions.put(txIndex, tx);
        txIndex += 1;
        
        #ok(txIndex - 1)
    };
    
    private func _burn(from: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        let from_balance = switch (balances.get(from)) {
            case (?balance) { balance };
            case (_) { 0 };
        };
        
        if (from_balance < amount) {
            return #err("Insufficient balance to burn");
        };
        
        balances.put(from, from_balance - amount);
        
        let tx: TxRecord = {
            caller = ?from;
            op = "burn";
            index = txIndex;
            from = from;
            to = Principal.fromText("2vxsx-fae"); // System principal
            amount = amount;
            fee = 0;
            timestamp = Time.now();
            status = "completed";
        };
        
        transactions.put(txIndex, tx);
        txIndex += 1;
        
        #ok(txIndex - 1)
    };
    
    // Query functions
    public query func getTransaction(index: Nat) : async ?TxRecord {
        transactions.get(index)
    };
    
    public query func getTransactions(start: Nat, limit: Nat) : async [TxRecord] {
        let end = if (start + limit > txIndex) { txIndex } else { start + limit };
        var result: [TxRecord] = [];
        
        for (i in Iter.range(start, end - 1)) {
            switch (transactions.get(i)) {
                case (?tx) { result := Array.append(result, [tx]) };
                case (_) {};
            };
        };
        
        result
    };
}
