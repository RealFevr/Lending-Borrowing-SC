// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/IDeckMaster.sol";
import "./interfaces/BundlesInterface.sol";

contract DeckMaster is ERC721Enumerable, ERC721Holder, Ownable, IDeckMaster {
    mapping(address => bool) public isAllowedTokens;
    mapping(address => bool) public isAllowedNFTs;
    mapping(address => bool) public isAllowedBundles;
    mapping(uint256 => ServiceFee) private serviceFees;
    mapping(address => uint256) private linkServiceFees;
    mapping(address => uint256) private depositLimitations;
    mapping(uint256 => DeckLPInfo) private deckLpInfos;
    mapping(uint256 => LendInfo) private lendInfos;

    uint256 private serviceFeeId;
    uint256 private deckLpId;

    uint16 public BASE_POINT = 1000;

    constructor () ERC721("DeckLp", "DeckLP") {
        serviceFeeId = 1;
        deckLpId = 1;
    }
    
    /// @inheritdoc IDeckMaster
    function setAcceptableERC20(address _token, bool _accept) external onlyOwner override {
        require (_token != address(0), "zero address");
        isAllowedTokens[_token] = _accept;
        emit AcceptableERC20Set(_token, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableOpener(address _opener, bool _accept) external onlyOwner override {
        require (_opener != address(0), "zero address");
        isAllowedNFTs[_opener] = _accept;
        emit AcceptableOpenerSet(_opener, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableBundle(address _bundle, bool _accept) external onlyOwner override {
        require (_bundle != address(0), "zero address");
        isAllowedBundles[_bundle] = _accept;
        emit AcceptableBundleSet(_bundle, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external onlyOwner override {
        require (_paymentToken != address(0), "zero payment token address");
        require (isAllowedTokens[_paymentToken], "not acceptable payment token address");
        serviceFees[serviceFeeId ++] = ServiceFee(_paymentToken, _feeAmount, _feeName, _feeFlag, _burnPercent);
        emit ServiceFeeSet(_paymentToken, _feeAmount, _feeFlag, _feeName, _burnPercent);
    }

    /// @inheritdoc IDeckMaster
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _nftAddress
    ) external onlyOwner override {
        require (_serviceFeeId != 0 && _serviceFeeId < serviceFeeId, "invalid serviceFeeId");
        require (_nftAddress != address(0) && (isAllowedNFTs[_nftAddress] || isAllowedBundles[_nftAddress]), "not acceptable nft address");
        require (linkServiceFees[_nftAddress] == 0, "already linked to a fee");
        linkServiceFees[_nftAddress] = _serviceFeeId;
        emit ServiceFeeLinked(_serviceFeeId, _nftAddress);
    }

    /// @inheritdoc IDeckMaster
    function setDepositFlag(
        address _nftAddress,
        uint256 _depositLimit
    ) external onlyOwner override {
        require (_nftAddress != address(0) && (isAllowedNFTs[_nftAddress] || isAllowedBundles[_nftAddress]), "invalid nft address");
        depositLimitations[_nftAddress] = _depositLimit;
        emit DepositFlagSet(_nftAddress, _depositLimit);
    }

    /// @inheritdoc IDeckMaster
    function depositNFTs(
        address _nftAddress,
        uint256 _tokenId
    ) external override {
        address sender = msg.sender;
        bool isNFT = isAllowedNFTs[_nftAddress];
        bool isBundle = isAllowedBundles[_nftAddress];
        require (sender != address(0), "zero caller address");
        require (isNFT || isBundle, "not acceptable nft address");
        require (IERC721(_nftAddress).ownerOf(_tokenId) == sender, "not NFT owner");

        if (isNFT) {
            require (depositLimitations[_nftAddress] > 0, "exceeds to max deposit limit");
            depositLimitations[_nftAddress] --;
        } else {    // if bundle
            (,,address[] memory nfts,) = BundlesInterface(_nftAddress).getBundle(_tokenId);
            for (uint256 i = 0; i < nfts.length; i ++) {
                address nft = nfts[i];
                require (depositLimitations[nft] > 0, "exceeds to max deposit limit");
                depositLimitations[nft] --;
            }
        }
        deckLpInfos[deckLpId] = DeckLPInfo(_nftAddress, _tokenId, false, false, false);
        IERC721(_nftAddress).transferFrom(sender, address(this), _tokenId);
        emit Deposit(_nftAddress, _tokenId, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function withdrawNFTs(
        uint256 _deckLpId
    ) external override {
        address sender = msg.sender;
        DeckLPInfo storage deck = deckLpInfos[_deckLpId];
        require (sender != address(0), "zero caller addres");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) == sender, "not deckLp owner");
        require (!deck.lendDeckLp && !deck.lend, "related to lend");
        
        IERC721(deck.nftAddress).transferFrom(address(this), sender, deck.tokenId);
        deck.nftAddress = address(0); deck.tokenId = 0; deck.listedLend = deck.lend = deck.lendDeckLp = false;
        _burn(_deckLpId);
        emit Withdraw(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function lend(
        address _paymentToken,
        uint256 _deckLpId,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        bool _prepay,
        WinningDistribution memory _winDist
    ) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (isAllowedTokens[_paymentToken], "not acceptable payment token");
        require (
            _exists(_deckLpId) && ownerOf(_deckLpId) == sender &&
            !deckLpInfos[_deckLpId].lendDeckLp && !deckLpInfos[_deckLpId].lend,
            "invalid deckLp id"
        );
        require ((!_prepay && _prepayAmount == 0) || (_prepay && _prepayAmount > 0), "invalid prepay amount");
        require (_winDist.borrowerRate + _winDist.lenderRate + _winDist.burnRate == BASE_POINT, "invalid winning distribution");

        deckLpInfos[_deckLpId].listedLend = true;
        lendInfos[_deckLpId] = LendInfo(sender, address(0), _paymentToken, _deckLpId, _dailyInterest, _prepayAmount, 0, 0, _prepay);
        emit Lend(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function borrow(
        uint256 _deckLpId
    ) external override {

    }

    /// @inheritdoc IDeckMaster
    function winningCalculation(
        address _lender,
        address _borrower,
        uint256 _deckLpId,
        uint256[] memory _gameIds
    ) external override {

    }

    /// @inheritdoc IDeckMaster
    function claimWinnings(uint256 _gameIds) external override {

    }

    /// @inheritdoc IDeckMaster
    function claimInterest(uint256 _deckLpId) external override {

    }

    /// @inheritdoc IDeckMaster
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external override {

    }

    /// @inheritdoc IDeckMaster
    function setBuybackFee(
        address _token,
        uint256 _buybackFee
    ) external override {

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
        return (0, 0, 0, WinningDistribution(0, 0, 0));
    }

    /// @inheritdoc IDeckMaster
    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view override returns (address nftAddress, uint256[] memory tokenIds) {
        return (address(0), new uint256[](0));
    }

    /// @inheritdoc IDeckMaster
    function getAllDeckCount() external view override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IDeckMaster
    function getOpenerAddress() external view override returns (address[] memory) {
        return new address[](0);
    }

    /// @inheritdoc IDeckMaster
    function getBundlesAddress() external view override returns (address[] memory) {
        return new address[](0);
    }

    /// @inheritdoc IDeckMaster
    function getServiceFeeInfo(uint256 _serviceFeedId) external view override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IDeckMaster
    function getLockedERC20(address _token) external view override returns (uint256) {
        return 0;
    }

    function _mintDeckLp(address _recipient) internal {
        _safeMint(_recipient, deckLpId ++);
    }
}