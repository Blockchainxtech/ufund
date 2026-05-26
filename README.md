# uFund Reference Implementation

This repository contains a minimal reference implementation for the draft **uFund: Fund Metadata and Lifecycle Interface** ERC.

The implementation is intentionally small and non-production. The ERC standardizes read functions and event semantics. It does not standardize admin write function names, signatures, or access-control models.

## Structure

```text
contracts/interfaces/IERC_UFUND.sol   Draft interfaces and structs
contracts/UFundBase.sol               Minimal example implementation
test/UFundBase.t.sol                  Foundry tests and interface-ID logging
src/indexer/ufundEvents.ts            TypeScript event ABI and parser helpers
```

## Install

```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
forge test -vv
```

## Compute ERC-165 interface IDs

```bash
forge test --match-test testInterfaceId -vv
```

Replace placeholder IDs in `ERCS/erc-draft_ufund.md` before opening the ERC PR.

## Important

- `setNav`, `setLifecycleState`, and `declareDistribution` are example admin functions only.
- A production implementation should add more tests, auditing, storage optimizations, timelocks/multisig/DAO controls, and extension contracts for AUM, lockups, yield, multi-class shares, and proof-of-reserves.
