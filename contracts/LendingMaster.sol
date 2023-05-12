// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/ILendingMaster.sol";
import "./interfaces/BundleInterface.sol";
import "./interfaces/IUniswapRouter02.sol";

contract LendingMaster is ERC721Holder, Ownable, ILendingMaster {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedNLBundles;

    /// @notice Deposited deckIds totally.
    EnumerableSet.UintSet private totalDepositedIds;

    /// @notice deckIds listed for lending totally.
    EnumerableSet.UintSet private totalListedIds;

    /// @notice deposited deckIds of each user.
    mapping(address => EnumerableSet.UintSet) private depositedIdsPerUser;

    /// @notice deckIds listed for lending of each user.
    mapping(address => EnumerableSet.UintSet) private listedIdsPerUser;

    /// @notice borrowed deckIds of each user.
    mapping(address => EnumerableSet.UintSet) private borrowedIdsPerUser;

    /// @dev The fee infomation for buyback.
    mapping(address => BuyBackFee) private buybackFees;

    /// @dev Lending req for each deckId.
    mapping(uint256 => LendingReq) private lendingReqsPerDeck;

    /// The information of ServiceFee by serviceFeeId.
    mapping(uint256 => ServiceFee) private serviceFees;

    /// The information of each deck.
    mapping(uint256 => DeckInfo) private deckInfo;

    /// Collection information per deckId
    mapping(uint256 => CollectionInfo) private collectionInfoPerDeck;

    /// The max amount of collection that can be deposited.
    mapping(address => uint256) public depositLimitations;

    /// @dev ServiceFee for accepted collection.
    mapping(address => uint256) private linkServiceFees;

    /// @dev Locked token amount for certain token.
    mapping(address => uint256) private lockedTokenAmount;

    /// @dev Locked payment token amount by each deckId.
    mapping(uint256 => uint256) private lockedInterestsPerDeck;

    /// @dev The address of uniswap router.
    address public dexRouter;

    /// @dev The address of fevr token.
    address public fevrToken;

    /// @dev The id of ServiceFee.
    uint256 public serviceFeeId;

    uint256 private deckId;

    /// @dev Max collection amount that bundle can contain.
    uint256 public maxAmountForBundle;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint16 public FIXED_POINT = 1000;

    constructor(address _fevrToken, address _dexRouter) {
        require(_fevrToken != address(0), "zero fevr token address");
        require(_dexRouter != address(0), "zero dex router address");
        fevrToken = _fevrToken;
        dexRouter = _dexRouter;
        serviceFeeId = 1;
        deckId = 1;
    }

    /// @inheritdoc ILendingMaster
    function setAcceptableERC20(
        address[] memory _tokens,
        bool _accept
    ) external override onlyOwner {
        uint256 length = _tokens.length;
        require(length > 0, "invalid length array");
        for (uint256 i = 0; i < length; i++) {
            address token = _tokens[i];
            if (_accept) {
                require(!allowedTokens.contains(token), "already added");
                allowedTokens.add(token);
            } else {
                require(allowedTokens.contains(token), "already removed");
                allowedTokens.remove(token);
            }
        }
    }

    /// @inheritdoc ILendingMaster
    function setApprovedCollections(
        address[] memory _collections,
        bool _accept
    ) external override onlyOwner {
        uint256 length = _collections.length;
        require(length > 0, "invalid length array");
        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            if (_accept) {
                require(
                    !allowedCollections.contains(collection),
                    "already added"
                );
                allowedCollections.add(collection);
            } else {
                require(
                    allowedCollections.contains(collection),
                    "already removed"
                );
                allowedCollections.remove(collection);
            }
        }
    }

    /// @inheritdoc ILendingMaster
    function setNLBundles(
        address[] memory _nlBundles,
        bool _accept
    ) external override onlyOwner {
        uint256 length = _nlBundles.length;
        require(length > 0, "invalid length array");
        for (uint256 i = 0; i < length; i++) {
            address bundle = _nlBundles[i];
            if (_accept) {
                require(!allowedNLBundles.contains(bundle), "already added");
                allowedNLBundles.add(bundle);
            } else {
                require(allowedNLBundles.contains(bundle), "already removed");
                allowedNLBundles.remove(bundle);
            }
        }
    }

    /// @inheritdoc ILendingMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external override onlyOwner {
        serviceFees[serviceFeeId++] = ServiceFee(
            _paymentToken,
            _feeAmount,
            _feeName,
            _feeFlag,
            _burnPercent
        );
    }

    /// @inheritdoc ILendingMaster
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _collectionAddress
    ) external override onlyOwner {
        require(
            _serviceFeeId != 0 && _serviceFeeId < serviceFeeId,
            "invalid serviceFeeId"
        );
        require(
            _collectionAddress != address(0) &&
                (allowedCollections.contains(_collectionAddress) ||
                    allowedNLBundles.contains(_collectionAddress)),
            "not acceptable collection address"
        );
        require(
            linkServiceFees[_collectionAddress] == 0,
            "already linked to a fee"
        );
        linkServiceFees[_collectionAddress] = _serviceFeeId;
    }

    /// @inheritdoc ILendingMaster
    function setMaxAmountForBundle(
        uint256 _newAmount
    ) external override onlyOwner {
        require(_newAmount > 0, "invalid maxAmountForBundle value");
        maxAmountForBundle = _newAmount;
    }

    /// @inheritdoc ILendingMaster
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external override onlyOwner {
        require(
            _collectionAddress != address(0) &&
                (allowedCollections.contains(_collectionAddress) ||
                    allowedNLBundles.contains(_collectionAddress)),
            "invalid collection address"
        );
        depositLimitations[_collectionAddress] = _depositLimit;
    }

    /// @inheritdoc ILendingMaster
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external override onlyOwner {
        require(allowedTokens.contains(_token), "token is not approved");
        buybackFees[_token].active = _turningStatus;
    }

    /// @inheritdoc ILendingMaster
    function setBuybackFee(
        address _token,
        uint16 _buybackFee
    ) external override onlyOwner {
        require(allowedTokens.contains(_token), "token is not approved");
        buybackFees[_token].feeRate = _buybackFee;
    }

    /// @inheritdoc ILendingMaster
    function depositNLBundle(
        address _bundleAddress,
        uint256 _tokenId
    ) external override {
        address sender = msg.sender;
        require(
            allowedNLBundles.contains(_bundleAddress),
            "not allowed bundle"
        );
        require(
            IERC721(_bundleAddress).ownerOf(_tokenId) == sender,
            "not bundle owner"
        );
        require(
            depositLimitations[_bundleAddress] > 0,
            "exceeds to max deposit limit"
        );

        (, , address[] memory collections, ) = BundlesInterface(_bundleAddress)
            .getBundle(_tokenId);
        require(
            maxAmountForBundle > collections.length,
            "exceeds to max deposit limit"
        );
        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);

        depositLimitations[_bundleAddress] -= 1;
        depositedIdsPerUser[sender].add(deckId);
        uint256[] memory deckIds = new uint256[](1);
        address[] memory depositedCollections = new address[](1);
        deckIds[0] = deckId;
        deckInfo[deckId] = DeckInfo(sender, address(0), 0, 0, deckIds);

        depositedCollections[0] = _bundleAddress;
        deckIds[0] = _tokenId;
        collectionInfoPerDeck[deckId] = CollectionInfo(
            depositedCollections,
            deckIds
        );

        depositedIdsPerUser[sender].add(deckId);
        totalDepositedIds.add(deckId++);
    }

    /// @inheritdoc ILendingMaster
    function depositLBundle(
        address[] memory _collections,
        uint256[] memory _tokenIds
    ) external override {
        address sender = msg.sender;
        uint256 length = _collections.length;
        require(length > 0, "invalid length array");
        require(length == _tokenIds.length, "mismatch length array");
        require(maxAmountForBundle > length, "exceeds to maxAmountForBundle");

        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            uint256 tokenId = _tokenIds[i];
            require(
                allowedCollections.contains(collection),
                "not allowed collection"
            );
            require(
                IERC721(collection).ownerOf(tokenId) == sender,
                "not collection owner"
            );
            require(
                depositLimitations[collection] > 0,
                "exceeds to max deposit limit"
            );
            depositLimitations[collection] -= 1;
            IERC721(collection).transferFrom(sender, address(this), tokenId);
        }

        depositedIdsPerUser[sender].add(deckId);
        uint256[] memory deckIds = new uint256[](1);
        deckIds[0] = deckId;
        deckInfo[deckId] = DeckInfo(sender, address(0), 0, 0, deckIds);
        collectionInfoPerDeck[deckId] = CollectionInfo(_collections, _tokenIds);
        depositedIdsPerUser[sender].add(deckId);
        totalDepositedIds.add(deckId++);
    }

    /// @inheritdoc ILendingMaster
    function makeLBundle(uint256[] memory _deckIds) external override {
        uint256 length = _deckIds.length;
        address sender = msg.sender;
        require(length > 0, "invalid length array");
        for (uint256 i = 0; i < length; i++) {
            uint256 _deckId = _deckIds[i];
            DeckInfo storage info = deckInfo[_deckId];
            require(
                depositedIdsPerUser[sender].contains(_deckId),
                "invalid deckId"
            );
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "borrowed deckId"
            );
            require(
                !listedIdsPerUser[sender].contains(_deckId),
                "listed for lend"
            );
            depositedIdsPerUser[sender].remove(_deckId);
            totalDepositedIds.remove(_deckId);
        }
        depositedIdsPerUser[sender].add(deckId);
        deckInfo[deckId] = DeckInfo(sender, address(0), 0, 0, _deckIds);
        totalDepositedIds.add(deckId++);
    }

    /// @inheritdoc ILendingMaster
    function lend(
        uint256[] memory _deckIds,
        LendingReq[] memory _lendingReqs
    ) external override {
        address sender = msg.sender;
        uint256 length = _deckIds.length;
        require(length > 0, "invalid length array");
        require(length == _lendingReqs.length, "mismatch length array");

        for (uint256 i = 0; i < length; i++) {
            uint256 _deckId = _deckIds[i];
            LendingReq memory req = _lendingReqs[i];
            require(
                depositedIdsPerUser[sender].contains(_deckId),
                "invalid deckId"
            );
            require(
                !listedIdsPerUser[sender].contains(_deckId),
                "already listed"
            );
            require(
                allowedTokens.contains(req.paymentToken),
                "not allowed paymentToken"
            );
            require(req.dailyInterest > 0, "invalid dailyInterest");
            require(req.maxDuration > 0, "invalid maxDuration");
            require(
                (req.prepay && req.prepayAmount > 0) ||
                    (!req.prepay && req.prepayAmount == 0),
                "invalid prepay settings"
            );
            lendingReqsPerDeck[_deckId] = req;
            totalListedIds.add(_deckId);
        }
    }

    /// @inheritdoc ILendingMaster
    function borrow(
        uint256[] memory _deckIds,
        uint256 _duration
    ) external override {
        address sender = msg.sender;
        uint256 length = _deckIds.length;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _duration * 1 days;
        require(length > 0, "invalid length array");
        require(_duration > 0, "invalid borrow duration");

        address lender = deckInfo[_deckIds[0]].owner;
        for (uint256 i = 1; i < length; i++) {
            uint256 _deckId = _deckIds[i];
            uint256 requireAmount = 0;
            DeckInfo storage info = deckInfo[_deckId];
            LendingReq memory req = lendingReqsPerDeck[_deckId];
            require(totalListedIds.contains(_deckId), "not listed for lend");
            require(info.owner == lender, "should be same lender");
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "already borrowed"
            );
            require(req.maxDuration > _duration, "exceeds to max duration");
            if (req.prepay) {
                require(
                    IERC20(req.paymentToken).balanceOf(sender) >=
                        req.prepayAmount,
                    "not enough for prepayment"
                );
                requireAmount += req.prepayAmount;
            }
            uint256 totalInterest = req.dailyInterest * _duration;
            requireAmount += totalInterest;
            require(
                IERC20(req.paymentToken).balanceOf(sender) >= requireAmount,
                "not enough cost for borrow"
            );

            lockedInterestsPerDeck[deckId] += _transferFrom(
                req.paymentToken,
                sender,
                address(this),
                totalInterest
            );

            if (req.prepayAmount > 0) {
                _transferFrom(
                    req.paymentToken,
                    sender,
                    info.owner,
                    req.prepayAmount
                );
            }

            _takeServiceFee(sender, collectionInfoPerDeck[_deckId]);

            info.borrower = sender;
            info.startTime = startTime;
            info.endTime = endTime;
            borrowedIdsPerUser[sender].add(_deckId);
        }
    }

    /// @inheritdoc ILendingMaster
    function withdrawCollection(uint256[] memory _deckIds) external override {
        address sender = msg.sender;
        uint256 length = _deckIds.length;
        require(length > 0, "invalid length array");

        for (uint256 i = 0; i < length; i++) {
            uint256 _deckId = _deckIds[i];
            DeckInfo memory info = deckInfo[_deckId];
            require(
                depositedIdsPerUser[sender].contains(_deckId),
                "invalid deckId"
            );
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "borrowed deckId"
            );
            require(
                lockedInterestsPerDeck[_deckId] == 0,
                "should claim interests first"
            );

            for (uint256 j = 0; j < info.deckIds.length; j++) {
                _withdrawDeck(sender, info.deckIds[j]);
            }
        }
    }

    /// @inheritdoc ILendingMaster
    function claimLendingInterest(uint256 _deckId) external override {
        address sender = msg.sender;
        uint256 claimableAmount = lockedInterestsPerDeck[_deckId];
        DeckInfo memory info = deckInfo[_deckId];
        LendingReq memory req = lendingReqsPerDeck[_deckId];
        require(info.owner == address(0), "invalid deckId");
        require(info.owner == sender, "only lender");
        require(info.endTime < block.timestamp, "before maturity");
        require(claimableAmount > 0, "not claimable interest");

        lockedInterestsPerDeck[_deckId] = 0;
        lockedTokenAmount[req.paymentToken] -= claimableAmount;
        address borrower = info.borrower;
        if (borrowedIdsPerUser[borrower].contains(_deckId)) {
            borrowedIdsPerUser[borrower].remove(_deckId);
        }
        IERC20(req.paymentToken).safeTransfer(sender, claimableAmount);
    }

    /// @inheritdoc ILendingMaster
    function getAllLendDecks(
        address _account
    ) external view override returns (uint256[] memory) {
        uint256[] memory listedIds = listedIdsPerUser[_account].values();
        uint256 amount = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            DeckInfo memory info = deckInfo[listedIds[i]];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                amount++;
            }
        }

        uint256[] memory lendableIds = new uint256[](amount);
        uint256 index = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            uint256 _deckId = listedIds[i];
            DeckInfo memory info = deckInfo[_deckId];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                lendableIds[index++] = _deckId;
            }
        }

        return lendableIds;
    }

    /// @inheritdoc ILendingMaster
    function getAllBorrowedDecks(
        address _account
    ) external view override returns (uint256[] memory) {
        uint256[] memory listedIds = borrowedIdsPerUser[_account].values();
        uint256 amount = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            DeckInfo memory info = deckInfo[listedIds[i]];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            amount++;
        }

        uint256[] memory borrowedIds = new uint256[](amount);
        uint256 index = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            uint256 _deckId = listedIds[i];
            DeckInfo memory info = deckInfo[_deckId];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            borrowedIds[index++] = _deckId;
        }

        return borrowedIds;
    }

    /// @inheritdoc ILendingMaster
    function getDeckLpInfo(
        uint256 _deckId
    ) external view override returns (DeckInfo memory) {
        return deckInfo[_deckId];
    }

    /// @inheritdoc ILendingMaster
    function getServiceFeeInfo(
        uint256 _serviceFeeId
    ) external view override returns (ServiceFee memory) {
        return serviceFees[_serviceFeeId];
    }

    /// @inheritdoc ILendingMaster
    function getLockedERC20(
        address _token
    ) external view override returns (uint256) {
        return lockedTokenAmount[_token];
    }

    /// @inheritdoc ILendingMaster
    function getAllowedNLBundles()
        external
        view
        override
        returns (address[] memory)
    {
        return allowedNLBundles.values();
    }

    /// @inheritdoc ILendingMaster
    function getAllowedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return allowedTokens.values();
    }

    /// @inheritdoc ILendingMaster
    function getAllowedCollections()
        external
        view
        override
        returns (address[] memory)
    {
        return allowedCollections.values();
    }

    /// @inheritdoc ILendingMaster
    function getListedDecks() external view returns (uint256[] memory) {
        return totalListedIds.values();
    }

    function _transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 beforeBal = IERC20(_token).balanceOf(_to);
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        uint256 afterBal = IERC20(_token).balanceOf(_to);
        uint256 recvAmount = afterBal - beforeBal;

        if (_to == address(this)) {
            lockedTokenAmount[_token] += recvAmount;
        }

        return recvAmount;
    }

    function _withdrawDeck(address _owner, uint256 _deckId) internal {
        CollectionInfo memory collectionInfo = collectionInfoPerDeck[_deckId];

        for (uint256 j = 0; j < collectionInfo.collections.length; j++) {
            IERC721(collectionInfo.collections[j]).transferFrom(
                address(this),
                _owner,
                collectionInfo.tokenIds[j]
            );
        }
        depositedIdsPerUser[_owner].remove(_deckId);
        totalDepositedIds.remove(_deckId);
        if (listedIdsPerUser[_owner].contains(_deckId)) {
            listedIdsPerUser[_owner].remove(_deckId);
            totalListedIds.remove(_deckId);
        }
    }

    function _takeServiceFee(
        address _sender,
        CollectionInfo memory _collectionInfo
    ) internal {
        address[] memory collections = _collectionInfo.collections;

        uint256 length = collections.length;
        for (uint256 i = 0; i < length; i++) {
            address collection = collections[i];
            uint256 feeId = linkServiceFees[collection];
            ServiceFee memory serviceFee = serviceFees[feeId];
            IERC20 paymentToken = IERC20(serviceFee.paymentToken);
            uint256 feeAmount = serviceFee.feeAmount;
            if (serviceFee.active) {
                require(
                    paymentToken.balanceOf(_sender) >= feeAmount,
                    "not enough balance for serviceFee"
                );
                feeAmount = _transferFrom(
                    address(paymentToken),
                    _sender,
                    address(this),
                    feeAmount
                );
                uint256 burnAmount = (feeAmount * serviceFee.burnPercent) /
                    FIXED_POINT;
                paymentToken.safeTransfer(DEAD, burnAmount);
                _buyBack(address(paymentToken), feeAmount - burnAmount);
            }
        }
    }

    function _buyBack(address _paymentToken, uint256 _amount) internal {
        if (!buybackFees[_paymentToken].active || _amount == 0) return;

        address[] memory path = new address[](3);
        path[0] = _paymentToken;
        path[1] = IUniswapV2Router02(dexRouter).WETH();
        path[2] = fevrToken;

        uint256 beforeBal = IERC20(fevrToken).balanceOf(address(this));
        IERC20(_paymentToken).approve(dexRouter, _amount);
        IUniswapV2Router02(dexRouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp
            );
        uint256 afterBal = IERC20(fevrToken).balanceOf(address(this));
        uint256 swappedAmount = afterBal - beforeBal;

        uint16 feeRate = buybackFees[_paymentToken].feeRate;
        uint256 feeAmount = (swappedAmount * feeRate) / FIXED_POINT;
        uint256 burnAmount = swappedAmount - feeAmount;
        if (burnAmount == 0) return;
        IERC20(fevrToken).safeTransfer(DEAD, burnAmount);
    }
}
