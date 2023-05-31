// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILendingMaster {
    struct LendingReq {
        address paymentToken;
        uint256 prepayAmount;
        uint16 lendDuration;
        uint16 winningRateForLender;
        uint16 winningRateForBorrower;
        uint16 gameFee;
        bool prepay;
    }

    struct DepositInfo {
        address owner;
        address borrower;
        uint256 startTime;
        uint256 endTime;
        uint256[] depositIds;
    }

    struct DepositLimitInfo {
        uint256 minAmount;
        uint256 maxAmount;
    }

    struct CollectionInfo {
        address[] collections;
        uint256[] tokenIds;
    }

    struct ServiceFee {
        address paymentToken;
        uint256 feeAmount;
        string serviceFeeName;
        bool active;
        uint16 burnPercent;
    }

    struct BuyBackFee {
        bool active;
        uint16 feeRate;
    }

    /// @notice Set treasury contract address.
    /// @dev Only owner can call this function.
    function setTreasury(address _treasury) external;

    /// @notice Set acceptable ERC20 token.
    /// @dev Only owner can call this function.
    /// @param _tokens   The addresses of ERC20 token.
    /// @param _accept  Status for accept or not.
    function setAcceptableERC20(
        address[] memory _tokens,
        bool _accept
    ) external;

    /// @notice Set acceptable Collections.
    /// @dev Only owner can call this function.
    /// @param _collections The addresses of Opener.
    /// @param _accept The status for accept or not.
    function setApprovedCollections(
        address[] memory _collections,
        bool _accept
    ) external;

    /// @notice Set acceptable NLBundle.
    /// @dev Only owner can call this function.
    /// @param _nlBundles The addresses of Opener.
    /// @param _accept The status for accept or not.
    function setNLBundles(address[] memory _nlBundles, bool _accept) external;

    /// @notice Set gameFee rate.
    /// @dev Only owner can call this function.
    function setRFGameFee(uint16 _gameFee) external;

    /// @notice Enable/Disable deposit/merge LBundle.
    /// @dev Only owner can call this function.
    function enableLBundleMode(bool _enable) external;

    /// @notice Set service fee.
    /// @dev Only owner can call this function.
    /// @param _paymentToken    The address of payment token.
    /// @param _feeAmount       The amount of service fee.
    /// @param _feeFlag         Status fee is active or not.
    /// @param _feeName         The service fee name.
    /// @param _burnPercent     The percent to burn.
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external;

    /// @notice Linke service fee to an collection.
    /// @dev Only owner can call this function and service fee linked only once per collection.
    /// @param _serviceFeeId    ServiceFee id.
    /// @param _collectionAddress      The address of collection.
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _collectionAddress
    ) external;

    /// @notice Set max amount for bundle.
    /// @dev Only owner can call this function.
    function configAmountForBundle(
        uint256 _minAmount,
        uint256 _maxAmount
    ) external;

    /// @notice Set deposit flag.
    /// @dev Only owner can call this function.
    /// @param _collectionAddress      The address of collection.
    /// @param _depositLimit    The min/max deposit collection count.
    function setDepositFlag(
        address _collectionAddress,
        DepositLimitInfo memory _depositLimit
    ) external;

    /// @notice Deposit single collections or as LBundle.
    /// @dev User can deposit serveral collections at once.
    function depositCollection(
        address[] memory _collections,
        uint256[] memory _tokenIds,
        bool _isLBundleMode
    ) external;

    /// @notice Deposit Bundle Collection.
    /// @param _bundleAddress The address of bundle Collection.
    /// @param _tokenId       The token id of Bundle Collection.
    function depositNLBundle(address _bundleAddress, uint256 _tokenId) external;

    /// @notice Make LBundle with several collections.
    /// @dev Only NLBundle owner can call this function.
    function mergeDeposits(uint256[] memory _depositIds) external;

    /// @notice list collections for lending.
    /// @dev Only NLBundle owner can call this function.
    /// @param _depositIds The depositIds.
    /// @param _lendingReqs The lending requriements information.
    function lend(
        uint256[] memory _depositIds,
        LendingReq[] memory _lendingReqs
    ) external;

    /// @notice Borrow collections with depositIds.
    /// @dev Borrowers can borrow several collections but from only one lender.
    function borrow(uint256[] memory _depositIds) external payable;

    /// @notice Enables the buyback for a certain ERC20.
    /// @dev Only owner can call this function.
    /// @param _token           The address of token.
    /// @param _turningStatus   Status for turn on or off.
    function buybackFeeTake(address _token, bool _turningStatus) external;

    /// @notice Sets the buyback fee for certain ERC20.
    /// @param _token       The address of token.
    /// @param _buybackFee  Fee percent of buyback.
    function setBuybackFee(address _token, uint16 _buybackFee) external;

    /// @notice Withdraw collections.
    /// @param _depositIds depositIds to withdraw.
    function withdrawCollection(uint256[] memory _depositIds) external;

    function withdrawToken(address _token) external;

    function getUserDepositedIds(
        address _user
    ) external view returns (uint256[] memory);

    function getUserListedIds(
        address _user
    ) external view returns (uint256[] memory);

    function getUserNotListedIds(
        address _user
    ) external view returns (uint256[] memory);

    function getUserBorrowedIds(
        address _account
    ) external view returns (uint256[] memory, uint16, uint256);

    function getTotalBorrowedIds() external view returns (uint256[] memory);

    function getDepositInfo(
        uint256 _depositId
    ) external view returns (DepositInfo memory);

    function getCollectionInfo(
        uint256 _depositId
    ) external view returns (CollectionInfo memory);

    function getAllowedTokens() external view returns (address[] memory);

    function getAllowedCollections() external view returns (address[] memory);

    function getAllowedNLBundles() external view returns (address[] memory);

    function getTotalListedCollections()
        external
        view
        returns (uint256[] memory);

    event AcceptableERC20Set(address[] indexed tokens, bool accept);

    event ApprovedCollectionsSet(address[] indexed collections, bool accept);

    event NLBundlesSet(address[] indexed nlBundles, bool accept);

    event ServiceFeeSet(
        uint256 serviceFeeId,
        address indexed paymentToken,
        uint256 feeAmount,
        bool feeFlag,
        string feeName,
        uint16 burnPercent
    );

    event ServiceFeeLinked(
        uint256 serviceFeeId,
        address indexed collectionAddress
    );

    event AmountForBundleConfigured(uint256 minAmount, uint256 maxAmount);

    event DepositFlagSet(
        address indexed collectionAddress,
        DepositLimitInfo depositLimit
    );

    event SingleCollectionDeposited(
        address indexed collection,
        uint256 tokenId,
        uint256 depositId
    );

    event NLBundleDeposited(
        address indexed bundleAddress,
        uint256 tokenId,
        uint256 depositId
    );

    event LBundleDeposited(
        address[] indexed collections,
        uint256[] tokenIds,
        uint256 depositId
    );

    event LBundleMade(uint256[] depositIds);

    event Lent(uint256[] depositIds, LendingReq[] lendingReqs);

    event Borrowed(uint256[] depositIds);

    event BuybackFeeTake(address indexed token, bool turningStatus);

    event BuybackFeeSet(address indexed token, uint16 buybackFee);

    event CollectionWithdrawn(uint256[] depositIds);

    event TokenWithdrawn(address indexed token);

    event LBundleModeEnabled(bool _enable);
}
