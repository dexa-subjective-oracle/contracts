// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/TeeOracle.sol";
import "../src/TeeOracleAdapter.sol";
import "../src/registry/IdentityRegistry.sol";
import "../src/registry/TEERegistry.sol";

contract MockProofVerifier {
    bool public shouldVerify = true;

    function setShouldVerify(bool value) external {
        shouldVerify = value;
    }

    function verify(address, uint256, bytes32, address, string calldata, bytes calldata) external view returns (bool) {
        return shouldVerify;
    }
}

contract TeeOracleTest is Test {
    TeeOracle internal oracle;
    TeeOracleAdapter internal adapter;
    IdentityRegistry internal identityRegistry;
    TEERegistry internal teeRegistry;
    MockProofVerifier internal mockVerifier;

    bytes32 internal constant IDENTIFIER = keccak256("YES_OR_NO_QUERY");
    bytes internal constant ANCILLARY_DATA = abi.encodePacked("FED OCT 2025");
    address internal constant AGENT = address(0xA11CE);
    address internal constant OTHER = address(0xBEEF);
    uint256 internal agentId;

    function setUp() public {
        identityRegistry = new IdentityRegistry();
        teeRegistry = new TEERegistry(address(identityRegistry));
        mockVerifier = new MockProofVerifier();

        teeRegistry.addVerifier(address(mockVerifier), bytes32("TDX"));

        vm.prank(AGENT);
        agentId = identityRegistry.register();

        vm.prank(AGENT);
        teeRegistry.addKey(
            agentId, bytes32("TDX"), keccak256("code"), AGENT, "ipfs://config", address(mockVerifier), bytes("")
        );

        oracle = new TeeOracle(address(teeRegistry));
        adapter = new TeeOracleAdapter(address(oracle));
    }

    function testRequestPriceStoresRequest() public {
        uint256 timestamp = block.timestamp;

        bytes32 requestId = oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        (
            address requester,
            address rewardToken,
            uint256 reward,
            uint256 storedTimestamp,
            bool settled,
            int256 settledPrice,
            bytes32 storedHash
        ) = oracle.requests(requestId);

        assertEq(requester, address(this), "requester");
        assertEq(rewardToken, address(0), "reward token");
        assertEq(reward, 0, "reward");
        assertEq(storedTimestamp, timestamp, "timestamp");
        assertFalse(settled, "should not be settled");
        assertEq(settledPrice, 0, "price default");
        assertEq(storedHash, bytes32(0), "hash default");

        bytes32[] memory pending = oracle.pendingRequests();
        assertEq(pending.length, 1, "pending length");
        assertEq(pending[0], requestId, "pending id");
    }

    function testHasPriceFalseBeforeSettlement() public {
        uint256 timestamp = block.timestamp;
        oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        bool hasPrice = oracle.hasPrice(address(this), IDENTIFIER, timestamp, ANCILLARY_DATA);
        assertFalse(hasPrice, "should be false before settlement");
    }

    function testSettlePriceRequiresAuthorization() public {
        uint256 timestamp = block.timestamp;
        oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        vm.expectRevert(TeeOracle.UnauthorizedResolver.selector);
        vm.prank(OTHER);
        oracle.settlePrice(IDENTIFIER, timestamp, ANCILLARY_DATA, 1e18, bytes32("hash"));
    }

    function testSettlePriceWithoutRequestReverts() public {
        vm.expectRevert(TeeOracle.RequestNotFound.selector);
        oracle.settlePrice(IDENTIFIER, block.timestamp, ANCILLARY_DATA, 1e18, bytes32("hash"));
    }

    function testSettlePriceUpdatesRequest() public {
        uint256 timestamp = block.timestamp;
        bytes32 requestId = oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        vm.prank(AGENT);
        oracle.settlePrice(IDENTIFIER, timestamp, ANCILLARY_DATA, 1e18, bytes32("hash"));

        (,,,, bool settled, int256 settledPrice, bytes32 storedHash) = oracle.requests(requestId);

        assertTrue(settled, "should be settled");
        assertEq(settledPrice, 1e18, "price");
        assertEq(storedHash, bytes32("hash"), "hash stored");
        assertTrue(oracle.hasPrice(address(this), IDENTIFIER, timestamp, ANCILLARY_DATA), "has price true");

        bytes32[] memory pendingAfter = oracle.pendingRequests();
        assertEq(pendingAfter.length, 0, "pending cleared");
    }

    function testSettleAndGetPriceRevertsWhenUnset() public {
        uint256 timestamp = block.timestamp;
        oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        vm.expectRevert(TeeOracle.PriceNotAvailable.selector);
        oracle.settleAndGetPrice(IDENTIFIER, timestamp, ANCILLARY_DATA);
    }

    function testAdapterFlow() public {
        bytes32 questionId = adapter.initialize(ANCILLARY_DATA);
        (bytes memory storedAncillary, uint256 requestTimestamp, bool resolved) = adapter.questions(questionId);

        assertEq(storedAncillary, ANCILLARY_DATA, "ancillary stored");
        assertEq(requestTimestamp, block.timestamp, "timestamp stored");
        assertFalse(resolved, "should not be resolved yet");
        assertFalse(adapter.ready(questionId), "ready should be false");

        vm.prank(AGENT);
        oracle.settlePrice(IDENTIFIER, requestTimestamp, ANCILLARY_DATA, 0, bytes32("hash"));

        assertTrue(adapter.ready(questionId), "ready should be true");

        int256 price = adapter.resolve(questionId);
        assertEq(price, 0, "adapter price");
        (,, bool isResolved) = adapter.questions(questionId);
        assertTrue(isResolved, "question resolved");
    }

    function testResolveBeforeReadyReverts() public {
        bytes32 questionId = adapter.initialize(ANCILLARY_DATA);
        vm.expectRevert(TeeOracle.PriceNotAvailable.selector);
        adapter.resolve(questionId);
    }

    function testAddKeyFailsWithInvalidProof() public {
        vm.prank(AGENT);
        teeRegistry.removeKey(agentId, AGENT);
        mockVerifier.setShouldVerify(false);

        vm.expectRevert(bytes("Invalid proof"));
        vm.prank(AGENT);
        teeRegistry.addKey(
            agentId,
            bytes32("TDX"),
            keccak256("code2"),
            address(0xCAFE),
            "ipfs://config",
            address(mockVerifier),
            bytes("")
        );
    }

    function testForceAddKeyRequiresOwner() public {
        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, AGENT));
        teeRegistry.forceAddKey(agentId, bytes32("TDX"), keccak256("manual"), OTHER, "manual://dev");
    }

    function testManualResolverFlow() public {
        vm.prank(AGENT);
        teeRegistry.removeKey(agentId, AGENT);

        uint256 timestamp = block.timestamp;
        oracle.requestPrice(IDENTIFIER, timestamp, ANCILLARY_DATA, address(0), 0);

        vm.expectRevert(TeeOracle.UnauthorizedResolver.selector);
        vm.prank(AGENT);
        oracle.settlePrice(IDENTIFIER, timestamp, ANCILLARY_DATA, 1e18, bytes32("hash"));

        teeRegistry.forceAddKey(agentId, bytes32("TDX"), keccak256("manual"), OTHER, "manual://dev");

        assertTrue(teeRegistry.isRegisteredKey(OTHER), "manual key registered");
        assertEq(teeRegistry.keyAgent(OTHER), agentId, "manual key agent mapping");

        vm.prank(OTHER);
        oracle.settlePrice(IDENTIFIER, timestamp, ANCILLARY_DATA, 2e18, bytes32("manual"));

        teeRegistry.forceRemoveKey(OTHER);
        assertFalse(teeRegistry.isRegisteredKey(OTHER), "manual key removed");
    }
}
