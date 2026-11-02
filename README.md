# uFund

uFund is BlockchainX's implementation of **ERC-8318 — Tokenized fund lifecycle metadata**, a minimal, read-heavy, base-token-agnostic interface for tokenized investment funds (NAV, NAV freshness, lifecycle state, distributions, fees, subscription/redemption windows, maturity), with optional extensions for AUM, holder lockups, accrued yield, multiple share classes and proof-of-reserves attestations.

> **Naming.** "uFund" is the name of this repository and its implementation contract (`UFundBase`). It is **not** the name of the ERC. The standard's interfaces are neutrally named `IFundMetadata*`, and this repository implements them as defined in ERC-8318.
>
> The ERC itself carries a minimal, self-contained reference implementation in its own assets folder (`assets/erc-8318/` in the `ethereum/ERCs` repository). This repository is a separate, independently maintained implementation and is not normative.

## Status

- Implements the ERC-8318 **core** interface `IFundMetadata` (ERC-165 ID `0x9539c458`).
- Optional extensions are declared in `contracts/interfaces/IFundMetadata.sol` but are **not** implemented by `UFundBase`, and `supportsInterface` returns `false` for them.
- **Not audited.** Do not use in production without a full security review.

## Repository structure

```text
contracts/
  interfaces/
    IFundMetadata.sol      # ERC-8318 enums, structs, core interface, events, extensions
  UFundBase.sol            # implementation of IFundMetadata (OpenZeppelin AccessControl)
test/
  UFundBase.t.sol          # Foundry tests
src/indexer/
  ufundEvents.ts           # ERC-8318 event ABI fragments for indexers
foundry.toml
```

## Interfaces and ERC-165 IDs

Interface IDs are asserted in `testInterfaceIdsMatchSpecTable` and match the table in ERC-8318:

| Interface | Interface ID |
| --- | --- |
| `IFundMetadata` | `0x9539c458` |
| `IFundMetadataAUM` | `0x081529b6` |
| `IFundMetadataLockup` | `0xb6e90569` |
| `IFundMetadataYield` | `0xc744ad19` |
| `IFundMetadataMultiClass` | `0xe872a87f` |
| `IFundMetadataProofOfReserves` | `0x9655511c` |

### Core reads (`IFundMetadata`)

- NAV: `navPerShare()`, `navAsOf(uint256)`, `navUpdatedAt()`, `navStale()`, `navStalenessThreshold()`, `valuationCurrency()`
- Lifecycle: `lifecycleState()`, `lifecycleStateUpdatedAt()`
- Distributions: `distributionCount()`, `distributionById(uint256)`, `pendingDistributionIds()`, `lastDistributionId()`, `nextDistributionDate()`
- Parameters: `managementFeeBps()`, `performanceFeeBps()`, `subscriptionFeeBps()`, `redemptionFeeBps()`, `minInvestment()`, `subscriptionWindow()`, `redemptionWindow()`, `maturityDate()`

### Required events

`NavUpdated`, `LifecycleStateChanged`, `DistributionDeclared`, `DistributionPaid`, `DistributionCancelled` — with the exact field order and `indexed` layout of ERC-8318 (checked in `testEventTopicLayout`).

## Implementation behaviour (`UFundBase`)

The ERC standardizes reads and events, not admin functions. The write functions here (`setNav`, `setLifecycleState`, `declareDistribution`, `markDistributionPaid`, `cancelDistribution`, `setFees`, `setMinInvestment`, `setWindows`, `setMaturityDate`, `setStalenessThreshold`) are **non-normative**.

- **Roles:** `FUND_ADMIN_ROLE` (lifecycle, distributions, parameters), `NAV_PUBLISHER_ROLE` (NAV), `DISTRIBUTION_AGENT_ROLE` (payment confirmation). Grant these to a multisig or timelock, not a single EOA.
- **NAV history:** append-only, sorted by effective timestamp. `navAsOf(t)` returns the latest NAV effective at or before `t` (binary search) and reverts with `NoNavAtOrBefore` if there is none. Re-publishing at the same effective timestamp is treated as a correction. Identical re-publication emits nothing.
- **Unset vs zero NAV:** before the first publication `navPerShare()` returns `(0, 0)`, `navUpdatedAt()` returns `0` and `navStale()` returns `true`. A published NAV of zero is valid and is told apart by `navUpdatedAt() != 0`.
- **Staleness:** stale when `block.timestamp - navUpdatedAt() > navStalenessThreshold()` (age equal to the threshold is not stale). A stale NAV is still returned.
- **Lifecycle:** `Pending → SubscriptionOpen → {SubscriptionClosed, Operating} → … → WindingDown → Closed`. `Closed` is terminal. `Paused` can be entered from any non-closed state and exits only to the pre-pause state or a legal successor of it. No-op transitions revert.
- **Distributions:** IDs start at 1. `distributionById` reverts for unknown IDs. A `Declared` distribution is reported as `ExDate` once its ex-date has passed. `markDistributionPaid` can be called only on or after the record date. **It does not move funds:** the `DISTRIBUTION_AGENT_ROLE` holder is trusted to call it only after settlement has actually happened. Production deployments should bind it to verified settlement.

## Build and test

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
git clone --recurse-submodules https://github.com/Blockchainxtech/ufund.git
cd ufund
forge build
forge test -vv
```

Dependencies (pinned in `foundry.lock`): OpenZeppelin Contracts v5.6.1, forge-std v1.16.1. Compiler: solc 0.8.24.

## Migration from the previous draft API

| Previous (`IERC_UFUND`) | Now (`IFundMetadata`, ERC-8318) |
| --- | --- |
| `IERC_UFUND*` interface names | `IFundMetadata*` |
| `pendingDistributions()` returning structs | `pendingDistributionIds()` + `distributionById(uint256)` |
| `lastDistribution()` returning a struct | `lastDistributionId()` + `distributionById(uint256)` |
| — | `distributionCount()` |
| `DistributionDeclared(..., amountPerShare, currency)` | adds `uint8 amountDecimals` before `currency` |
| `DistributionPaid(id, totalAmount, paidAt)` | `DistributionPaid(id, totalAmount, amountDecimals, currency, paidAt)` |
| Multi-class events overloaded core names | `ClassNavUpdated`, `ClassLifecycleStateChanged`, `ClassDistribution*` |
| `navAsOf` exact-timestamp match only | at-or-before lookup |
| Core interface ID `0x35e466ae` | `0x9539c458` |

## Security notes

`navPerShare()` is an administered value, not a market price, and a fresh NAV is not necessarily an accurate one. Integrators should check `navStale()` and apply their own risk controls. Publishing an attestation is not proof of solvency. See the Security Considerations section of ERC-8318.

## License

Implementation: MIT. `contracts/interfaces/IFundMetadata.sol`: CC0-1.0.
