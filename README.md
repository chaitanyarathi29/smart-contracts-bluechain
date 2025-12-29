"# Aeris - Blockchain Carbon Credit Ecosystem

## What is Aeris?

Aeris is a comprehensive blockchain-based carbon credit system that brings transparency, trust, and verifiable climate impact to global carbon offsetting. It combines smart contracts with machine learning to ensure every carbon credit represents real, verified environmental restoration.

## Quick Start

### View the Architecture
- Full architecture: [`DOCUMENTATION.md`](DOCUMENTATION.md)
- Deployment guide: [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)
- Integration API: [`INTEGRATION_API.sol`](INTEGRATION_API.sol)
- Project summary: [`PROJECT_SUMMARY.md`](PROJECT_SUMMARY.md)

### Core Smart Contracts (8 Total)
1. **ProjectRegistry.sol** - Project & entity registration
2. **MRVVerification.sol** - ML-based verification with validator consensus
3. **CarbonToken.sol** - ERC-20 carbon credit token
4. **ValidatorStaking.sol** - Validator registration (32 ETH stake)
5. **PermissionedAMM.sol** - Decentralized trading via AMM
6. **CarbonRetirement.sol** - Token burning and offset recording
7. **Aeris.sol** - Branded token interface
8. **AerisSystemOrchestrator.sol** - System initialization & orchestration

## System Overview

### 7-Step Workflow

```
Step 1: Registration            → ProjectRegistry
Step 2: MRV Data Collection     → IPFS + On-chain
Step 3: Verification            → MRVVerification + ValidatorStaking
Step 4: Token Minting           → CarbonToken (ERC20)
Step 5: Trading                 → PermissionedAMM
Step 6: Industry Purchase       → Token Acquisition
Step 7: Offset & Retirement     → CarbonRetirement
```

## Key Features

### 1. **ML-Powered Verification** 
Four-stage verification pipeline:
- **Stage 1**: Aerial semantic segmentation (drone imagery)
- **Stage 2**: Multispectral biomass analysis (NDVI)
- **Stage 3**: Growth prediction (environmental parameters)
- **Stage 4**: Carbon conversion (CO₂ equivalent)

### 2. **Stake-Based Consensus** 
- Validators stake 32 ETH to gain validation rights
- Minimum 2 validator approvals required
- Slashing mechanism: dishonest validators lose their stake
- Output tolerance: 5% (configurable)

### 3. **Decentralized Trading** 
- AMM with constant product formula (x × y = k)
- No centralized intermediary
- Transparent price discovery
- 0.25% transaction fee

### 4. **Immutable Records** 
- Complete on-chain audit trail
- IPFS integration for large files
- Prevention of double-spending
- Permanent after token burning

### 5. **Annual Expiration** 
- Carbon credits valid for one financial year
- Credits expire at year-end
- Prevents indefinite credit hoarding

## Documentation

| Document | Purpose |
|----------|---------|
| [`DOCUMENTATION.md`](DOCUMENTATION.md) | Complete architecture, features, and security |
| [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) | Step-by-step deployment with code examples |
| [`INTEGRATION_API.sol`](INTEGRATION_API.sol) | All function signatures and usage patterns |
| [`PROJECT_SUMMARY.md`](PROJECT_SUMMARY.md) | Complete implementation overview |

## Security

Key security mechanisms:
- **Validator Slashing**: Dishonest validators lose 32 ETH
- **Whitelisting**: Admin controls who can participate
- **Consensus**: Multiple independent approvals required
- **Immutability**: Blockchain-based permanent records
- **No Double-Spending**: Burnt tokens cannot be reused

## Use Cases

### For Environmental Organizations
 Register restoration projects  
 Submit verified MRV data  
 Receive carbon credit tokens  
 Create liquidity pools for trading

### For Industries
 Purchase verified carbon credits  
 Trade via decentralized AMM  
 Permanently offset emissions  
 Record compliance on-chain

## Impact Potential

- **Year 1**: 100+ projects, 500K+ tons CO₂ offset
- **Year 3**: 1,000+ projects, 10M+ tons CO₂ offset
- **Vision**: Global-scale transparent carbon offsetting

## Getting Help

1. **Learn**: Read [`DOCUMENTATION.md`](DOCUMENTATION.md)
2. **Understand**: Review [`INTEGRATION_API.sol`](INTEGRATION_API.sol)
3. **Deploy**: Follow [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)

---

**Aeris v1.0** | Blockchain Carbon Credit Ecosystem | MIT License" 
