import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

// Decentralized Governance untuk Aegis Vault
actor Governance {
    
    public type Proposal = {
        id: Nat;
        proposer: Principal;
        title: Text;
        description: Text;
        proposalType: ProposalType;
        votingPower: Nat;
        votesFor: Nat;
        votesAgainst: Nat;
        status: ProposalStatus;
        createdAt: Int;
        votingEnds: Int;
        executed: Bool;
    };
    
    public type ProposalType = {
        #SystemUpgrade: { wasmModule: Blob };
        #ParameterChange: { parameter: Text; newValue: Text };
        #TokenMint: { recipient: Principal; amount: Nat };
        #FeatureToggle: { feature: Text; enabled: Bool };
    };
    
    public type ProposalStatus = {
        #Open;
        #Passed;
        #Rejected;
        #Executed;
    };
    
    public type Vote = {
        voter: Principal;
        proposalId: Nat;
        vote: Bool; // true = for, false = against
        votingPower: Nat;
        timestamp: Int;
    };
    
    // State variables
    private stable var proposalEntries: [(Nat, Proposal)] = [];
    private stable var voteEntries: [(Nat, [Vote])] = [];
    private stable var nextProposalId: Nat = 1;
    private stable var governanceToken: ?Principal = null;
    
    // Runtime state
    private var proposals = HashMap.fromIter<Nat, Proposal>(
        proposalEntries.vals(), proposalEntries.size(), 
        func(a: Nat, b: Nat) : Bool { a == b }, func(a: Nat) : Nat { a }
    );
    
    private var votes = HashMap.fromIter<Nat, [Vote]>(
        voteEntries.vals(), voteEntries.size(),
        func(a: Nat, b: Nat) : Bool { a == b }, func(a: Nat) : Nat { a }
    );
    
    // System hooks
    system func preupgrade() {
        proposalEntries := Iter.toArray(proposals.entries());
        voteEntries := Iter.toArray(votes.entries());
    };
    
    system func postupgrade() {
        proposalEntries := [];
        voteEntries := [];
    };
    
    // Governance functions
    public shared(msg) func submitProposal(
        title: Text,
        description: Text,
        proposalType: ProposalType
    ) : async Result.Result<Nat, Text> {
        let caller = msg.caller;
        
        // Check if caller has minimum voting power (would check token balance in real implementation)
        let votingPower = 1000; // Placeholder
        
        if (votingPower < 100) {
            return #err("Insufficient voting power to submit proposal");
        };
        
        let proposalId = nextProposalId;
        nextProposalId += 1;
        
        let proposal: Proposal = {
            id = proposalId;
            proposer = caller;
            title = title;
            description = description;
            proposalType = proposalType;
            votingPower = votingPower;
            votesFor = 0;
            votesAgainst = 0;
            status = #Open;
            createdAt = Time.now();
            votingEnds = Time.now() + (7 * 24 * 60 * 60 * 1_000_000_000); // 7 days
            executed = false;
        };
        
        proposals.put(proposalId, proposal);
        votes.put(proposalId, []);
        
        #ok(proposalId)
    };
    
    public shared(msg) func vote(proposalId: Nat, support: Bool) : async Result.Result<Text, Text> {
        let caller = msg.caller;
        
        switch (proposals.get(proposalId)) {
            case (?proposal) {
                if (Time.now() > proposal.votingEnds) {
                    return #err("Voting period has ended");
                };
                
                if (proposal.status != #Open) {
                    return #err("Proposal is not open for voting");
                };
                
                // Check if user already voted
                let proposalVotes = switch (votes.get(proposalId)) {
                    case (?v) { v };
                    case (_) { [] };
                };
                
                let alreadyVoted = Array.find<Vote>(proposalVotes, func(v) = Principal.equal(v.voter, caller));
                if (alreadyVoted != null) {
                    return #err("User has already voted on this proposal");
                };
                
                // Get voting power (would check token balance)
                let votingPower = 100; // Placeholder
                
                let newVote: Vote = {
                    voter = caller;
                    proposalId = proposalId;
                    vote = support;
                    votingPower = votingPower;
                    timestamp = Time.now();
                };
                
                let updatedVotes = Array.append(proposalVotes, [newVote]);
                votes.put(proposalId, updatedVotes);
                
                // Update proposal vote counts
                let updatedProposal = if (support) {
                    { proposal with votesFor = proposal.votesFor + votingPower }
                } else {
                    { proposal with votesAgainst = proposal.votesAgainst + votingPower }
                };
                
                proposals.put(proposalId, updatedProposal);
                
                #ok("Vote recorded successfully")
            };
            case (_) { #err("Proposal not found") };
        }
    };
    
    public func executeProposal(proposalId: Nat) : async Result.Result<Text, Text> {
        switch (proposals.get(proposalId)) {
            case (?proposal) {
                if (proposal.executed) {
                    return #err("Proposal already executed");
                };
                
                if (Time.now() <= proposal.votingEnds) {
                    return #err("Voting period has not ended");
                };
                
                let totalVotes = proposal.votesFor + proposal.votesAgainst;
                let quorum = 1000; // Minimum votes required
                
                if (totalVotes < quorum) {
                    let rejectedProposal = { proposal with status = #Rejected };
                    proposals.put(proposalId, rejectedProposal);
                    return #err("Proposal did not meet quorum requirements");
                };
                
                if (proposal.votesFor > proposal.votesAgainst) {
                    // Proposal passed
                    let passedProposal = { proposal with status = #Passed; executed = true };
                    proposals.put(proposalId, passedProposal);
                    
                    // Execute the proposal based on type
                    switch (proposal.proposalType) {
                        case (#ParameterChange(params)) {
                            // Implement parameter change logic
                            #ok("Parameter change executed: " # params.parameter # " = " # params.newValue)
                        };
                        case (#FeatureToggle(feature)) {
                            // Implement feature toggle logic
                            #ok("Feature toggle executed: " # feature.feature # " = " # (if (feature.enabled) "enabled" else "disabled"))
                        };
                        case (_) {
                            #ok("Proposal executed successfully")
                        };
                    }
                } else {
                    let rejectedProposal = { proposal with status = #Rejected };
                    proposals.put(proposalId, rejectedProposal);
                    #err("Proposal was rejected by voters")
                }
            };
            case (_) { #err("Proposal not found") };
        }
    };
    
    // Query functions
    public query func getProposal(proposalId: Nat) : async ?Proposal {
        proposals.get(proposalId)
    };
    
    public query func getAllProposals() : async [Proposal] {
        Iter.toArray(proposals.vals())
    };
    
    public query func getProposalVotes(proposalId: Nat) : async [Vote] {
        switch (votes.get(proposalId)) {
            case (?v) { v };
            case (_) { [] };
        }
    };
}
