// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IDeckMaster.sol";
import "./interfaces/BundlesInterface.sol";

contract DeckMaster is ERC721Enumerable, ERC721Holder, Ownable, IDeckMaster {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedBundles;
    mapping(uint256 => ServiceFee) private serviceFees;
    mapping(address => uint256) private linkServiceFees;
    mapping(address => uint256) private depositLimitations;
    mapping(address => uint256) private lockedTokenAmount;
    mapping(uint256 => DeckLPInfo) private deckLpInfos;
    mapping(uint256 => LendInfo) private lendInfos;
    mapping(address => BuyBackFee) private buybackFees;
    mapping(address => mapping(uint256 => uint256)) public claimableAmount;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public baseToken;
    uint256 private serviceFeeId;
    uint256 private deckLpId;
    uint256 public collectionAmountForBundle = 50;

    uint16 public BASE_POINT = 1000;

    modifier onlyAllowedToken(address _token) {
        require (allowedTokens.contains(_token), "not acceptable payment token address");
        _;
    }

    constructor (address _baseToken) ERC721("DeckLp", "DeckLP") {
        require (_baseToken != address(0), "zero base token address");
        baseToken = _baseToken;
        serviceFeeId = 1;
        deckLpId = 1;
    }

    /// @inheritdoc IDeckMaster
    function setCollectionAmountForBundle(uint256 _amount) external onlyOwner override {
        require (_amount > 0, "invalid amount");
        collectionAmountForBundle = _amount;
    }
    
    /// @inheritdoc IDeckMaster
    function setAcceptableERC20(address _token, bool _accept) external onlyOwner override {
        require (_token != address(0), "zero address");
        require (
            (_accept && !allowedTokens.contains(_token)) ||
            (!_accept && allowedTokens.contains(_token)),
            "Already set"
        );

        if (_accept) { allowedTokens.add(_token); }
        else { allowedTokens.remove(_token); }
        
        emit AcceptableERC20Set(_token, _accept);
    }

    /// @inheritdoc IDeckMaster
    function getAllowedTokens() external view override returns (address[] memory) {
        return allowedTokens.values();
    }

    /// @inheritdoc IDeckMaster
    function getAllowedCollections() external view override returns (address[] memory) {
        return allowedCollections.values();
    }

    /// @inheritdoc IDeckMaster
    function getAllowedBundles() external view override returns (address[] memory) {
        return allowedBundles.values();
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableCollections(address[] memory _collections, bool _accept) external onlyOwner override {
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
        emit AcceptableCollectionsSet(_collections, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableBundle(address _bundle, bool _accept) external onlyOwner override {
        require (_bundle != address(0), "zero address");
        require (
            (_accept && !allowedBundles.contains(_bundle)) ||
            (!_accept && allowedBundles.contains(_bundle)),
            "Already set"
        );
        if (_accept) { allowedBundles.add(_bundle); }
        else { allowedBundles.remove(_bundle); }
        emit AcceptableBundleSet(_bundle, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external onlyOwner onlyAllowedToken(_paymentToken) override {
        require (_paymentToken != address(0), "zero payment token address");
        serviceFees[serviceFeeId ++] = ServiceFee(_paymentToken, _feeAmount, _feeName, _feeFlag, _burnPercent);
        emit ServiceFeeSet(_paymentToken, _feeAmount, _feeFlag, _feeName, _burnPercent);
    }

    /// @inheritdoc IDeckMaster
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _collectionAddress
    ) external onlyOwner override {
        require (_serviceFeeId != 0 && _serviceFeeId < serviceFeeId, "invalid serviceFeeId");
        require (
            _collectionAddress != address(0) && 
            (allowedCollections.contains(_collectionAddress) || allowedBundles.contains(_collectionAddress)), 
            "not acceptable collection address"
        );
        require (linkServiceFees[_collectionAddress] == 0, "already linked to a fee");
        linkServiceFees[_collectionAddress] = _serviceFeeId;
        emit ServiceFeeLinked(_serviceFeeId, _collectionAddress);
    }

    /// @inheritdoc IDeckMaster
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external onlyOwner override {
        require (
            _collectionAddress != address(0) && 
            (allowedCollections.contains(_collectionAddress) || allowedBundles.contains(_collectionAddress)),
            "invalid collection address"
        );
        depositLimitations[_collectionAddress] = _depositLimit;
        emit DepositFlagSet(_collectionAddress, _depositLimit);
    }

    /// @inheritdoc IDeckMaster
    function depositCollections(
        address _collectionAddress,
        uint256[] memory _tokenIds
    ) external override {
        address sender = msg.sender;
        uint256 length = _tokenIds.length;
        require (sender != address(0), "zero caller address");
        require (length > 0, "dismatched length");

        DeckLPInfo storage deckLpInfo = deckLpInfos[deckLpId];
        require (allowedCollections.contains(_collectionAddress), "Not acceptable collection address");
        require (depositLimitations[_collectionAddress] >= length, "exceeds to max deposit limit");
            depositLimitations[_collectionAddress] -= length;

        for (uint256 i = 0; i < length; i ++) {
            uint256 tokenId = _tokenIds[i];
            require (IERC721(_collectionAddress).ownerOf(tokenId) == sender, "not Collection owner");
            
            deckLpInfo.collectionAddresses.push(_collectionAddress);
            deckLpInfo.tokenIds.push(tokenId);
            IERC721(_collectionAddress).transferFrom(sender, address(this), tokenId);
        }
        
        emit CollectionsDeposited(_collectionAddress, _tokenIds, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function depositBundle(address _bundleAddress, uint256 _tokenId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (allowedBundles.contains(_bundleAddress), "Not acceptable bundle address");
        require (IERC721(_bundleAddress).ownerOf(_tokenId) == sender, "not Collection owner");
        require (depositLimitations[_bundleAddress] > 0, "exceeds to max deposit limit");

        (,,address[] memory collections,) = BundlesInterface(_bundleAddress).getBundle(_tokenId);
        require (collections.length == collectionAmountForBundle, "Bundle should have certain collections");

        depositLimitations[_bundleAddress] -= 1;
        DeckLPInfo storage deckLpInfo = deckLpInfos[deckLpId];
        deckLpInfo.collectionAddresses.push(_bundleAddress);
        deckLpInfo.tokenIds.push(_tokenId);
        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);
        
        emit BundleDeposited(_bundleAddress, _tokenId, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function withdrawCollections(
        uint256 _deckLpId
    ) external override {
        address sender = msg.sender;
        DeckLPInfo storage deck = deckLpInfos[_deckLpId];
        require (sender != address(0), "zero caller addres");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) == sender, "not deckLp owner");
        require (!deck.lendDeckLp, "receipt deckLp");
        require (!deck.listedLend && !deck.lend, "related to lend");
        
        for (uint256 i = 0; i < deck.collectionAddresses.length; i ++) {
            address collectionAddress = deck.collectionAddresses[i];
            uint256 tokenId = deck.tokenIds[i];
            IERC721(collectionAddress).transferFrom(address(this), sender, tokenId);
        }
        delete deck.collectionAddresses;
        delete deck.tokenIds;
        
        _burn(_deckLpId);
        emit Withdraw(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function lend(
        address _paymentToken,
        uint256 _deckLpId,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        uint256 _duration,
        bool _prepay,
        WinningDistribution memory _winDist
    ) external onlyAllowedToken(_paymentToken) override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (_duration > 0, "invalid lend duration");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) == sender && !deckLpInfos[_deckLpId].lend, "not deckLp owner");
        require (
            !deckLpInfos[_deckLpId].lendDeckLp &&
            !deckLpInfos[_deckLpId].listedLend && 
            !deckLpInfos[_deckLpId].lend,
            "already listed or lent"
        );
        require ((!_prepay && _prepayAmount == 0) || (_prepay && _prepayAmount > 0), "invalid prepay amount");
        require (_winDist.borrowerRate + _winDist.lenderRate + _winDist.burnRate == BASE_POINT, "invalid winning distribution");

        deckLpInfos[_deckLpId].listedLend = true;
        lendInfos[_deckLpId] = LendInfo(
            sender, 
            address(0), 
            _paymentToken, 
            _dailyInterest, 
            _prepayAmount, 
            0, 
            _duration, 
            _winDist,
            _prepay
        );
        emit Lend(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function borrow(
        uint256 _deckLpId
    ) external override {
        address sender = msg.sender;
        DeckLPInfo storage deckLpInfo = deckLpInfos[_deckLpId];
        LendInfo storage lendInfo = lendInfos[_deckLpId];
        require (sender != address(0), "zero caller address");
        require (!deckLpInfo.lendDeckLp, "This is receipt deckLp");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) != sender, "deckLp owner");
        require (deckLpInfo.listedLend && !deckLpInfo.lend, "not listed");

        _takeServiceFee(_deckLpId);
        _takeLendOffer(_deckLpId);

        deckLpInfo.listedLend = false;
        deckLpInfo.lend = true;
        lendInfo.borrower = sender;
        lendInfo.borrowedTimestamp = block.timestamp;

        deckLpInfos[deckLpId].lendDeckLp = true;
        deckLpInfos[deckLpId].borrowedDeckLpId = _deckLpId;

        emit Borrow(sender, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function winningCalculation(
        uint256 _deckLpId,
        uint256 _totalWinnings,
        uint256[] memory _gameIds
    ) external onlyOwner override {
        require (!deckLpInfos[_deckLpId].lendDeckLp, "this deckLp is receipt deckLp");
        if (!deckLpInfos[_deckLpId].lend) {
            address deckOwner = ownerOf(_deckLpId);
            claimableAmount[deckOwner][_deckLpId] += _totalWinnings;
        } else {
            LendInfo memory lendInfo = lendInfos[_deckLpId];
            WinningDistribution memory winDist = lendInfo.winDistributionRate;
            uint256 lenderAmount = _totalWinnings * winDist.lenderRate / BASE_POINT;
            uint256 borrowerAmount = _totalWinnings * winDist.borrowerRate / BASE_POINT;
            uint256 burnRate = _totalWinnings - lenderAmount - borrowerAmount;
            claimableAmount[lendInfo.lender][_deckLpId] += lenderAmount;
            claimableAmount[lendInfo.borrower][_deckLpId] += borrowerAmount;
            IERC20(baseToken).safeTransfer(DEAD, burnRate);
        }

        emit WinningRewardsSet(_deckLpId, _gameIds, _totalWinnings);
    }

    /// @inheritdoc IDeckMaster
    function claimWinnings(uint256 _deckLpId) external override {
        address sender = msg.sender;
        require (!deckLpInfos[_deckLpId].lendDeckLp, "this deckLp is receipt deckLp");
        require (claimableAmount[sender][_deckLpId] > 0, "no claimable winning rewards");
        claimableAmount[sender][_deckLpId] = 0;
        IERC20(baseToken).safeTransfer(sender, claimableAmount[sender][_deckLpId]);
        emit WinningRewardsClaimed(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function claimInterest(uint256 _deckLpId) external override {
        address sender = msg.sender;
        DeckLPInfo storage deckLpInfo = deckLpInfos[_deckLpId];
        require (!deckLpInfo.lendDeckLp, "this deckLp is receipt deckLp");
        require (deckLpInfo.lend, "this deck is not lent deckLp");
        LendInfo memory lendInfo = lendInfos[_deckLpId];
        require (lendInfo.lender == sender, "not lender");
        require (block.timestamp > lendInfo.borrowedTimestamp + lendInfo.borrowDuration, "can not claim interest in lend duration");
        uint256 interestAmount = lendInfo.dailyInterest * (lendInfo.borrowDuration);
        lockedTokenAmount[lendInfo.paymentToken] -= interestAmount;
        deckLpInfo.lend = deckLpInfo.listedLend = false;
        IERC20(lendInfo.paymentToken).safeTransfer(sender, interestAmount);
        _burn(_deckLpId);

        emit InterestClaimed(sender, interestAmount);
    }

    /// @inheritdoc IDeckMaster
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external override {
        buybackFees[_token].active = _turningStatus;
    }

    /// @inheritdoc IDeckMaster
    function setBuybackFee(
        address _token,
        uint16 _buybackFee
    ) external override {
        buybackFees[_token].feeRate = _buybackFee;
    }

    /// @inheritdoc IDeckMaster
    function getReceiptDeckLpInfo(
        uint256 _deckLpId
    ) external view override returns (
        uint256 duration, 
        uint256 prepay, 
        uint256 interest, 
        WinningDistribution memory winDistribution
    ) {
        require (_exists(_deckLpId), "not exist deckLp id");
        DeckLPInfo memory deckLpInfo = deckLpInfos[_deckLpId];
        require (deckLpInfo.lendDeckLp, "this deckLp is not receipt deckLp");
        LendInfo memory lendInfo = lendInfos[deckLpInfo.borrowedDeckLpId];
        return (lendInfo.borrowDuration, lendInfo.prepayAmount, lendInfo.dailyInterest, lendInfo.winDistributionRate);
    }

    /// @inheritdoc IDeckMaster
    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view override returns (address collectionAddress, uint256[] memory tokenIds) {
        require (_exists(_deckLpId), "not exist deckLp id");
        DeckLPInfo memory deckLpInfo = deckLpInfos[_deckLpId];
        require (!deckLpInfo.lendDeckLp, "this deckLp is receipt deckLp");
        return (deckLpInfo.collectionAddresses[0], deckLpInfo.tokenIds);
    }

    /// @inheritdoc IDeckMaster
    function getAllDeckCount() external view override returns (uint256) {
        return deckLpId - 1;
    }

    /// @inheritdoc IDeckMaster
    function getCollectionAddress() external view override returns (address[] memory) {
        return allowedCollections.values();
    }

    /// @inheritdoc IDeckMaster
    function getBundlesAddress() external view override returns (address[] memory) {
        return allowedBundles.values();
    }

    /// @inheritdoc IDeckMaster
    function getServiceFeeInfo(uint256 _serviceFeedId) external view override returns (ServiceFee memory) {
        return serviceFees[_serviceFeedId];
    }

    /// @inheritdoc IDeckMaster
    function getLockedERC20(address _token) external view override returns (uint256) {
        return lockedTokenAmount[_token];
    }

    function _mintDeckLp(address _recipient) internal {
        _safeMint(_recipient, deckLpId ++);
    }

    function _getServiceFeeId(uint256 _deckLpId) internal view returns (uint256) {
        DeckLPInfo memory deckLpInfo = deckLpInfos[_deckLpId];
        address collectionAddress = deckLpInfo.collectionAddresses[0];
        return linkServiceFees[collectionAddress];
    }

    function _takeServiceFee(uint256 _deckLpId) internal {
        address sender = msg.sender;
        uint256 collectionServiceFeeId = _getServiceFeeId(_deckLpId);
        if (collectionServiceFeeId > 0) {
            ServiceFee memory serviceFee = serviceFees[collectionServiceFeeId];
            IERC20 paymentToken = IERC20(serviceFee.paymentToken);
            uint256 feeAmount = serviceFee.feeAmount;
            require (
                !serviceFee.active ||
                paymentToken.balanceOf(sender) >= feeAmount, 
                "Not enough balance for serviceFee"
            );
            paymentToken.safeTransferFrom(sender, address(this), feeAmount);
            uint256 burnAmount = feeAmount * serviceFee.burnPercent / BASE_POINT;
            paymentToken.safeTransfer(DEAD, burnAmount);

            // TODO buyback
        }
    }

    function _takeLendOffer(uint256 _deckLpId) internal {
        address sender = msg.sender;
        LendInfo memory lendInfo = lendInfos[_deckLpId];
        IERC20 paymentToken = IERC20(lendInfo.paymentToken);
        if (lendInfo.prepay) {
            uint256 prepayAmount = lendInfo.prepayAmount;
            require (paymentToken.balanceOf(sender) >= prepayAmount, "Not enough balance for prepay");
            paymentToken.safeTransferFrom(sender, address(this), prepayAmount);
            paymentToken.safeTransfer(lendInfo.lender, prepayAmount);
        }

        uint256 dailyInterest = lendInfo.dailyInterest;
        uint256 duration = lendInfo.borrowDuration / 1 days;
        uint256 requiredInterest = dailyInterest * duration;
        require (paymentToken.balanceOf(sender) >= requiredInterest, "Not enough balance for interest");
        paymentToken.safeTransferFrom(sender, address(this), requiredInterest);
        lockedTokenAmount[address(paymentToken)] += requiredInterest;
    }
}