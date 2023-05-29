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
import "./interfaces/BundlesInterface.sol";
import "./interfaces/IUniswapRouter02.sol";
import "./interfaces/IWBNB.sol";
import "./libraries/Utils.sol";

contract LendingMaster is ERC721Holder, Ownable, ILendingMaster {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedNLBundles;

    /// @notice Deposited depositIds totally.
    EnumerableSet.UintSet private totalDepositedIds;

    /// @notice Total borrowed depositIds.
    EnumerableSet.UintSet private totalBorrowedIds;

    /// @notice depositIds listed for lending totally.
    EnumerableSet.UintSet private totalListedIds;

    /// @notice deposited depositIds of each user.
    mapping(address => EnumerableSet.UintSet) private depositedIdsPerUser;

    /// @notice depositIds listed for lending of each user.
    mapping(address => EnumerableSet.UintSet) private listedIdsPerUser;

    /// @notice borrowed depositIds of each user.
    mapping(address => EnumerableSet.UintSet) private borrowedIdsPerUser;

    /// @dev The fee infomation for buyback.
    mapping(address => BuyBackFee) private buybackFees;

    /// @dev Lending req for each depositId.
    mapping(uint256 => LendingReq) public lendingReqsPerDeck;

    /// The information of ServiceFee by serviceFeeId.
    mapping(uint256 => ServiceFee) public serviceFees;

    /// The information of each deck.
    mapping(uint256 => DepositInfo) private depositInfo;

    /// Collection information per depositId
    mapping(uint256 => CollectionInfo) private collectionInfoPerDeck;

    /// The max amount of collection that can be deposited.
    mapping(address => uint256) public depositLimitations;

    /// @dev ServiceFee for accepted collection.
    mapping(address => uint256) private linkServiceFees;

    /// @dev The address of uniswap router.
    address public dexRouter;

    /// @dev The address of fevr token.
    address public fevrToken;

    /// @dev The id of ServiceFee.
    uint256 public serviceFeeId;

    uint256 public depositId;

    /// @dev Max collection amount that LBundle can contain.
    uint256 public maxAmountForBundle;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint16 public FIXED_POINT = 1000;

    uint16 public constant RF_GAME_FEE = 50; // 5%

    bool public LBundleMode;

    constructor(address _fevrToken, address _dexRouter) {
        require(_fevrToken != address(0), "zero fevr token address");
        require(_dexRouter != address(0), "zero dex router address");
        fevrToken = _fevrToken;
        dexRouter = _dexRouter;
        serviceFeeId = 1;
        depositId = 1;
    }

    /// @inheritdoc ILendingMaster
    function setAcceptableERC20(
        address[] memory _tokens,
        bool _accept
    ) external override onlyOwner {
        uint256 length = Utils.checkAddressArray(_tokens);
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

        emit AcceptableERC20Set(_tokens, _accept);
    }

    /// @inheritdoc ILendingMaster
    function setApprovedCollections(
        address[] memory _collections,
        bool _accept
    ) external override onlyOwner {
        uint256 length = Utils.checkAddressArray(_collections);
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

        emit ApprovedCollectionsSet(_collections, _accept);
    }

    /// @inheritdoc ILendingMaster
    function enableLBundleMode(bool _enable) external override onlyOwner {
        LBundleMode = _enable;
        emit LBundleModeEnabled(_enable);
    }

    /// @inheritdoc ILendingMaster
    function setNLBundles(
        address[] memory _nlBundles,
        bool _accept
    ) external override onlyOwner {
        uint256 length = Utils.checkAddressArray(_nlBundles);
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

        emit NLBundlesSet(_nlBundles, _accept);
    }

    /// @inheritdoc ILendingMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external override onlyOwner {
        _checkAcceptedToken(_paymentToken);
        require(_burnPercent <= FIXED_POINT, "invalid burn percent");
        require(_feeAmount > 0, "invalid feeAmount");
        serviceFees[serviceFeeId++] = ServiceFee(
            _paymentToken,
            _feeAmount,
            _feeName,
            _feeFlag,
            _burnPercent
        );

        emit ServiceFeeSet(
            serviceFeeId - 1,
            _paymentToken,
            _feeAmount,
            _feeFlag,
            _feeName,
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
        _checkAcceptedCollection(_collectionAddress);
        require(
            linkServiceFees[_collectionAddress] == 0,
            "already linked to a fee"
        );
        linkServiceFees[_collectionAddress] = _serviceFeeId;

        emit ServiceFeeLinked(_serviceFeeId, _collectionAddress);
    }

    /// @inheritdoc ILendingMaster
    function setMaxAmountForBundle(
        uint256 _newAmount
    ) external override onlyOwner {
        require(_newAmount > 0, "invalid maxAmountForBundle value");
        maxAmountForBundle = _newAmount;
        emit MaxAmountForBundleSet(_newAmount);
    }

    /// @inheritdoc ILendingMaster
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external override onlyOwner {
        _checkAcceptedCollection(_collectionAddress);
        require(_depositLimit > 0, "invalid deposit limit");
        depositLimitations[_collectionAddress] = _depositLimit;
        emit DepositFlagSet(_collectionAddress, _depositLimit);
    }

    /// @inheritdoc ILendingMaster
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external override onlyOwner {
        _checkAcceptedToken(_token);
        require(buybackFees[_token].feeRate > 0, "buybackFee rate is not set");
        buybackFees[_token].active = _turningStatus;
        emit BuybackFeeTake(_token, _turningStatus);
    }

    /// @inheritdoc ILendingMaster
    function setBuybackFee(
        address _token,
        uint16 _buybackFee
    ) external override onlyOwner {
        _checkAcceptedToken(_token);
        require(_buybackFee > 0, "invalid buybackFee rate");
        buybackFees[_token].feeRate = _buybackFee;
        emit BuybackFeeSet(_token, _buybackFee);
    }

    /// @inheritdoc ILendingMaster
    function depositCollection(
        address[] memory _collections,
        uint256[] memory _tokenIds,
        bool _isLBundleMode
    ) external override {
        address sender = msg.sender;
        uint256 length = Utils.compareAddressArrayLength(
            _collections,
            _tokenIds.length
        );
        require(
            !_isLBundleMode || maxAmountForBundle >= length,
            "exceeds to maxAmountForBundle"
        );
        require(!_isLBundleMode || LBundleMode, "LBundleMode disabled");

        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            uint256 tokenId = _tokenIds[i];
            _checkCollection(collection, tokenId);
            IERC721(collection).transferFrom(sender, address(this), tokenId);

            if (!_isLBundleMode) {
                depositedIdsPerUser[sender].add(depositId);
                depositInfo[depositId] = DepositInfo(
                    sender,
                    address(0),
                    0,
                    0,
                    Utils.genUintArrayWithArg(depositId)
                );
                collectionInfoPerDeck[depositId] = CollectionInfo(
                    Utils.genAddressArrayWithArg(collection),
                    Utils.genUintArrayWithArg(tokenId)
                );
                depositedIdsPerUser[sender].add(depositId);
                totalDepositedIds.add(depositId);
                emit SingleCollectionDeposited(
                    collection,
                    tokenId,
                    depositId++
                );
            }
        }

        if (_isLBundleMode) {
            depositedIdsPerUser[sender].add(depositId);
            depositInfo[depositId] = DepositInfo(
                sender,
                address(0),
                0,
                0,
                Utils.genUintArrayWithArg(depositId)
            );
            collectionInfoPerDeck[depositId] = CollectionInfo(
                _collections,
                _tokenIds
            );
            depositedIdsPerUser[sender].add(depositId);
            totalDepositedIds.add(depositId);

            emit LBundleDeposited(_collections, _tokenIds, depositId++);
        }
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

        (, , address[] memory collections, ) = BundlesInterface(_bundleAddress)
            .getBundle(_tokenId);

        require(
            collections.length <= depositLimitations[_bundleAddress],
            "exceeds to depositLimitation"
        );

        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);

        depositedIdsPerUser[sender].add(depositId);
        depositInfo[depositId] = DepositInfo(
            sender,
            address(0),
            0,
            0,
            Utils.genUintArrayWithArg(depositId)
        );

        collectionInfoPerDeck[depositId] = CollectionInfo(
            Utils.genAddressArrayWithArg(_bundleAddress),
            Utils.genUintArrayWithArg(_tokenId)
        );

        depositedIdsPerUser[sender].add(depositId);
        totalDepositedIds.add(depositId);

        emit NLBundleDeposited(_bundleAddress, _tokenId, depositId++);
    }

    /// @inheritdoc ILendingMaster
    function mergeDeposits(uint256[] memory _depositIds) external override {
        address sender = msg.sender;
        uint256 length = Utils.checkUintArray(_depositIds);
        require(maxAmountForBundle >= length, "exceeds to maxAmountForBundle");
        require(LBundleMode, "LBundleMode disabled");
        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            DepositInfo storage info = depositInfo[_depositId];
            require(
                depositedIdsPerUser[sender].contains(_depositId),
                "invalid depositId"
            );
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "borrowed depositId"
            );
            require(
                !listedIdsPerUser[sender].contains(_depositId),
                "listed for lend"
            );
            depositedIdsPerUser[sender].remove(_depositId);
            totalDepositedIds.remove(_depositId);
        }
        depositedIdsPerUser[sender].add(depositId);
        listedIdsPerUser[sender].add(depositId);
        depositInfo[depositId] = DepositInfo(
            sender,
            address(0),
            0,
            0,
            _depositIds
        );
        totalDepositedIds.add(depositId++);
        emit LBundleMade(_depositIds);
    }

    /// @inheritdoc ILendingMaster
    function lend(
        uint256[] memory _depositIds,
        LendingReq[] memory _lendingReqs
    ) external override {
        address sender = msg.sender;
        uint256 length = Utils.compareUintArrayLength(
            _depositIds,
            _lendingReqs.length
        );

        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            LendingReq memory req = _lendingReqs[i];
            require(
                depositedIdsPerUser[sender].contains(_depositId),
                "not deck owner"
            );
            require(
                !listedIdsPerUser[sender].contains(_depositId),
                "already listed"
            );
            _checkAcceptedToken(req.paymentToken);
            require(req.lendDuration > 0, "invalid lendDuration");
            require(
                req.winningRateForLender +
                    req.winningRateForBorrower +
                    RF_GAME_FEE <=
                    FIXED_POINT,
                "invalid winningRate"
            );
            require(
                (req.prepay && req.prepayAmount > 0) ||
                    (!req.prepay && req.prepayAmount == 0),
                "invalid prepay settings"
            );
            lendingReqsPerDeck[_depositId] = req;
            listedIdsPerUser[sender].add(_depositId);
            totalListedIds.add(_depositId);
        }
        emit Lent(_depositIds, _lendingReqs);
    }

    /// @inheritdoc ILendingMaster
    function borrow(uint256[] memory _depositIds) external payable override {
        address sender = msg.sender;
        uint256 startTime = block.timestamp;
        (, uint16 totalWinningRate) = getUserBorrowedIds(sender);
        uint256 length = Utils.checkUintArray(_depositIds);

        address lender = depositInfo[_depositIds[0]].owner;
        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            DepositInfo storage info = depositInfo[_depositId];
            LendingReq memory req = lendingReqsPerDeck[_depositId];
            require(totalListedIds.contains(_depositId), "not listed for lend");
            require(info.owner == lender, "should be same lender");
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "already borrowed"
            );
            require(
                totalWinningRate + req.winningRateForBorrower + RF_GAME_FEE <=
                    FIXED_POINT,
                "over max DistRate"
            );
            uint256 endTime = startTime + req.lendDuration * 1 days;
            totalWinningRate += req.winningRateForBorrower;
            if (req.prepay) {
                if (req.paymentToken == address(0)) {
                    require(
                        msg.value >= req.prepayAmount,
                        "not enough for prepayment"
                    );
                } else {
                    require(
                        IERC20(req.paymentToken).balanceOf(sender) >=
                            req.prepayAmount,
                        "not enough for prepayment"
                    );

                    _transferFrom(
                        req.paymentToken,
                        sender,
                        info.owner,
                        req.prepayAmount
                    );
                }
            }

            _takeServiceFee(sender, collectionInfoPerDeck[_depositId]);

            info.borrower = sender;
            info.startTime = startTime;
            info.endTime = endTime;
            if (!borrowedIdsPerUser[sender].contains(_depositId)) {
                borrowedIdsPerUser[sender].add(_depositId);
            }
            if (!totalBorrowedIds.contains(_depositId)) {
                totalBorrowedIds.add(_depositId);
            }
        }
        emit Borrowed(_depositIds);
    }

    /// @inheritdoc ILendingMaster
    function withdrawCollection(
        uint256[] memory _depositIds
    ) external override {
        address sender = msg.sender;
        uint256 length = Utils.checkUintArray(_depositIds);

        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            DepositInfo memory info = depositInfo[_depositId];
            require(
                depositedIdsPerUser[sender].contains(_depositId),
                "not deck owner"
            );
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "borrowed depositId"
            );

            for (uint256 j = 0; j < info.depositIds.length; j++) {
                _withdrawDeck(sender, info.depositIds[j]);
            }
        }
        emit CollectionWithdrawn(_depositIds);
    }

    /// @inheritdoc ILendingMaster
    function withdrawToken(address _token) external override onlyOwner {
        address sender = msg.sender;
        require(
            (_token == address(0) && address(this).balance > 0) &&
                (IERC20(_token).balanceOf(address(this)) > 0),
            "no withdrawable amount"
        );
        uint256 claimableAmount;
        if (_token == address(0)) {
            claimableAmount = address(this).balance;
            _transferBNB(sender, claimableAmount);
        } else {
            claimableAmount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(owner(), claimableAmount);
        }

        emit TokenWithdrawn(_token);
    }

    /// @inheritdoc ILendingMaster
    function getUserDepositedIds(
        address _user
    ) external view override returns (uint256[] memory) {
        return depositedIdsPerUser[_user].values();
    }

    /// @inheritdoc ILendingMaster
    function getUserListedIds(
        address _user
    ) external view override returns (uint256[] memory) {
        return listedIdsPerUser[_user].values();
    }

    /// @inheritdoc ILendingMaster
    function getUserNotListedIds(
        address _user
    ) external view override returns (uint256[] memory) {
        uint256 length = depositedIdsPerUser[_user].length() -
            listedIdsPerUser[_user].length();
        uint256[] memory ids = new uint256[](length);
        if (length == 0) {
            return ids;
        }
        uint256 index = 0;
        for (uint256 i = 0; i < depositedIdsPerUser[_user].length(); i++) {
            uint256 id = depositedIdsPerUser[_user].at(i);
            if (!listedIdsPerUser[_user].contains(id)) {
                ids[index++] = id;
                if (index == length) {
                    break;
                }
            }
        }

        return ids;
    }

    /// @inheritdoc ILendingMaster
    function getTotalBorrowedIds()
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory listedIds = totalBorrowedIds.values();
        uint256 amount = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            DepositInfo memory info = depositInfo[listedIds[i]];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            amount++;
        }

        uint256[] memory borrowedIds = new uint256[](amount);
        uint256 index = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            uint256 _depositId = listedIds[i];
            DepositInfo memory info = depositInfo[_depositId];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            borrowedIds[index++] = _depositId;
        }

        return borrowedIds;
    }

    /// @inheritdoc ILendingMaster
    function getUserBorrowedIds(
        address _account
    ) public view override returns (uint256[] memory, uint16) {
        uint16 winningDistRate = 0;
        uint256[] memory listedIds = borrowedIdsPerUser[_account].values();
        uint256 amount = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            DepositInfo memory info = depositInfo[listedIds[i]];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            amount++;
        }

        uint256[] memory borrowedIds = new uint256[](amount);
        uint256 index = 0;
        for (uint256 i = 0; i < listedIds.length; i++) {
            uint256 _depositId = listedIds[i];
            DepositInfo memory info = depositInfo[_depositId];
            if (info.borrower == address(0) || info.endTime < block.timestamp) {
                continue;
            }
            borrowedIds[index++] = _depositId;
            winningDistRate += lendingReqsPerDeck[_depositId]
                .winningRateForBorrower;
        }

        return (borrowedIds, winningDistRate);
    }

    /// @inheritdoc ILendingMaster
    function getDepositInfo(
        uint256 _depositId
    ) external view override returns (DepositInfo memory) {
        return depositInfo[_depositId];
    }

    /// @inheritdoc ILendingMaster
    function getCollectionInfo(
        uint256 _depositId
    ) external view override returns (CollectionInfo memory) {
        return collectionInfoPerDeck[_depositId];
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
    function getTotalListedCollections()
        external
        view
        returns (uint256[] memory)
    {
        uint256 cnt = 0;
        for (uint256 i = 0; i < totalListedIds.length(); i++) {
            uint256 id = totalListedIds.at(i);
            if (depositInfo[id].endTime < block.timestamp) {
                cnt++;
            }
        }
        uint256[] memory ids = new uint256[](cnt);
        uint256 index = 0;
        for (uint256 i = 0; i < totalListedIds.length(); i++) {
            uint256 id = totalListedIds.at(i);
            if (depositInfo[id].endTime < block.timestamp) {
                ids[index++] = id;
            }
        }
        return ids;
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

        return recvAmount;
    }

    function _withdrawDeck(address _owner, uint256 _depositId) internal {
        CollectionInfo memory collectionInfo = collectionInfoPerDeck[
            _depositId
        ];

        for (uint256 j = 0; j < collectionInfo.collections.length; j++) {
            IERC721(collectionInfo.collections[j]).transferFrom(
                address(this),
                _owner,
                collectionInfo.tokenIds[j]
            );
        }
        depositedIdsPerUser[_owner].remove(_depositId);
        totalDepositedIds.remove(_depositId);
        if (listedIdsPerUser[_owner].contains(_depositId)) {
            listedIdsPerUser[_owner].remove(_depositId);
            totalListedIds.remove(_depositId);
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
                if (serviceFee.paymentToken != address(0)) {} else {
                    feeAmount = _transferFrom(
                        address(paymentToken),
                        _sender,
                        address(this),
                        feeAmount
                    );
                }

                uint256 burnAmount = (feeAmount * serviceFee.burnPercent) /
                    FIXED_POINT;
                if (serviceFee.paymentToken == address(0)) {
                    _transferBNB(DEAD, burnAmount);
                } else {
                    paymentToken.safeTransfer(DEAD, burnAmount);
                }
                _buyBack(address(paymentToken), feeAmount - burnAmount);
            }
        }
    }

    function _buyBack(address _paymentToken, uint256 _amount) internal {
        if (!buybackFees[_paymentToken].active || _amount == 0) return;

        uint256 swappedAmount = _amount;
        if (_paymentToken != fevrToken) {
            address WETH = IUniswapV2Router02(dexRouter).WETH();
            address[] memory path;
            if (_paymentToken == address(0)) {
                IWBNB(WETH).deposit{value: _amount}();
                path = new address[](2);
                path[0] = WETH;
                path[1] = fevrToken;
            } else {
                path = new address[](3);
                path[0] = _paymentToken;
                path[1] = WETH;
                path[2] = fevrToken;
            }

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
            swappedAmount = afterBal - beforeBal;
        }

        uint16 feeRate = buybackFees[_paymentToken].feeRate;
        uint256 feeAmount = (swappedAmount * feeRate) / FIXED_POINT;
        uint256 burnAmount = swappedAmount - feeAmount;
        if (burnAmount == 0) return;
        IERC20(fevrToken).safeTransfer(DEAD, burnAmount);
    }

    function _checkCollection(
        address _collection,
        uint256 _tokenId
    ) internal view {
        require(
            allowedCollections.contains(_collection),
            "not allowed collection"
        );
        require(
            IERC721(_collection).ownerOf(_tokenId) == msg.sender,
            "not collection owner"
        );
    }

    function _checkAcceptedToken(address _token) internal view {
        require(allowedTokens.contains(_token), "token is not allowed");
    }

    function _checkAcceptedCollection(
        address _collectionAddress
    ) internal view {
        require(
            _collectionAddress != address(0) &&
                (allowedCollections.contains(_collectionAddress) ||
                    allowedNLBundles.contains(_collectionAddress)),
            "not acceptable collection address"
        );
    }

    function _transferBNB(address _to, uint256 _amount) internal {
        require(_amount > 0, "invalid send BNB amount");
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "sending BNB failed");
    }
}
