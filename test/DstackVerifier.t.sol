// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../src/verifiers/DstackVerifier.sol";

contract MockDcapVerifier {
    bool public shouldSucceed = true;

    function setShouldSucceed(bool value) external {
        shouldSucceed = value;
    }

    function verifyAndAttestOnChain(bytes calldata) external view returns (bool, bytes memory) {
        return (shouldSucceed, bytes(""));
    }
}

contract DstackVerifierTest is Test {
    MockDcapVerifier internal mockDcap;
    DstackOffchainVerifier internal verifier;

    address internal constant UNAUTHORIZED = address(0xBEEF);

    function setUp() public {
        mockDcap = new MockDcapVerifier();
        verifier = new DstackOffchainVerifier(address(mockDcap));
    }

    function testSetReferenceValuesOnlyOwner() public {
        (
            bytes memory mrTd,
            bytes memory mrConfigId,
            bytes memory rtMr0,
            bytes memory rtMr1,
            bytes memory rtMr2,
            bytes memory rtMr3
        ) = _buildReferences();

        vm.prank(UNAUTHORIZED);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, UNAUTHORIZED));
        verifier.setReferenceValues(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3);

        verifier.setReferenceValues(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3);
    }

    function testSetReferenceValuesRejectsInvalidLength() public {
        bytes memory invalid = new bytes(47);
        vm.expectRevert("Invalid mrTd length");
        verifier.setReferenceValues(invalid, invalid, invalid, invalid, invalid, invalid);
    }

    function testInitValidatorOnlyOwner() public {
        (
            bytes memory mrTd,
            bytes memory mrConfigId,
            bytes memory rtMr0,
            bytes memory rtMr1,
            bytes memory rtMr2,
            bytes memory rtMr3
        ) = _buildReferences();

        verifier.setReferenceValues(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3);

        bytes memory rawQuote = _buildRawQuote(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3, UNAUTHORIZED);

        vm.prank(UNAUTHORIZED);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, UNAUTHORIZED));
        verifier.initValidator(UNAUTHORIZED, rawQuote);
    }

    function testInitValidatorFailsWhenDcapFails() public {
        (
            bytes memory mrTd,
            bytes memory mrConfigId,
            bytes memory rtMr0,
            bytes memory rtMr1,
            bytes memory rtMr2,
            bytes memory rtMr3
        ) = _buildReferences();
        verifier.setReferenceValues(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3);

        bytes memory rawQuote = _buildRawQuote(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3, address(0xCAFE));

        mockDcap.setShouldSucceed(false);
        vm.expectRevert("DCAP verification failed");
        verifier.initValidator(address(0xCAFE), rawQuote);
    }

    function testInitValidatorSucceedsWithValidQuote() public {
        (
            bytes memory mrTd,
            bytes memory mrConfigId,
            bytes memory rtMr0,
            bytes memory rtMr1,
            bytes memory rtMr2,
            bytes memory rtMr3
        ) = _buildReferences();
        verifier.setReferenceValues(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3);

        address validator = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        bytes memory rawQuote = _buildRawQuote(mrTd, mrConfigId, rtMr0, rtMr1, rtMr2, rtMr3, validator);

        verifier.initValidator(validator, rawQuote);

        assertEq(verifier.validatorPublicKey(), validator, "validator stored");
    }

    function _buildReferences()
        internal
        pure
        returns (
            bytes memory mrTd,
            bytes memory mrConfigId,
            bytes memory rtMr0,
            bytes memory rtMr1,
            bytes memory rtMr2,
            bytes memory rtMr3
        )
    {
        mrTd = _measurement(0x10);
        mrConfigId = _measurement(0x20);
        rtMr0 = _measurement(0x30);
        rtMr1 = _measurement(0x40);
        rtMr2 = _measurement(0x50);
        rtMr3 = _measurement(0x60);
    }

    function _buildRawQuote(
        bytes memory mrTd,
        bytes memory mrConfigId,
        bytes memory rtMr0,
        bytes memory rtMr1,
        bytes memory rtMr2,
        bytes memory rtMr3,
        address validator
    ) internal pure returns (bytes memory rawQuote) {
        rawQuote = new bytes(632);
        _write(rawQuote, 184, mrTd);
        _write(rawQuote, 232, mrConfigId);
        _write(rawQuote, 376, rtMr0);
        _write(rawQuote, 424, rtMr1);
        _write(rawQuote, 472, rtMr2);
        _write(rawQuote, 520, rtMr3);
        bytes memory reportData = _encodeValidator(validator);
        _write(rawQuote, 568, reportData);
    }

    function _measurement(uint8 seed) internal pure returns (bytes memory out) {
        out = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            out[i] = bytes1(uint8(uint256(seed) + i));
        }
    }

    function _write(bytes memory target, uint256 offset, bytes memory data) internal pure {
        for (uint256 i = 0; i < data.length; i++) {
            target[offset + i] = data[i];
        }
    }

    function _encodeValidator(address validator) internal pure returns (bytes memory reportData) {
        reportData = new bytes(64);
        bytes memory encoded = abi.encodePacked(bytes32(uint256(uint160(validator)) << 96));
        for (uint256 i = 0; i < encoded.length; i++) {
            reportData[i] = encoded[i];
        }
    }
}
