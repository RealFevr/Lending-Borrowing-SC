// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/BundlesInterface.sol";
import "./interfaces/IServiceManager.sol";

contract ServiceManager is Ownable, IServiceManager {

    mapping(uint256 => DeckLPInfo) private deckLpInfos;
    mapping(uint256 => LendInfo) private lendInfos;

    address public deckMaster;
    
    modifier onlyDeckMaster {
        require (msg.sender == deckMaster, "Only DeckMaster");
        _;
    }

    constructor () {}

    function setDeckMaster(address _deckMaster) external onlyOwner {
        require (_deckMaster != address(0), "zero deck master address");
        deckMaster = _deckMaster;
    }

    function addDepositedCollections(
        uint256 _deckLpId,
        address _collectionAddress, 
        uint256[] memory _tokenIds
    ) external {
        DeckLPInfo storage deckLpInfo = deckLpInfos[_deckLpId];
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i ++) {
            deckLpInfo.collectionAddresses.push(_collectionAddress);
            deckLpInfo.tokenIds.push(_tokenIds[i]);
        }
    }

    function addDepositedBundle(uint256 _deckLpId, address _bundleAddress, uint256 _tokenId) external {
        DeckLPInfo storage deckLpInfo = deckLpInfos[_deckLpId];
        deckLpInfo.collectionAddresses.push(_bundleAddress);
        deckLpInfo.tokenIds.push(_tokenId);
    }

    function removeWithdrawedCollections(uint256 _deckLpId) external returns (
        address[] memory collectionAddresses, 
        uint256[] memory tokenIds
    ) {
        DeckLPInfo storage deck = deckLpInfos[_deckLpId];
        require (!deck.lendDeckLp, "receipt deckLp");
        require (!deck.listedLend && !deck.lend, "related to lend");
        
        collectionAddresses = deck.collectionAddresses;
        tokenIds = deck.tokenIds;
        delete deck.collectionAddresses;
        delete deck.tokenIds;
    }

    function listDeckLpLend(
        uint256 _deckLpId,
        address _user,
        address _paymentToken,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        uint256 _duration,
        WinningDistribution memory _winDist,
        bool _prepay
    ) external {
        require (
            !deckLpInfos[_deckLpId].lendDeckLp &&
            !deckLpInfos[_deckLpId].listedLend && 
            !deckLpInfos[_deckLpId].lend,
            "already listed or lent"
        );

        deckLpInfos[_deckLpId].listedLend = true;
        lendInfos[_deckLpId] = LendInfo(
            _user, 
            address(0), 
            _paymentToken, 
            _dailyInterest, 
            _prepayAmount, 
            0, 
            _duration, 
            _winDist,
            _prepay
        );
    }

    function borrowDeckLp(address _borrower, uint256 _borrowTimestamp, uint256 _borrowedDeckLpId, uint256 _mintDeckLpId) external {
        DeckLPInfo storage deckLpInfo = deckLpInfos[_borrowedDeckLpId];
        LendInfo storage lendInfo = lendInfos[_borrowedDeckLpId];
        require (!deckLpInfo.lendDeckLp, "This is receipt deckLp");
        require (deckLpInfo.listedLend && !deckLpInfo.lend, "not listed");

        deckLpInfo.listedLend = false;
        deckLpInfo.lend = true;
        lendInfo.borrower = _borrower;
        lendInfo.borrowedTimestamp = _borrowTimestamp;

        deckLpInfos[_mintDeckLpId].lendDeckLp = true;
        deckLpInfos[_mintDeckLpId].borrowedDeckLpId = _borrowedDeckLpId;
    }

    function checkDeckLpAvailableForClaimInterest(
        address _user, 
        uint256 _deckLpId
    ) external returns (uint256 interestAmount, address paymentToken) {
        DeckLPInfo storage deckLpInfo = deckLpInfos[_deckLpId];
        require (!deckLpInfo.lendDeckLp, "this deckLp is receipt deckLp");
        require (deckLpInfo.lend, "this deck is not lent deckLp");
        LendInfo memory lendInfo = lendInfos[_deckLpId];
        require (lendInfo.lender == _user, "not lender");
        require (block.timestamp > lendInfo.borrowedTimestamp + lendInfo.borrowDuration, "can not claim interest in lend duration");
        interestAmount = lendInfo.dailyInterest * (lendInfo.borrowDuration);
        deckLpInfo.lend = deckLpInfo.listedLend = false;
        paymentToken = lendInfo.paymentToken;
    }

    function getDeckLendInfo(uint256 _deckLpId) external view returns (
        address _lender,
        address _borrower,
        WinningDistribution memory _winDist,
        bool _isLendDeckLp,
        bool _isLend
    ) {
        LendInfo memory lendInfo = lendInfos[_deckLpId];
        _lender = lendInfo.lender;
        _borrower = lendInfo.borrower;
        _winDist = lendInfo.winDistributionRate;
        _isLendDeckLp = deckLpInfos[_deckLpId].lendDeckLp;
        _isLend = deckLpInfos[_deckLpId].lend;
    }

    function isLendDeckLp(uint256 _deckLpId) external view returns (bool) {
        return deckLpInfos[_deckLpId].lendDeckLp;
    }

    function getReceiptDeckLpInfo(uint256 _deckLpId) external view returns (
        uint256 duration, 
        uint256 prepay, 
        uint256 interest, 
        WinningDistribution memory winDistribution
    ) {
        DeckLPInfo memory deckLpInfo = deckLpInfos[_deckLpId];
        require (deckLpInfo.lendDeckLp, "this deckLp is not receipt deckLp");
        LendInfo memory lendInfo = lendInfos[deckLpInfo.borrowedDeckLpId];
        duration = lendInfo.borrowDuration;
        prepay= lendInfo.prepayAmount;
        interest = lendInfo.dailyInterest;
        winDistribution = lendInfo.winDistributionRate;
    }

    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (address collectionAddress, uint256[] memory tokenIds) {
        DeckLPInfo memory deckLpInfo = deckLpInfos[_deckLpId];
        require (!deckLpInfo.lendDeckLp, "this deckLp is receipt deckLp");
        return (deckLpInfo.collectionAddresses[0], deckLpInfo.tokenIds);
    }

    function getLendInfo(uint256 _deckLpId)  external view returns (LendInfo memory lendInfo) {
        return lendInfos[_deckLpId];
    }
}