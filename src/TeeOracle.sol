// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITEERegistry.sol";

contract TeeOracle {
    error UnauthorizedResolver();
    error PriceNotAvailable();
    error RequestAlreadyExists();
    error RequestNotFound();

    struct Request {
        address requester;
        address rewardToken;
        uint256 reward;
        uint256 timestamp;
        bytes32 identifier;
        bytes ancillaryData;
        bool settled;
        int256 settledPrice;
        bytes32 evidenceHash;
    }

    event PriceRequested(bytes32 indexed requestId, address indexed requester, bytes ancillaryData);
    event PriceSettled(bytes32 indexed requestId, int256 price, address indexed resolver, bytes32 evidenceHash);

    mapping(bytes32 => Request) public requests;
    bytes32[] private _pendingRequests;
    mapping(bytes32 => uint256) private _pendingIndex;
    ITEERegistry public teeRegistry;

    constructor(address teeRegistry_) {
        teeRegistry = ITEERegistry(teeRegistry_);
    }

    function requestPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        address rewardToken,
        uint256 reward
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encode(identifier, timestamp, ancillaryData));
        Request storage req = requests[requestId];
        if (req.requester != address(0)) {
            revert RequestAlreadyExists();
        }
        req.requester = msg.sender;
        req.rewardToken = rewardToken;
        req.reward = reward;
        req.timestamp = timestamp;
        req.identifier = identifier;
        req.ancillaryData = ancillaryData;
        _addPendingRequest(requestId);
        emit PriceRequested(requestId, msg.sender, ancillaryData);
    }

    function hasPrice(address, bytes32 identifier, uint256 timestamp, bytes memory ancillaryData)
        external
        view
        returns (bool)
    {
        bytes32 requestId = keccak256(abi.encode(identifier, timestamp, ancillaryData));
        Request storage req = requests[requestId];
        if (req.requester == address(0)) {
            revert RequestNotFound();
        }
        return req.settled;
    }

    function settlePrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 price,
        bytes32 evidenceHash
    ) external {
        bytes32 requestId = keccak256(abi.encode(identifier, timestamp, ancillaryData));
        Request storage req = requests[requestId];
        if (req.requester == address(0)) {
            revert RequestNotFound();
        }
        if (!teeRegistry.isRegisteredKey(msg.sender)) {
            revert UnauthorizedResolver();
        }
        req.settled = true;
        req.settledPrice = price;
        req.evidenceHash = evidenceHash;
        _removePendingRequest(requestId);
        emit PriceSettled(requestId, price, msg.sender, evidenceHash);
    }

    function settleAndGetPrice(bytes32 identifier, uint256 timestamp, bytes memory ancillaryData)
        external
        view
        returns (int256)
    {
        bytes32 requestId = keccak256(abi.encode(identifier, timestamp, ancillaryData));
        Request storage req = requests[requestId];
        if (req.requester == address(0)) {
            revert RequestNotFound();
        }
        if (!req.settled) {
            revert PriceNotAvailable();
        }
        return req.settledPrice;
    }

    function pendingRequests() external view returns (bytes32[] memory) {
        return _pendingRequests;
    }

    function getRequest(bytes32 requestId) external view returns (Request memory) {
        Request storage req = requests[requestId];
        if (req.requester == address(0)) {
            revert RequestNotFound();
        }
        return req;
    }

    function _addPendingRequest(bytes32 requestId) internal {
        _pendingIndex[requestId] = _pendingRequests.length + 1;
        _pendingRequests.push(requestId);
    }

    function _removePendingRequest(bytes32 requestId) internal {
        uint256 indexPlusOne = _pendingIndex[requestId];
        if (indexPlusOne == 0) {
            return;
        }
        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = _pendingRequests.length - 1;
        if (index != lastIndex) {
            bytes32 lastId = _pendingRequests[lastIndex];
            _pendingRequests[index] = lastId;
            _pendingIndex[lastId] = index + 1;
        }
        _pendingRequests.pop();
        delete _pendingIndex[requestId];
    }
}
