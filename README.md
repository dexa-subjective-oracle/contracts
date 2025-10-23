## Dexa Subjective Oracle Contracts

On-chain components for the Dexa subjective oracle. This repository packages the UMA-compatible oracle, identity & TEE registries, and verifier wiring as a Foundry project.

### Layout
- `src/TeeOracle.sol`: UMA-style oracle storing price requests, verifying resolver authorization through the TEE registry, and emitting evidence hashes with each settlement.
- `src/registry/IdentityRegistry.sol`: ERC-721 identity registry for agents (`agentId` NFTs).
- `src/registry/TEERegistry.sol`: Associates TEE-derived pubkeys with agents, enforces ownership approvals, and validates DCAP proofs via pluggable verifiers.
- `src/verifiers/DstackVerifier.sol`: Intel TDX/DCAP verifier implementation compatible with dstack flows.
- `test/TeeOracle.t.sol`: Foundry tests covering registration flow, proof failures, and oracle settlement.

### Quick Start

```bash
forge install
forge fmt
forge test
```

### Registering a TEE Key
1. Deploy `IdentityRegistry` and mint an NFT for your agent.
2. Deploy `TEERegistry`, pointing it to the identity registry, and whitelist a proof verifier (e.g. the dstack verifier contract).
3. Call `addKey(agentId, teeArch, codeMeasurement, pubkey, codeConfigUri, verifier, proof)` from the agent owner. The verifier must accept the proof; otherwise registration reverts.
4. Deploy `TeeOracle` with the TEE registry address. When a price request is ready, the registered TEE key calls `settlePrice(...)` with the evidence hash emitted by the off-chain agent.

### Links
- Agent runtime: https://github.com/dexa-subjective-oracle/erc-8004-oracle-agent-dstack
- Foundry docs: https://book.getfoundry.sh
