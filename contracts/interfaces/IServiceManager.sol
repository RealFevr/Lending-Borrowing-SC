// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IDeckStructure.sol";

interface IServiceManager is IDeckStructure {

     function setDeckMaster(address _deckMaster) external;

    function addDepositedCollections(
        uint256 _deckLpId, 
        address _collectionAddress, 
        uint256[] memory _tokenIds
    ) external;

    function addDepositedBundle(uint256 _deckLpId, address _bundleAddress, uint256 _tokenId) external;

    function removeWithdrawedCollections(uint256 _deckLpId) external returns (
        address[] memory collectionAddresses, 
        uint256[] memory tokenIds
    );

    function listDeckLpLend(
        uint256 _deckLpId,
        address _user,
        address _paymentToken,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        uint256 _duration,
        WinningDistribution memory _winDist,
        bool _prepay
    ) external;

    function borrowDeckLp(address _borrower, uint256 _borrowTimestamp, uint256 _borrowedDeckLpId, uint256 _mintDeckLpId) external;

    function checkDeckLpAvailableForClaimInterest(
        address _user, 
        uint256 _deckLpId
    ) external returns (uint256 interestAmount, address paymentToken);

    function getDeckLendInfo(uint256 _deckLpId) external view returns (
        address _lender,
        address _borrower,
        WinningDistribution memory _winDist,
        bool _isLendDeckLp,
        bool _isLend
    );

    function isLendDeckLp(uint256 _deckLpId) external view returns (bool);

    function getReceiptDeckLpInfo(uint256 _deckLpId) external view returns (
        uint256 duration, 
        uint256 prepay, 
        uint256 interest, 
        WinningDistribution memory winDistribution
    );

    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (address collectionAddress, uint256[] memory tokenIds);

    function getLendInfo(uint256 _deckLpId)  external view returns (LendInfo memory lendInfo);
}