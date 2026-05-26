# uFund

uFund is a proposed ERC interface for tokenized investment funds.

It defines a minimal, read-heavy, base-token-agnostic interface for exposing fund-level information such as:

- Net Asset Value (NAV)
- NAV freshness and staleness
- fund lifecycle state
- declared and paid distributions
- basic fee metadata
- subscription and redemption windows
- maturity date

It also defines optional extensions for:

- AUM reporting
- holder lockup reporting
- accrued yield reporting
- multi-class share structures
- proof-of-reserves attestations

The goal of uFund is to reduce custom integration work for DeFi protocols, wallets, indexers, custodians, and RWA platforms that need to interact with tokenized funds.

---

## Status

This repository contains a reference implementation for the proposed uFund ERC interface.

The implementation is **non-normative**. The interface and events are intended to demonstrate one possible implementation pattern. Production implementations may use different internal admin functions, access-control models, oracle models, accounting systems, or operational workflows.

This repository is currently intended for discussion, review, testing, and ecosystem feedback.

---

## Why uFund?

Tokenized funds and RWA products often expose similar concepts through different contract ABIs.

Common fund-level data includes:

- current NAV
- NAV update timestamp
- NAV staleness
- fund lifecycle state
- distribution schedule
- fee metadata
- subscription and redemption windows
- maturity
- proof-of-reserves information

Today, every DeFi protocol, wallet, dashboard, custodian, and indexer often needs custom adapters for each issuer.

uFund standardizes the common fund metadata and lifecycle surface while allowing issuers to keep their existing:

- token model
- custody system
- compliance system
- oracle system
- accounting process
- subscription and redemption architecture

---

## Design Goals

uFund is designed to be:

- Minimal in the mandatory core
- Read-heavy
- Base-token agnostic
- Compatible with existing token standards
- Friendly to indexers and analytics systems
- Non-prescriptive on admin/write-side implementation details
- Easy to compose with existing RWA, vault, and permissioned-token systems

uFund can be implemented alongside:

- ERC-20
- ERC-4626
- ERC-7540
- ERC-7575
- ERC-3643
- ERC-7943-style RWA systems

---

## Events-Only Write-Side Design

uFund does **not** standardize admin write function signatures.

For example, the standard does not require every implementation to expose the same function names for:

- setting NAV
- changing lifecycle state
- declaring distributions
- updating AUM
- publishing attestations

Instead, implementations are free to use their own:

- admin model
- oracle model
- batch process
- multisig
- DAO
- off-chain accounting flow
- role-based access-control model

What uFund standardizes is the **event stream** that must be emitted when corresponding state changes occur.

This allows integrators and indexers to observe fund state changes consistently without forcing all issuers into the same write architecture.

---

## Repository Structure

```text
src/
  interfaces/
    IERC_UFUND.sol
  UFundBase.sol

test/
  UFundBase.t.sol

foundry.toml
README.md
LICENSE
```

---

## Core Interface

The mandatory core interface is:

```solidity
interface IERC_UFUND
```

It includes read functions for the common fund metadata surface.

### NAV

```solidity
navPerShare()
navAsOf(uint256 timestamp)
navUpdatedAt()
navStale()
navStalenessThreshold()
valuationCurrency()
```

### Lifecycle

```solidity
lifecycleState()
lifecycleStateUpdatedAt()
```

### Distributions

```solidity
pendingDistributions()
lastDistribution()
nextDistributionDate()
```

### Basic Fund Parameters

```solidity
managementFeeBps()
performanceFeeBps()
subscriptionFeeBps()
redemptionFeeBps()
minInvestment()
subscriptionWindow()
redemptionWindow()
maturityDate()
```

---

## Optional Extensions

### `IERC_UFUND_AUM`

Optional extension for AUM reporting.

```solidity
aum()
aumUpdatedAt()
```

### `IERC_UFUND_Lockup`

Optional extension for holder-specific lockup information.

```solidity
lockupExpires(address account)
```

### `IERC_UFUND_Yield`

Optional extension for account-level accrued yield.

```solidity
accruedYield(address account)
```

### `IERC_UFUND_MultiClass`

Optional extension for funds with multiple share classes.

```solidity
shareClasses()
defaultShareClass()
shareClassInfo(bytes32 shareClassId)
navPerShare(bytes32 shareClassId)
```

### `IERC_UFUND_ProofOfReserves`

Optional extension for reserve attestations.

```solidity
latestAttestation()
attestationHistory(uint256 fromTimestamp)
```

---

## Required Events

The core interface defines standardized events such as:

```solidity
NavUpdated
LifecycleStateChanged
DistributionDeclared
DistributionPaid
DistributionCancelled
```

Optional extensions define additional events such as:

```solidity
AUMUpdated
ShareClassAdded
AttestationPublished
```

Indexers and analytics platforms can listen to these events across different uFund-compatible implementations.

---

## ERC-165 Interface IDs

The interface IDs are computed using ERC-165 rules.

Run:

```bash
forge test --match-test testInterfaceId -vv
```

Current interface IDs:

| Interface | Interface ID |
|---|---|
| `IERC_UFUND` | `0x35e466ae` |
| `IERC_UFUND_AUM` | `0x081529b6` |
| `IERC_UFUND_Lockup` | `0xb6e90569` |
| `IERC_UFUND_Yield` | `0xc744ad19` |
| `IERC_UFUND_MultiClass` | `0xc99baab7` |
| `IERC_UFUND_ProofOfReserves` | `0x9655511c` |


---

## Installation

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Clone this repository:

```bash
git clone https://github.com/Blockchainxtech/ufund.git
cd ufund
```

Install dependencies:

```bash
forge install
```

---

## Build

```bash
forge build
```

---

## Test

```bash
forge test -vv
```

---

## Compute Interface IDs

```bash
forge test --match-test testInterfaceId -vv
```

---

## Example Usage

A DeFi protocol, wallet, or indexer can detect uFund support using ERC-165:

```solidity
if (fund.supportsInterface(type(IERC_UFUND).interfaceId)) {
    // fund supports uFund core interface
}
```

Then it can call standardized read functions:

```solidity
(uint256 nav, uint8 decimals) = fund.navPerShare();
LifecycleState state = fund.lifecycleState();
bool stale = fund.navStale();
```

---

## Example Integration Flow

A lending protocol, wallet, or RWA dashboard can use uFund like this:

1. Check whether the fund supports `IERC_UFUND` through ERC-165.
2. Read the current NAV using `navPerShare()`.
3. Check whether the NAV is stale using `navStale()`.
4. Read the lifecycle state using `lifecycleState()`.
5. Read upcoming distributions using `pendingDistributions()` or `nextDistributionDate()`.
6. Listen to standardized events for future updates.

This enables the same integration logic to work across multiple tokenized fund issuers that implement the interface.

---

## Security Notes

This repository is a reference implementation only.

Production deployments should carefully review:

- admin access control
- NAV update authority
- stale NAV handling
- event emission correctness
- oracle trust assumptions
- lifecycle transition rules
- distribution payment logic
- proof-of-reserves verification model
- privacy impact of holder-specific lockup data

The reference implementation is not audited.

Do not use this implementation in production without a full security review.

---

## License

The reference implementation is released under the MIT License.
