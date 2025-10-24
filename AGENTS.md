# Repository Guidelines

## Project Structure & Module Organization
The Foundry project centers on `src/`, where `TeeOracle.sol` implements the UMA-compatible oracle, `registry/IdentityRegistry.sol` mints agent NFTs, `registry/TEERegistry.sol` tracks trusted TEEs, and `verifiers/DstackVerifier.sol` validates DCAP proofs. Deployment scripts live in `script/` with `DeployOracleSuite.s.sol` wiring the oracle suite. Runtime artifacts land in `out/` and Anvil broadcast traces in `broadcast/`; keep generated files out of PRs. Solidity tests sit under `test/` and mirror contract names with `*.t.sol`.

## Build, Test, and Development Commands
- `forge build` compiles the suite with remappings from `foundry.toml`.
- `forge test` runs the full unit test suite; add `-vvv` when debugging reverts.
- `forge test --match-path test/TeeOracle.t.sol` targets a single contract.
- `forge fmt` applies canonical formatting before opening a PR.
- `anvil --fork-url "$BASE_SEPOLIA_RPC_URL"` spins a local Base Sepolia fork (see `DEPLOYMENT_COMMANDS.md`).
- `forge script script/DeployOracleSuite.s.sol:DeployOracleSuite --rpc-url ... --broadcast` deploys to the fork or a live network.

## Coding Style & Naming Conventions
Adhere to Solidity 0.8 defaults with 4-space indentation and explicit SPDX headers. Contracts and libraries use PascalCase, storage variables camelCase, and constants UPPER_CASE. Keep functions external or public only when callable off-chain; favor revert reasons that match UMA observer logs. Run `forge fmt` and ensure no lint warnings remain.

## Testing Guidelines
Author tests in Foundry using `Test` inheritance and `vm` cheats. Name files after the subject contract (e.g., `test/TEERegistry.t.sol`) and write descriptive test function names following Arrange-Act-Assert comments when logic is non-obvious. Cover revert paths for unauthorized calls and failing attestation proofs. Use `forge coverage` locally when altering verification logic, and confirm broadcasts succeed on a fork before merging integration changes.

## Commit & Pull Request Guidelines
Follow Conventional Commits (`feat:`, `fix:`, `docs:`) as seen in recent history. Squash work-in-progress commits before pushing. PRs should link relevant Dexa issue IDs, summarize contract-level risk, and include screenshots or logs for deployments, especially fork-based scripts. Note any configuration changes to `.env`, and highlight new external dependencies or required verifier settings.

## Security & Configuration Tips
Never commit `.env` files or private keys. When testing manual resolvers, prefer the `forceAddKey` helper shown in `DEPLOYMENT_COMMANDS.md` and clean up with `forceRemoveKey`. Treat forked chain data as disposable; rerun against a fresh Anvil fork before requesting review.
