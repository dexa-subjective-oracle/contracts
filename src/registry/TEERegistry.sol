// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ITEERegistry.sol";
import "../interfaces/ITEEVerifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IIdentityRegistryLike {
    function ownerOf(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

contract TEERegistry is ITEERegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public identityRegistry;
    address public constant MANUAL_VERIFIER = address(0xdead);

    mapping(address => Verifier) private _verifiers;
    mapping(uint256 => EnumerableSet.AddressSet) private _agentKeys;
    mapping(address => Key) private _keys;
    mapping(address => uint256) private _keyAgents;

    constructor(address _identityRegistry) Ownable(msg.sender) {
        identityRegistry = _identityRegistry;
    }

    function verifiers(address verifier) external view returns (Verifier memory) {
        return _verifiers[verifier];
    }

    function keys(uint256 agentId, address pubkey) external view returns (Key memory) {
        return _keys[pubkey];
    }

    function addVerifier(address verifier, bytes32 teeArch) external onlyOwner {
        require(verifier != address(0), "Invalid verifier address");

        _verifiers[verifier] = Verifier({teeArch: teeArch});

        emit VerifierAdded(verifier, teeArch);
    }

    function removeVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "Invalid verifier address");

        delete _verifiers[verifier];

        emit VerifierRemoved(verifier);
    }

    function addKey(
        uint256 agentId,
        bytes32 teeArch,
        bytes32 codeMeasurement,
        address pubkey,
        string calldata codeConfigUri,
        address verifier,
        bytes calldata proof
    ) external {
        require(pubkey != address(0), "Invalid pubkey");
        address owner = IIdentityRegistryLike(identityRegistry).ownerOf(agentId);
        require(
            msg.sender == owner || IIdentityRegistryLike(identityRegistry).isApprovedForAll(owner, msg.sender)
                || IIdentityRegistryLike(identityRegistry).getApproved(agentId) == msg.sender,
            "Not authorized"
        );

        require(_verifiers[verifier].teeArch != bytes32(0), "Verifier not whitelisted");

        bool valid =
            ITEEVerifier(verifier).verify(identityRegistry, agentId, codeMeasurement, pubkey, codeConfigUri, proof);
        require(valid, "Invalid proof");

        _storeKey(agentId, teeArch, codeMeasurement, pubkey, codeConfigUri, verifier);
    }

    function removeKey(uint256 agentId, address pubkey) external {
        address owner = IIdentityRegistryLike(identityRegistry).ownerOf(agentId);
        require(
            msg.sender == owner || IIdentityRegistryLike(identityRegistry).isApprovedForAll(owner, msg.sender)
                || IIdentityRegistryLike(identityRegistry).getApproved(agentId) == msg.sender,
            "Not authorized"
        );

        _removeKey(agentId, pubkey);
    }

    function forceAddKey(
        uint256 agentId,
        bytes32 teeArch,
        bytes32 codeMeasurement,
        address pubkey,
        string calldata codeConfigUri
    ) external onlyOwner {
        require(pubkey != address(0), "Invalid pubkey");
        _storeKey(agentId, teeArch, codeMeasurement, pubkey, codeConfigUri, MANUAL_VERIFIER);
    }

    function forceRemoveKey(address pubkey) external onlyOwner {
        Key memory existing = _keys[pubkey];
        require(existing.verifier != address(0), "Key not found");
        uint256 agentId = _keyAgents[pubkey];
        _removeKey(agentId, pubkey);
    }

    function getKey(uint256 agentId, address pubkey) external view returns (Key memory) {
        require(_agentKeys[agentId].contains(pubkey), "Key not found");
        return _keys[pubkey];
    }

    function hasKey(uint256 agentId, address pubkey) external view returns (bool) {
        return _agentKeys[agentId].contains(pubkey);
    }

    function getKeyCount(uint256 agentId) external view returns (uint256) {
        return _agentKeys[agentId].length();
    }

    function getKeyAtIndex(uint256 agentId, uint256 index) external view returns (address) {
        return _agentKeys[agentId].at(index);
    }

    function isVerifier(address verifier) external view returns (bool) {
        return _verifiers[verifier].teeArch != bytes32(0);
    }

    function getIdentityRegistry() external view returns (address) {
        return identityRegistry;
    }

    function isRegisteredKey(address pubkey) external view returns (bool) {
        return _keys[pubkey].verifier != address(0);
    }

    function keyAgent(address pubkey) external view returns (uint256) {
        return _keyAgents[pubkey];
    }

    function _storeKey(
        uint256 agentId,
        bytes32 teeArch,
        bytes32 codeMeasurement,
        address pubkey,
        string memory codeConfigUri,
        address verifier
    ) internal {
        require(_keys[pubkey].verifier == address(0), "Key already exists");

        _keys[pubkey] = Key({
            teeArch: teeArch,
            codeMeasurement: codeMeasurement,
            pubkey: abi.encodePacked(pubkey),
            codeConfigUri: codeConfigUri,
            verifier: verifier
        });
        _keyAgents[pubkey] = agentId;
        _agentKeys[agentId].add(pubkey);

        emit KeyAdded(agentId, teeArch, codeMeasurement, pubkey, codeConfigUri, verifier);
    }

    function _removeKey(uint256 agentId, address pubkey) internal {
        require(_agentKeys[agentId].contains(pubkey), "Key not found");

        _agentKeys[agentId].remove(pubkey);
        delete _keys[pubkey];
        delete _keyAgents[pubkey];

        emit KeyRemoved(agentId, pubkey);
    }
}
