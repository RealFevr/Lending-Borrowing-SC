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
import "./interfaces/ICollectionManager.sol";
import "./interfaces/IServiceManager.sol";
import "./interfaces/BundlesInterface.sol";
import "./interfaces/IUniswapRouter02.sol";

contract DeckMaster is ERC721Enumerable, ERC721Holder, Ownable, IDeckMaster {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    /// The information of ServiceFee by serviceFeeId.
    mapping(uint256 => ServiceFee) private serviceFees;

    /// @dev ServiceFee for accepted collection.
    mapping(address => uint256) private linkServiceFees;
    
    /// @dev Locked token amount for certain token.
    mapping(address => uint256) private lockedTokenAmount;

    /// @dev The fee infomation for buyback.
    mapping(address => BuyBackFee) private buybackFees;

    /// @dev The claimable $Fevr token amount comes from winning games.
    mapping(address => mapping(uint256 => uint256)) public claimableAmount;

    /// The address of collectionManager contract.
    ICollectionManager public collectionManager;

    /// @dev The address of serviceManager contract.
    IServiceManager public serviceManager;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @dev The address of $Fevr token.
    address public baseToken;

    /// @dev The address of uniswap router.
    address public dexRouter;

    /// @dev total DeckLP count that exist.
    uint256 private totalDeckLPCnt;

    /// @dev The id of ServiceFee.
    uint256 private serviceFeeId;

    /// @dev The id of deckLpId. deckLpId = tokenId.
    uint256 private deckLpId;
    

    uint16 public BASE_POINT = 1000;

    modifier onlyAllowedToken(address _token) {
        require (collectionManager.isAllowedToken(_token), "not acceptable payment token address");
        _;
    }

    constructor (
        address _baseToken,
        address _collectionManager,
        address _serviceManager,
        address _dexRouter
    ) ERC721("DeckLp", "DeckLP") {
        require (_baseToken != address(0), "zero base token address");
        require (_collectionManager != address(0), "zero collection manager address");
        require (_dexRouter != address(0), "zero dex router address");

        dexRouter = _dexRouter;
        collectionManager = ICollectionManager(_collectionManager);
        serviceManager = IServiceManager(_serviceManager);
        baseToken = _baseToken;
        serviceFeeId = 1;
        deckLpId = 1;
    }

    /// @inheritdoc IDeckMaster
    function setCollectionAmountForBundle(uint256 _amount) external onlyOwner override {
        require (_amount > 0, "invalid amount");
        collectionManager.setCollectionAmountForBundle(_amount);
    }
    
    /// @inheritdoc IDeckMaster
    function setAcceptableERC20(address _token, bool _accept) external onlyOwner override {
        require (_token != address(0), "zero address");
        collectionManager.setAcceptableERC20(_token, _accept);
        emit AcceptableERC20Set(_token, _accept);
    }

    /// @inheritdoc IDeckMaster
    function getAllowedTokens() external view override returns (address[] memory) {
        return collectionManager.getAllowedTokens();
    }

    /// @inheritdoc IDeckMaster
    function getAllowedCollections() external view override returns (address[] memory) {
        return collectionManager.getAllowedCollections();
    }

    /// @inheritdoc IDeckMaster
    function getAllowedBundles() external view override returns (address[] memory) {
        return collectionManager.getAllowedBundles();
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableCollections(address[] memory _collections, bool _accept) external onlyOwner override {
        collectionManager.setAcceptableCollections(_collections, _accept);
        emit AcceptableCollectionsSet(_collections, _accept);
    }

    /// @inheritdoc IDeckMaster
    function setAcceptableBundle(address _bundle, bool _accept) external onlyOwner override {
        require (_bundle != address(0), "zero address");
        collectionManager.setAcceptableBundle(_bundle, _accept);
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
        collectionManager.checkAllowedCollection(_collectionAddress);
        require (linkServiceFees[_collectionAddress] == 0, "already linked to a fee");
        linkServiceFees[_collectionAddress] = _serviceFeeId;
        emit ServiceFeeLinked(_serviceFeeId, _collectionAddress);
    }

    /// @inheritdoc IDeckMaster
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external onlyOwner override {
        collectionManager.setDepositFlag(_collectionAddress, _depositLimit);
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

        collectionManager.checkCollectionAvailableForDeposit(_collectionAddress, _tokenIds);

        for (uint256 i = 0; i < length; i ++) {
            uint256 tokenId = _tokenIds[i];
            require (IERC721(_collectionAddress).ownerOf(tokenId) == sender, "not Collection owner");
            IERC721(_collectionAddress).transferFrom(sender, address(this), tokenId);
        }
        serviceManager.addDepositedCollections(deckLpId, _collectionAddress, _tokenIds);
        
        emit CollectionsDeposited(_collectionAddress, _tokenIds, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function depositBundle(address _bundleAddress, uint256 _tokenId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (IERC721(_bundleAddress).ownerOf(_tokenId) == sender, "not Collection owner");
        collectionManager.checkBundleAvailableForDeposit(_bundleAddress, _tokenId);
        
        serviceManager.addDepositedBundle(deckLpId, _bundleAddress, _tokenId);
        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);
        
        emit BundleDeposited(_bundleAddress, _tokenId, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function withdrawCollections(
        uint256 _deckLpId
    ) external override {
        address sender = msg.sender;
        // DeckLPInfo storage deck = deckLpInfos[_deckLpId];
        require (sender != address(0), "zero caller addres");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) == sender, "not deckLp owner");
        (
            address[] memory collectionAddresses,
            uint256[] memory tokenIds
        ) = serviceManager.removeWithdrawedCollections(_deckLpId);
        
        for (uint256 i = 0; i < collectionAddresses.length; i ++) {
            address collectionAddress = collectionAddresses[i];
            uint256 tokenId = tokenIds[i];
            IERC721(collectionAddress).transferFrom(address(this), sender, tokenId);
        }
        
        _burn(_deckLpId); totalDeckLPCnt --;
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
        require (_exists(_deckLpId) && ownerOf(_deckLpId) == sender, "not deckLp owner");
        require ((!_prepay && _prepayAmount == 0) || (_prepay && _prepayAmount > 0), "invalid prepay amount");
        require (_winDist.borrowerRate + _winDist.lenderRate + _winDist.burnRate == BASE_POINT, "invalid winning distribution");

        serviceManager.listDeckLpLend(
            _deckLpId,
            sender, 
            _paymentToken, 
            _dailyInterest, 
            _prepayAmount, 
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
        require (sender != address(0), "zero caller address");
        require (_exists(_deckLpId) && ownerOf(_deckLpId) != sender, "deckLp owner");

        _takeServiceFee(_deckLpId);
        _takeLendOffer(_deckLpId);

        serviceManager.borrowDeckLp(sender, block.timestamp, _deckLpId, deckLpId);

        emit Borrow(sender, deckLpId);
        _mintDeckLp(sender);
    }

    /// @inheritdoc IDeckMaster
    function winningCalculation(
        uint256 _deckLpId,
        uint256 _totalWinnings,
        uint256[] memory _gameIds
    ) external onlyOwner override {
        (
            address lender,
            address borrower,
            WinningDistribution memory winDist,
            bool isLendDeckLp,
            bool isLend
        ) = serviceManager.getDeckLendInfo(_deckLpId);

        require (!isLendDeckLp, "this deckLp is receipt deckLp");
        if (!isLend) {
            address deckOwner = ownerOf(_deckLpId);
            claimableAmount[deckOwner][_deckLpId] += _totalWinnings;
        } else {
            uint256 lenderAmount = _totalWinnings * winDist.lenderRate / BASE_POINT;
            uint256 borrowerAmount = _totalWinnings * winDist.borrowerRate / BASE_POINT;
            uint256 burnRate = _totalWinnings - lenderAmount - borrowerAmount;
            claimableAmount[lender][_deckLpId] += lenderAmount;
            claimableAmount[borrower][_deckLpId] += borrowerAmount;
            IERC20(baseToken).safeTransfer(DEAD, burnRate);
        }

        emit WinningRewardsSet(_deckLpId, _gameIds, _totalWinnings);
    }

    /// @inheritdoc IDeckMaster
    function claimWinnings(uint256 _deckLpId) external override {
        address sender = msg.sender;
        require (!serviceManager.isLendDeckLp(_deckLpId), "this deckLp is receipt deckLp");
        require (claimableAmount[sender][_deckLpId] > 0, "no claimable winning rewards");
        claimableAmount[sender][_deckLpId] = 0;
        IERC20(baseToken).safeTransfer(sender, claimableAmount[sender][_deckLpId]);
        emit WinningRewardsClaimed(sender, _deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function claimInterest(uint256 _deckLpId) external override {
        address sender = msg.sender;
        (
            uint256 interestAmount,
            address paymentToken
        ) = serviceManager.checkDeckLpAvailableForClaimInterest(sender, _deckLpId);

        lockedTokenAmount[paymentToken] -= interestAmount;
        IERC20(paymentToken).safeTransfer(sender, interestAmount);
        _burn(_deckLpId); totalDeckLPCnt --;

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
        return serviceManager.getReceiptDeckLpInfo(_deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view override returns (address collectionAddress, uint256[] memory tokenIds) {
        require (_exists(_deckLpId), "not exist deckLp id");
        return serviceManager.getDeckLpInfo(_deckLpId);
    }

    /// @inheritdoc IDeckMaster
    function getAllDeckCount() external view override returns (uint256) {
        return deckLpId - 1;
    }

    /// @inheritdoc IDeckMaster
    function getCollectionAddress() external view override returns (address[] memory) {
        return collectionManager.getCollectionAddress();
    }

    /// @inheritdoc IDeckMaster
    function getBundlesAddress() external view override returns (address[] memory) {
        return collectionManager.getBundlesAddress();
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
        totalDeckLPCnt ++;
        _safeMint(_recipient, deckLpId ++);
    }

    function _getServiceFeeId(uint256 _deckLpId) internal view returns (uint256) {
        (address collectionAddress, ) = serviceManager.getDeckLpInfo(_deckLpId);
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

            _buyBack(address(paymentToken), feeAmount - burnAmount);
        }
    }

    function _buyBack(address _token, uint256 _amount) internal {
        if (!buybackFees[_token].active || _amount == 0) return;
        
        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = baseToken;

        uint256 beforeBal = IERC20(baseToken).balanceOf(address(this));
        IUniswapV2Router02(dexRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount, 
            0, 
            path, 
            address(this), 
            block.timestamp
        );
        uint256 afterBal = IERC20(baseToken).balanceOf(address(this));
        uint256 swappedAmount = afterBal - beforeBal;

        uint16 feeRate = buybackFees[_token].feeRate;
        uint256 feeAmount = swappedAmount * feeRate / BASE_POINT;
        uint256 burnAmount = swappedAmount - feeAmount;
        if (burnAmount == 0) return;
        IERC20(baseToken).safeTransfer(DEAD, burnAmount);
    }

    function _takeLendOffer(uint256 _deckLpId) internal {
        address sender = msg.sender;
        
        LendInfo memory lendInfo = serviceManager.getLendInfo(_deckLpId);
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