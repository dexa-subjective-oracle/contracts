# Local Deployment Commands

## 1. Mirror Base Sepolia with Anvil

```bash
cp .env.example .env   # first time only
source .env

anvil \
  --fork-url "$BASE_SEPOLIA_RPC_URL" \
  --chain-id 84532 \
  --host 127.0.0.1 \
  --port 8545 \
  --steps-tracing
```

> Tip: Pin to a recent block with `--fork-block-number <height>` if you need reproducible results.

## 2. Deploy the Oracle Suite

Open a new terminal in `contracts/` and broadcast the deployment script against the fork:

```bash
cd contracts

source .env

forge script script/DeployOracleSuite.s.sol:DeployOracleSuite \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key "$DEPLOYER_PRIVATE_KEY"
```

- Tweak `TEE_ARCH_LABEL`, `TEE_ARCH`, or other flags directly in `.env` (e.g. set `DEPLOY_DSTACK_VERIFIER=false`).
- Replace `DEPLOYER_PRIVATE_KEY` with a funded key before targeting a shared fork or live network.

## 3. Manually Register a Resolver Key (Dev Only)

While you iterate without a real TEE, authorize a resolver by calling the registry owner helper:

```bash
cast send $TEE_REGISTRY_ADDRESS \
  'forceAddKey(uint256,bytes32,bytes32,address,string)' \
  $AGENT_ID \
  $TEE_ARCH_HASH \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $RESOLVER_ADDRESS \
  manual://dev \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$DEPLOYER_PRIVATE_KEY"
```

- Use the agent ID returned by `IdentityRegistry.register()` and the resolver wallet that will call `settlePrice`.
- `TEE_ARCH_HASH` can reuse the hash logged during deployment (e.g. `0xf966…b98f`).
- Remove a manual resolver with `cast send $TEE_REGISTRY_ADDRESS 'forceRemoveKey(address)' $RESOLVER_ADDRESS ...`.
