#!/bin/bash

# Aegis Vault Blockchain Deployment Script
echo "🚀 Deploying Aegis Vault to Internet Computer"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if dfx is installed
if ! command -v dfx &> /dev/null; then
    echo -e "${RED}❌ DFX is not installed. Please install the DFINITY SDK first.${NC}"
    echo "Visit: https://internetcomputer.org/docs/current/developer-docs/setup/install/"
    exit 1
fi

# Check dfx version
DFX_VERSION=$(dfx --version | cut -d' ' -f2)
print_info "Using DFX version: $DFX_VERSION"

# Check if user wants to deploy to mainnet
read -p "Deploy to IC mainnet? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    NETWORK="ic"
    print_warning "Deploying to IC mainnet - this will cost cycles!"
else
    NETWORK="local"
    print_info "Deploying to local replica"
    
    # Start local replica if not running
    if ! dfx ping > /dev/null 2>&1; then
        print_info "Starting local replica..."
        dfx start --background --clean
        sleep 5
    fi
fi

# Clean previous builds
print_info "Cleaning previous builds..."
dfx stop > /dev/null 2>&1 || true
rm -rf .dfx/
rm -rf src/frontend/.svelte-kit/
rm -rf src/frontend/build/
rm -rf src/frontend/node_modules/.vite/

# Start fresh if local
if [ "$NETWORK" = "local" ]; then
    dfx start --background --clean
    sleep 5
fi

# Install frontend dependencies
print_info "Installing frontend dependencies..."
cd src/frontend
if command -v pnpm &> /dev/null; then
    pnpm install
else
    npm install
fi
cd ../..

# Generate Candid interfaces
print_info "Generating Candid interfaces..."
dfx generate --network $NETWORK

# Build and deploy canisters
print_info "Building and deploying canisters..."

# Deploy with cycles for mainnet
if [ "$NETWORK" = "ic" ]; then
    # Check wallet balance
    WALLET_BALANCE=$(dfx wallet --network ic balance 2>/dev/null || echo "0")
    print_info "Wallet balance: $WALLET_BALANCE"
    
    if [[ "$WALLET_BALANCE" == *"0.000"* ]]; then
        print_warning "Low wallet balance. You may need to add cycles."
        print_info "Visit: https://faucet.dfinity.org/ for free cycles"
    fi
    
    # Deploy with cycles
    dfx deploy --network ic --with-cycles 1000000000000
else
    dfx deploy --with-cycles 1000000000000
fi

DEPLOY_RESULT=$?
print_status $DEPLOY_RESULT "Canister deployment"

if [ $DEPLOY_RESULT -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed. Please check the errors above.${NC}"
    exit 1
fi

# Get canister IDs
print_info "Getting canister information..."

AGGREGATOR_ID=$(dfx canister id aggregator --network $NETWORK)
USERVAULT_ID=$(dfx canister id uservault --network $NETWORK)
TOKEN_ID=$(dfx canister id token --network $NETWORK 2>/dev/null || echo "not-deployed")
GOVERNANCE_ID=$(dfx canister id governance --network $NETWORK 2>/dev/null || echo "not-deployed")
FRONTEND_ID=$(dfx canister id frontend --network $NETWORK)

echo ""
echo "🎉 Deployment Successful!"
echo "========================"
echo ""
echo "📋 Canister IDs:"
echo "Aggregator:  $AGGREGATOR_ID"
echo "UserVault:   $USERVAULT_ID"
echo "Token:       $TOKEN_ID"
echo "Governance:  $GOVERNANCE_ID"
echo "Frontend:    $FRONTEND_ID"
echo ""

# Generate frontend URL
if [ "$NETWORK" = "ic" ]; then
    FRONTEND_URL="https://$FRONTEND_ID.ic0.app"
    echo "🌐 Frontend URL: $FRONTEND_URL"
else
    FRONTEND_URL="http://localhost:4943/?canisterId=$FRONTEND_ID"
    echo "🌐 Frontend URL: $FRONTEND_URL"
fi

echo ""
echo "🔧 Environment Variables:"
echo "VITE_AGGREGATOR_CANISTER_ID=$AGGREGATOR_ID"
echo "VITE_USERVAULT_CANISTER_ID=$USERVAULT_ID"
echo "VITE_TOKEN_CANISTER_ID=$TOKEN_ID"
echo "VITE_GOVERNANCE_CANISTER_ID=$GOVERNANCE_ID"
echo "VITE_FRONTEND_CANISTER_ID=$FRONTEND_ID"

# Create .env file for frontend
cat > src/frontend/.env << EOF
VITE_AGGREGATOR_CANISTER_ID=$AGGREGATOR_ID
VITE_USERVAULT_CANISTER_ID=$USERVAULT_ID
VITE_TOKEN_CANISTER_ID=$TOKEN_ID
VITE_GOVERNANCE_CANISTER_ID=$GOVERNANCE_ID
VITE_FRONTEND_CANISTER_ID=$FRONTEND_ID
VITE_DFX_NETWORK=$NETWORK
EOF

print_status 0 "Environment file created"

# Build frontend with proper environment
print_info "Building frontend with environment variables..."
cd src/frontend

# Export environment variables for build
export VITE_AGGREGATOR_CANISTER_ID=$AGGREGATOR_ID
export VITE_USERVAULT_CANISTER_ID=$USERVAULT_ID
export VITE_TOKEN_CANISTER_ID=$TOKEN_ID
export VITE_GOVERNANCE_CANISTER_ID=$GOVERNANCE_ID
export VITE_FRONTEND_CANISTER_ID=$FRONTEND_ID
export VITE_DFX_NETWORK=$NETWORK

# Build frontend
if command -v pnpm &> /dev/null; then
    pnpm run build
else
    npm run build
fi

FRONTEND_BUILD_RESULT=$?
cd ../..

print_status $FRONTEND_BUILD_RESULT "Frontend build"

if [ $FRONTEND_BUILD_RESULT -ne 0 ]; then
    echo -e "${RED}❌ Frontend build failed. Please check the errors above.${NC}"
    exit 1
fi

# Run basic health checks
print_info "Running health checks..."

# Check aggregator health
AGGREGATOR_HEALTH=$(dfx canister call aggregator healthCheck --network $NETWORK 2>/dev/null || echo "failed")
if [[ "$AGGREGATOR_HEALTH" == *"healthy"* ]]; then
    print_status 0 "Aggregator health check"
else
    print_status 1 "Aggregator health check"
fi

# Check token canister if deployed
if [ "$TOKEN_ID" != "not-deployed" ]; then
    TOKEN_HEALTH=$(dfx canister call token name --network $NETWORK 2>/dev/null || echo "failed")
    if [[ "$TOKEN_HEALTH" == *"Aegis Vault Token"* ]]; then
        print_status 0 "Token canister health check"
    else
        print_status 1 "Token canister health check"
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Visit your DApp at: $FRONTEND_URL"
echo "2. Test the core features: data upload, query processing"
echo "3. Test blockchain features if deployed: token transfers, governance"
echo "4. Monitor your canisters: dfx canister status --all --network $NETWORK"

if [ "$NETWORK" = "ic" ]; then
    echo ""
    echo "💰 Mainnet Considerations:"
    echo "- Monitor your cycle balance regularly"
    echo "- Set up cycle management for production"
    echo "- Consider implementing cycle monitoring alerts"
    echo "- Backup your canister code and state"
fi

echo ""
echo "📚 Available Features:"
echo "✅ Smart Contract Data Vaults"
echo "✅ Cryptographic Privacy"
echo "✅ Internet Identity Authentication"
echo "✅ Decentralized Query Processing"
if [ "$TOKEN_ID" != "not-deployed" ]; then
    echo "✅ AVT Token (ERC-20 compatible)"
    echo "✅ Decentralized Governance"
fi

echo ""
print_status 0 "Aegis Vault Blockchain Deployment Complete!"
