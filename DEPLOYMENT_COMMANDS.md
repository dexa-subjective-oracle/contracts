# Local Deployment Commands

## 1. Mirror Base Sepolia with Anvil

```bash
export BASE_SEPOLIA_RPC="https://base-sepolia.g.alchemy.com/v2/cLyinDK_XlPm5cQdjpQZ0"

anvil \
  --fork-url "$BASE_SEPOLIA_RPC" \
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

DCAP_VERIFIER_ADDRESS=0x95175096a9B74165BE0ac84260cc14Fc1c0EF5FF \
TEE_ARCH_LABEL="INTEL_TDX" \
forge script script/DeployOracleSuite.s.sol:DeployOracleSuite \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

- Override `TEE_ARCH_LABEL` or supply `TEE_ARCH` if you need a custom measurement key.
- Set `DEPLOY_DSTACK_VERIFIER=false` to skip the verifier, or `DEPLOY_ORACLE_ADAPTER=false` to omit the adapter.
- Replace the private key with your funded deployer when targeting a live fork.
