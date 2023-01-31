// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICollectionManager {

    function setDeckMaster(address _deckMaster) external;

    function setCollectionAmountForBundle(uint256 _amount) external;

    function setAcceptableERC20(address _token, bool _accept) external;

    function setAcceptableCollections(address[] memory _collections, bool _accept) external;

    function setAcceptableBundle(address _bundle, bool _accept) external;

    function setDepositFlag(address _collectionAddress, uint256 _depositLimit) external;

    function isAllowedToken(address _token) external view returns (bool);

    function checkAllowedCollection(address _collectionAddress) external view;

    function checkCollectionAvailableForDeposit(address _collectionAddress, uint256[] memory _tokenIds) external;

    function checkBundleAvailableForDeposit(address _bundleAddress, uint256 _tokenId) external;

    function getAllowedTokens() external view returns (address[] memory);

    function getAllowedCollections() external view returns (address[] memory);

    function getAllowedBundles() external view returns (address[] memory);

    function getCollectionAddress() external view returns (address[] memory);

    function getBundlesAddress() external view returns (address[] memory);
}