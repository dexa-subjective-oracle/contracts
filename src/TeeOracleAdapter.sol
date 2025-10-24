// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TeeOracle.sol";

contract TeeOracleAdapter {
    struct Question {
        bytes ancillaryData;
        uint256 requestTimestamp;
        bool resolved;
    }

    mapping(bytes32 => Question) public questions;

    TeeOracle public immutable teeOracle;

    bytes32 internal constant IDENTIFIER = keccak256("YES_OR_NO_QUERY");

    constructor(address oracle) {
        teeOracle = TeeOracle(oracle);
    }

    function initialize(bytes calldata ancillaryData) external returns (bytes32 questionId) {
        uint256 requestTimestamp = block.timestamp;
        questionId = keccak256(ancillaryData);

        Question storage q = questions[questionId];
        q.ancillaryData = ancillaryData;
        q.requestTimestamp = requestTimestamp;

        teeOracle.requestPrice(IDENTIFIER, requestTimestamp, ancillaryData, address(0), 0);
    }

    function ready(bytes32 questionId) external view returns (bool) {
        Question storage q = questions[questionId];
        return teeOracle.hasPrice(address(this), IDENTIFIER, q.requestTimestamp, q.ancillaryData);
    }

    function resolve(bytes32 questionId) external returns (int256 price) {
        Question storage q = questions[questionId];
        price = teeOracle.settleAndGetPrice(IDENTIFIER, q.requestTimestamp, q.ancillaryData);
        q.resolved = true;
    }
}
