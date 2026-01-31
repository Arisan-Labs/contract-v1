#!/bin/bash

# Sui Arisan Deployment Script
# Date: 31 Januari 2026

set -e

echo "🚀 Sui Arisan Smart Contract Deployment"
echo "========================================"
echo ""

# Check Sui CLI
if ! command -v sui &> /dev/null; then
    echo "❌ Sui CLI not found. Installing..."
    cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui
fi

echo "✅ Sui CLI found: $(sui --version)"
echo ""

# Show current wallet
echo "📋 Wallet Information:"
sui client active-address
echo ""

# Run tests first
echo "🧪 Running tests..."
sui move test

echo ""
echo "✅ Tests passed!"
echo ""

# Deploy
echo "📦 Deploying contract to Sui Testnet..."
echo "Gas budget: 100,000,000 mist"
echo ""

sui client publish \
    --gas-budget 100000000 \
    --skip-dependency-verification

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📌 Important: Save the Package ID from output above"
echo "Next steps:"
echo "  1. Update DEPLOYMENT.md with Package ID"
echo "  2. Share Package ID with team"
echo "  3. Test contract on Sui Testnet"
