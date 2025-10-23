// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITEEVerifier {
    function verify(
        address identityRegistry,
        uint256 agentId,
        bytes32 codeMeasurement,
        address pubkey,
        string calldata codeConfigUri,
        bytes calldata proof
    ) external returns (bool);
}
