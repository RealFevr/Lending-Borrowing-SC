// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILendingMaster.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/BundlesInterface.sol";
import "./interfaces/IUniswapRouter02.sol";
import "./interfaces/IWBNB.sol";
import "./libraries/Utils.sol";

contract LendingMaster is
    ERC721Holder,
    Ownable,
    ILendingMaster,
    ReentrancyGuard
{
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

    /// @dev Lending req for each depositId.
    mapping(uint256 => LendingReq) public lendingReqsPerDeck;

    /// The information of ServiceFee by paymentToken.
    mapping(address => ServiceFee) public serviceFees;

    /// The information of each deck.
    mapping(uint256 => DepositInfo) private depositInfo;

    /// Collection information per depositId
    mapping(uint256 => CollectionInfo) private collectionInfoPerDeck;

    /// The max amount of collection that can be deposited.
    mapping(address => DepositLimitInfo) public depositLimitations;

    /// @dev The address of treasury;
    address public treasury;

    uint256 public depositId;

    /// @dev Max collection amount that LBundle can contain.
    uint256 public maxAmountForBundle;

    uint256 public minAmountForBundle;

    uint16 public constant FIXED_POINT = 1000;

    uint16 public RF_GAME_FEE = 50; // 5%

    uint16 public maxCollectiblesAtOnce;

    bool public LBundleMode;

    constructor(address _treasury) {
        require(_treasury != address(0), "zero treasury address");
        treasury = _treasury;
        depositId = 1;
        maxCollectiblesAtOnce = 100;
    }

    function setMaxCollectiblesAtOnce(
        uint16 _maxCollectiblesAtOnce
    ) external override onlyOwner {
        require(
            _maxCollectiblesAtOnce > 0,
            "maximum managed collections should be greater than zero"
        );
        require(
            _maxCollectiblesAtOnce != maxCollectiblesAtOnce,
            "maximum managed collections already set"
        );
        maxCollectiblesAtOnce = _maxCollectiblesAtOnce;
    }

    /// @inheritdoc ILendingMaster
    function setTreasury(address _treasury) external override onlyOwner {
        require(_treasury != address(0), "zero treasury address");
        treasury = _treasury;
    }

    /// @inheritdoc ILendingMaster
    function setAcceptableERC20(
        address[] memory _tokens,
        bool _accept
    ) external override onlyOwner {
        uint256 length = Utils.checkAddressArray(_tokens);
        for (uint256 i = 0; i < length; i++) {
            Utils.updateAddressEnumerable(allowedTokens, _tokens[i], _accept);
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
            Utils.updateAddressEnumerable(
                allowedCollections,
                _collections[i],
                _accept
            );
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
            Utils.updateAddressEnumerable(
                allowedNLBundles,
                _nlBundles[i],
                _accept
            );
        }

        emit NLBundlesSet(_nlBundles, _accept);
    }

    /// @inheritdoc ILendingMaster
    function setRFGameFee(uint16 _gameFee) external override onlyOwner {
        require(_gameFee <= FIXED_POINT, "invalid gameFee rate");
        RF_GAME_FEE = _gameFee;
    }

    /// @inheritdoc ILendingMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        bool _burnFlag,
        string memory _feeName
    ) external override onlyOwner {
        _checkAcceptedToken(_paymentToken);
        require(_feeAmount > 0, "invalid feeAmount");
        serviceFees[_paymentToken] = ServiceFee(
            _paymentToken,
            _feeAmount,
            _feeName,
            _burnFlag,
            _feeFlag
        );

        emit ServiceFeeSet(
            _paymentToken,
            _feeAmount,
            _feeFlag,
            _burnFlag,
            _feeName
        );
    }

    /// @inheritdoc ILendingMaster
    function configAmountForBundle(
        uint256 _minAmount,
        uint256 _maxAmount
    ) external override onlyOwner {
        Utils.checkLimitConfig(_minAmount, _maxAmount);
        minAmountForBundle = _minAmount;
        maxAmountForBundle = _maxAmount;
        emit AmountForBundleConfigured(_minAmount, _maxAmount);
    }

    /// @inheritdoc ILendingMaster
    function setNLBundleDepositFlag(
        address _nlBundleAddress,
        DepositLimitInfo memory _depositLimit
    ) external override onlyOwner {
        _checkAcceptedNLBundle(_nlBundleAddress);
        _setDepositFlag(_nlBundleAddress, _depositLimit);
    }

    /// @inheritdoc ILendingMaster
    function setCollectionDepositFlag(
        address _collectionAddress,
        DepositLimitInfo memory _depositLimit
    ) external override onlyOwner {
        _checkAcceptedCollection(_collectionAddress);
        _setDepositFlag(_collectionAddress, _depositLimit);
    }

    /// @inheritdoc ILendingMaster
    function depositCollection(
        address[] memory _collections,
        uint256[] memory _tokenIds,
        bool _isLBundleMode
    ) external override nonReentrant {
        address sender = msg.sender;
        uint256 length = Utils.compareAddressArrayLength(
            _collections,
            _tokenIds.length
        );
        require(
            !_isLBundleMode ||
                (maxAmountForBundle >= length && length >= minAmountForBundle),
            "invalid deposit amount"
        );
        require(!_isLBundleMode || LBundleMode, "LBundleMode disabled");

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

        // EFFECTS
        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            uint256 tokenId = _tokenIds[i];
            _checkCollection(collection, tokenId);
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
                totalDepositedIds.add(depositId);
                emit SingleCollectionDeposited(
                    collection,
                    tokenId,
                    depositId++
                );
            }
        }

        // INTERACTIONS
        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            uint256 tokenId = _tokenIds[i];
            IERC721(collection).transferFrom(sender, address(this), tokenId);
        }
    }

    /// @inheritdoc ILendingMaster
    function depositNLBundle(
        address _bundleAddress,
        uint256 _tokenId
    ) external override nonReentrant {
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
            collections.length >=
                depositLimitations[_bundleAddress].minAmount &&
                collections.length <=
                depositLimitations[_bundleAddress].maxAmount,
            "exceeds to depositLimitation"
        );

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

        totalDepositedIds.add(depositId);

        emit NLBundleDeposited(_bundleAddress, _tokenId, depositId++);

        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);
    }

    /// @inheritdoc ILendingMaster
    function mergeDeposits(uint256[] memory _depositIds) external override {
        address sender = msg.sender;
        uint256 length = Utils.checkUintArray(_depositIds);
        require(
            maxAmountForBundle >= length && length >= minAmountForBundle,
            "invalid merge amount"
        );
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
        require(
            length <= maxCollectiblesAtOnce,
            "can not lend this amount at once"
        );
        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            LendingReq memory req = _lendingReqs[i];
            req.gameFee = RF_GAME_FEE;
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
    function borrow(
        uint256[] memory _depositIds
    ) external payable override nonReentrant {
        address sender = msg.sender;
        uint256 startTime = block.timestamp;
        (
            uint256[] memory borrowedIds,
            uint16 totalWinningRate,
            uint256 totalGameFee
        ) = getUserBorrowedIds(sender);
        uint256 length = Utils.checkUintArray(_depositIds);
        require(
            length <= maxCollectiblesAtOnce,
            "can not borrow this amount at once"
        );

        // CHECKS AND EFFECTS
        address lender = depositInfo[_depositIds[0]].owner;
        require(lender != sender, "Lender and borrower cannot be the same");
        uint256 remainingAmount = msg.value;

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
            uint256 endTime = startTime + req.lendDuration * 1 days;
            totalWinningRate += req.winningRateForBorrower;
            totalGameFee += req.gameFee;

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

        uint256 averageGameFee = totalGameFee / (borrowedIds.length + length);
        require(
            totalWinningRate + averageGameFee <= FIXED_POINT,
            "over max DistRate"
        );
        emit Borrowed(_depositIds);

        // INTERACTIONS
        for (uint256 i = 0; i < length; ++i) {
            uint256 _depositId = _depositIds[i];
            DepositInfo memory info = depositInfo[_depositId];
            LendingReq memory req = lendingReqsPerDeck[_depositId];
            if (req.prepay) {
                if (req.paymentToken == address(0)) {
                    require(
                        remainingAmount >= req.prepayAmount,
                        "not enough for prepayment"
                    );
                    remainingAmount -= req.prepayAmount;
                    _transferBNB(info.owner, req.prepayAmount);
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

            _takeServiceFee(sender, req.paymentToken);
        }
    }

    /// @inheritdoc ILendingMaster
    function withdrawCollection(
        uint256[] memory _depositIds
    ) external override {
        address sender = msg.sender;
        uint256 length = Utils.checkUintArray(_depositIds);
        require(
            length <= maxCollectiblesAtOnce,
            "can not withdraw this amount at once"
        );

        emit CollectionWithdrawn(_depositIds);

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
    ) public view override returns (uint256[] memory, uint16, uint256) {
        uint16 winningDistRate = 0;
        uint256 totalGameFee = 0;
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
            totalGameFee += lendingReqsPerDeck[_depositId].gameFee;
        }

        return (borrowedIds, winningDistRate, totalGameFee);
    }

    /// @inheritdoc ILendingMaster
    function getDepositInfo(
        uint256 _depositId
    ) external view override returns (DepositInfo memory, uint256[] memory) {
        return (depositInfo[_depositId], depositInfo[_depositId].depositIds);
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

        depositedIdsPerUser[_owner].remove(_depositId);
        totalDepositedIds.remove(_depositId);
        if (listedIdsPerUser[_owner].contains(_depositId)) {
            listedIdsPerUser[_owner].remove(_depositId);
            totalListedIds.remove(_depositId);
        }

        for (uint256 j = 0; j < collectionInfo.collections.length; j++) {
            IERC721(collectionInfo.collections[j]).transferFrom(
                address(this),
                _owner,
                collectionInfo.tokenIds[j]
            );
        }
    }

    function _takeServiceFee(address _sender, address _paymentToken) internal {
        ServiceFee memory serviceFee = serviceFees[_paymentToken];
        uint256 feeAmount = serviceFee.feeAmount;

        if (serviceFee.active) {
            if (_paymentToken == address(0)) {
                _transferBNB(treasury, feeAmount);
            } else {
                feeAmount = _transferFrom(
                    _paymentToken,
                    _sender,
                    treasury,
                    feeAmount
                );
            }
            ITreasury(treasury).takeServiceFee(
                _paymentToken,
                feeAmount,
                serviceFee.burnFlag
            );
        }
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
            allowedCollections.contains(_collectionAddress),
            "not acceptable collection address"
        );
    }

    function _checkAcceptedNLBundle(address _nlBundleAddress) internal view {
        require(
            allowedNLBundles.contains(_nlBundleAddress),
            "not acceptable NLBundle address"
        );
    }

    function _setDepositFlag(
        address _collectionAddress,
        DepositLimitInfo memory _depositLimit
    ) internal {
        require(_collectionAddress != address(0), "invalid zero address");
        Utils.checkLimitConfig(
            _depositLimit.minAmount,
            _depositLimit.maxAmount
        );
        depositLimitations[_collectionAddress] = _depositLimit;
        emit DepositFlagSet(_collectionAddress, _depositLimit);
    }

    function _transferBNB(address _to, uint256 _amount) internal {
        require(_amount > 0, "invalid send BNB amount");
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "lendingMaster: sending BNB failed");
    }
}
