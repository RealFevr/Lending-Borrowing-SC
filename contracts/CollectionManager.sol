// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/BundlesInterface.sol";
import "./interfaces/ICollectionManager.sol";

contract CollectionManager is Ownable, ICollectionManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedBundles;

    mapping(address => uint256) private depositLimitations;

    address public deckMaster;
    uint256 public collectionAmountForBundle = 50;

    modifier onlyDeckMaster {
        require (msg.sender == deckMaster, "Only DeckMaster");
        _;
    }

    constructor () {}

    /// @inheritdoc ICollectionManager
    function setDeckMaster(address _deckMaster) external override onlyOwner {
        require (_deckMaster != address(0), "zero deck master address");
        deckMaster = _deckMaster;
    }

    /// @inheritdoc ICollectionManager
    function setCollectionAmountForBundle(
        uint256 _amount
    ) external override onlyDeckMaster {
        collectionAmountForBundle = _amount;
    }

    /// @inheritdoc ICollectionManager
    function setAcceptableERC20(
        address _token, 
        bool _accept
    ) external override onlyDeckMaster {
        require (
            (_accept && !allowedTokens.contains(_token)) ||
            (!_accept && allowedTokens.contains(_token)),
            "Already set"
        );

        if (_accept) { allowedTokens.add(_token); }
        else { allowedTokens.remove(_token); }
    }

    /// @inheritdoc ICollectionManager
    function setAcceptableCollections(
        address[] memory _collections, 
        bool _accept
    ) external override onlyDeckMaster {
        uint256 length = _collections.length;
        require (length > 0, "invalid collection length");
        
        for (uint256 i = 0; i < length; i ++) {
            address collection = _collections[i];
            require (collection != address(0), "zero collection address");
            require (
                (_accept && !allowedCollections.contains(collection)) ||
                (!_accept && allowedCollections.contains(collection)),
                "Already set"
            );
            if (_accept) { allowedCollections.add(collection); }
            else { allowedCollections.remove(collection); }
        }
    }

    /// @inheritdoc ICollectionManager
    function setAcceptableBundle(
        address _bundle, 
        bool _accept
    ) external override onlyDeckMaster {
        require (
            (_accept && !allowedBundles.contains(_bundle)) ||
            (!_accept && allowedBundles.contains(_bundle)),
            "Already set"
        );
        if (_accept) { allowedBundles.add(_bundle); }
        else { allowedBundles.remove(_bundle); }
    }

    /// @inheritdoc ICollectionManager
    function setDepositFlag(
        address _collectionAddress, 
        uint256 _depositLimit
    ) external override onlyDeckMaster {
         require (
            _collectionAddress != address(0) && 
            (allowedCollections.contains(_collectionAddress) || allowedBundles.contains(_collectionAddress)),
            "invalid collection address"
        );
        depositLimitations[_collectionAddress] = _depositLimit;
    }

    /// @inheritdoc ICollectionManager
    function isAllowedToken(address _token) external view returns (bool) {
        return allowedTokens.contains(_token);
    }

    /// @inheritdoc ICollectionManager
    function checkAllowedCollection(address _collectionAddress) external view {
        require (
            _collectionAddress != address(0) && 
            (allowedCollections.contains(_collectionAddress) || allowedBundles.contains(_collectionAddress)), 
            "not acceptable collection address"
        );
    }

    /// @inheritdoc ICollectionManager
    function checkCollectionAvailableForDeposit(
        address _collectionAddress, 
        uint256[] memory _tokenIds
    ) external override onlyDeckMaster {
        uint256 length = _tokenIds.length;
        require (allowedCollections.contains(_collectionAddress), "Not acceptable collection address");
        require (depositLimitations[_collectionAddress] >= length, "exceeds to max deposit limit");
        depositLimitations[_collectionAddress] -= length;
    }

    /// @inheritdoc ICollectionManager
    function checkBundleAvailableForDeposit(
        address _bundleAddress, 
        uint256 _tokenId
    ) external override onlyDeckMaster {
        require (allowedBundles.contains(_bundleAddress), "Not acceptable bundle address");
        require (depositLimitations[_bundleAddress] > 0, "exceeds to max deposit limit");

        (,,address[] memory collections,) = BundlesInterface(_bundleAddress).getBundle(_tokenId);
        require (collections.length == collectionAmountForBundle, "Bundle should have certain collections");

        depositLimitations[_bundleAddress] -= 1;
    }

    /// @inheritdoc ICollectionManager
    function getAllowedTokens() external view returns (address[] memory) {
        return allowedTokens.values();
    }

    /// @inheritdoc ICollectionManager
    function getAllowedCollections() external view returns (address[] memory) {
        return allowedCollections.values();
    }

    /// @inheritdoc ICollectionManager
    function getAllowedBundles() external view returns (address[] memory) {
        return allowedBundles.values();
    }

    /// @inheritdoc ICollectionManager
    function getCollectionAddress() external view returns (address[] memory) {
        return allowedCollections.values();
    }

    /// @inheritdoc ICollectionManager
    function getBundlesAddress() external view returns (address[] memory) {
        return allowedBundles.values();
    }
}