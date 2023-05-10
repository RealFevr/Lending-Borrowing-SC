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

contract LendingMaster is ERC721Holder, Ownable, ILendingMaster {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedNLBundles;

    /// @notice deposited deckIds of each user.
    mapping(address => EnumerableSet.UintSet) private depositedIdsPerUser;

    /// @notice deckIds listed for lending of each user.
    mapping(address => EnumerableSet.UintSet) private listedIdsPerUser;

    /// @notice borrowed deckIds of each user.
    mapping(address => EnumerableSet.UintSet) private borrowedIdsPerUser;

    /// @dev The fee infomation for buyback.
    mapping(address => BuyBackFee) private buybackFees;

    /// The information of ServiceFee by serviceFeeId.
    mapping(uint256 => ServiceFee) private serviceFees;

    /// The max amount of collection that can be deposited.
    mapping(address => uint256) public depositLimitations;

    /// @notice Deposited deckIds totally.
    EnumerableSet.UintSet private totalDepositedIds;

    /// @dev ServiceFee for accepted collection.
    mapping(address => uint256) private linkServiceFees;

    /// @dev Locked token amount for certain token.
    mapping(address => uint256) private lockedTokenAmount;

    /// @notice deckIds listed for lending totally.
    EnumerableSet.UintSet private totalListedIds;

    /// @dev The address of uniswap router.
    address public dexRouter;

    /// @dev The address of fevr token.
    address public fevrToken;

    /// @dev The id of ServiceFee.
    uint256 public serviceFeeId;

    uint256 private deckId;

    uint16 public BASE_POINT = 1000;

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
        address _token,
        bool _accept
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setApprovedCollections(
        address[] memory _collections,
        bool _accept
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setNLBundles(
        address[] memory _nlBundles,
        bool _accept
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _collectionAddress
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setMaxAmountForBundle(
        uint256 _newAmount
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function setBuybackFee(
        address _token,
        uint16 _buybackFee
    ) external override onlyOwner {}

    /// @inheritdoc ILendingMaster
    function depositNLBundle(
        address _bundleAddress,
        uint256 _tokenId
    ) external override {}

    /// @inheritdoc ILendingMaster
    function depositLBundle(
        address[] memory _collections,
        uint256[] memory _tokenIds
    ) external override {}

    /// @inheritdoc ILendingMaster
    function makeLBundle(uint256[] memory _deckIds) external override {}

    /// @inheritdoc ILendingMaster
    function removeLBundle(uint256 _deckId) external override {}

    /// @inheritdoc ILendingMaster
    function lend(
        uint256[] memory _deckIds,
        LendingReq[] memory _lendingReqs
    ) external override {}

    /// @inheritdoc ILendingMaster
    function borrow(uint256[] memory _deckIds) external override {}

    /// @inheritdoc ILendingMaster
    function claimLendingInterest(uint256 _deckId) external override {}

    /// @inheritdoc ILendingMaster
    function getAllLendDecks(
        address _account
    ) external view override returns (uint256[] memory) {}

    /// @inheritdoc ILendingMaster
    function getAllBorrowedDecks(
        address _account
    ) external view override returns (uint256[] memory) {}

    /// @inheritdoc ILendingMaster
    function getDeckLpInfo(
        uint256 _deckId
    ) external view override returns (DeckInfo memory) {}

    /// @inheritdoc ILendingMaster
    function getServiceFeeInfo(
        uint256 _serviceFeedId
    ) external view override returns (ServiceFee memory) {}

    /// @inheritdoc ILendingMaster
    function getLockedERC20(
        address _token
    ) external view override returns (uint256) {}

    /// @inheritdoc ILendingMaster
    function getAllowedTokens()
        external
        view
        override
        returns (address[] memory)
    {}

    /// @inheritdoc ILendingMaster
    function getAllowedCollections()
        external
        view
        override
        returns (address[] memory)
    {}

    /// @inheritdoc ILendingMaster
    function getListedDecks() external view returns (uint256[] memory) {}
}
