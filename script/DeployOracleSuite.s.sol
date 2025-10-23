// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IdentityRegistry} from "../src/registry/IdentityRegistry.sol";
import {TEERegistry} from "../src/registry/TEERegistry.sol";
import {DstackOffchainVerifier} from "../src/verifiers/DstackVerifier.sol";
import {TeeOracle} from "../src/TeeOracle.sol";
import {TeeOracleAdapter} from "../src/TeeOracleAdapter.sol";

/// @notice Deploys the full subjective oracle stack (registries, verifier, oracle, and optional adapter).
/// @dev Configure behaviour via env vars:
///  - DCAP_VERIFIER_ADDRESS: required when DEPLOY_DSTACK_VERIFIER=true
///  - TEE_ARCH: optional raw bytes32; defaults to keccak256(TEE_ARCH_LABEL)
///  - TEE_ARCH_LABEL: optional string label (default: "INTEL_TDX")
///  - DEPLOY_DSTACK_VERIFIER: toggle off-chain verifier deployment (default: true)
///  - DEPLOY_ORACLE_ADAPTER: deploy TeeOracleAdapter for ancillary workflows (default: true)
contract DeployOracleSuite is Script {
    struct Deployment {
        address identityRegistry;
        address teeRegistry;
        address dstackVerifier;
        address teeOracle;
        address teeOracleAdapter;
        bytes32 teeArch;
    }

    function run() external returns (Deployment memory deployment) {
        bool deployDstackVerifier = vm.envOr("DEPLOY_DSTACK_VERIFIER", true);
        bool deployOracleAdapter = vm.envOr("DEPLOY_ORACLE_ADAPTER", true);

        bytes32 teeArch = vm.envOr("TEE_ARCH", bytes32(0));
        string memory teeArchLabel = "INTEL_TDX";
        try vm.envString("TEE_ARCH_LABEL") returns (string memory label) {
            teeArchLabel = label;
        } catch {}
        if (teeArch == bytes32(0)) {
            teeArch = keccak256(bytes(teeArchLabel));
        }

        address dcapVerifier = address(0);
        if (deployDstackVerifier) {
            dcapVerifier = vm.envAddress("DCAP_VERIFIER_ADDRESS");
        }

        vm.startBroadcast();

        IdentityRegistry identityRegistry = new IdentityRegistry();
        vm.label(address(identityRegistry), "IdentityRegistry");

        TEERegistry teeRegistry = new TEERegistry(address(identityRegistry));
        vm.label(address(teeRegistry), "TEERegistry");

        DstackOffchainVerifier dstackVerifier;
        if (deployDstackVerifier) {
            dstackVerifier = new DstackOffchainVerifier(dcapVerifier);
            vm.label(address(dstackVerifier), "DstackOffchainVerifier");
            teeRegistry.addVerifier(address(dstackVerifier), teeArch);
        }

        TeeOracle teeOracle = new TeeOracle(address(teeRegistry));
        vm.label(address(teeOracle), "TeeOracle");

        TeeOracleAdapter teeOracleAdapter;
        if (deployOracleAdapter) {
            teeOracleAdapter = new TeeOracleAdapter(address(teeOracle));
            vm.label(address(teeOracleAdapter), "TeeOracleAdapter");
        }

        vm.stopBroadcast();

        console2.log("IdentityRegistry deployed at", address(identityRegistry));
        console2.log("TEERegistry deployed at", address(teeRegistry));

        if (deployDstackVerifier) {
            console2.log("DstackOffchainVerifier deployed at", address(dstackVerifier));
            console2.log("TEERegistry teeArch label", teeArchLabel);
            console2.log("TEERegistry teeArch bytes32");
            console2.logBytes32(teeArch);
            console2.log("TEERegistry DCAP verifier", dcapVerifier);
        } else {
            console2.log("Skipped DstackOffchainVerifier deployment");
        }

        console2.log("TeeOracle deployed at", address(teeOracle));

        if (deployOracleAdapter) {
            console2.log("TeeOracleAdapter deployed at", address(teeOracleAdapter));
        } else {
            console2.log("Skipped TeeOracleAdapter deployment");
        }

        deployment = Deployment({
            identityRegistry: address(identityRegistry),
            teeRegistry: address(teeRegistry),
            dstackVerifier: address(dstackVerifier),
            teeOracle: address(teeOracle),
            teeOracleAdapter: address(teeOracleAdapter),
            teeArch: teeArch
        });
    }
}
