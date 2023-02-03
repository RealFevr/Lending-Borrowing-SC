// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IDeckStructure.sol";

interface IDeckMaster is IDeckStructure {

    /// @notice Set collection amount one bundle should have.
    /// @dev Only owner can call this function.
    /// @param _amount The amount of collection one bundle should have.
    function setCollectionAmountForBundle(uint256 _amount) external;

    /// @notice Set acceptable ERC20 token.
    /// @dev Only owner can call this function.
    /// @param _token   The address of ERC20 token.
    /// @param _accept  Status for accept or not.
    function setAcceptableERC20(address _token, bool _accept) external;

    /// @notice Set acceptable Collections.
    /// @dev Only owner can call this function.
    /// @param _collections The addresses of Opener.
    /// @param _accept The status for accept or not.
    function setAcceptableCollections(address[] memory _collections, bool _accept) external;

    /// @notice Set acceptable Bundles.
    /// @dev Only owner can call this function.
    /// @param _bundle The address of Bundle.
    /// @param _accept The status for accept or not.
    function setAcceptableBundle(address _bundle, bool _accept) external;

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

    /// @notice Set deposit flag.
    /// @dev Only owner can call this function.
    /// @param _collectionAddress      The address of collection.
    /// @param _depositLimit    The max deposit collection count.
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external;

    /// @notice Deposit Collection and get deckLp.
    /// @param _collectionAddress The address of collections.
    /// @param _tokenIds     Collection token ids.
    function depositCollections(
        address _collectionAddress,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Deposit Bundle Collection and get deckLp.
    /// @param _bundleAddress The address of bundle Collection.
    /// @param _tokenId       The token id of Bundle Collection.
    function depositBundle(address _bundleAddress, uint256 _tokenId) external;

    /// @notice Withdraw Collections by burning deckLp.
    /// @param _deckLpId The id of deckLp.
    function withdrawCollections(
        uint256 _deckLpId
    ) external;

    /// @notice Lend deck/moment.
    /// @param _paymentToken    The address of payment token.
    /// @param _deckLpId        The token id of deck lp.
    /// @param _dailyInterest   The token amount of daily interest.
    /// @param _prepayAmount    The token amount for prepay.
    /// @param _duration        The duration of lend.
    /// @param _prepay          Status for prepay is required or not.
    /// @param _winDist         Winning Distribution info.
    function lend(
        address _paymentToken,
        uint256 _deckLpId,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        uint256 _duration,
        bool _prepay,
        WinningDistribution memory _winDist
    ) external;

    /// @notice Borrow Collection with deckLp.
    /// @param _deckLpId The deckLp token id to borrow.
    function borrow(
        uint256 _deckLpId
    ) external;

    /// @notice Let the owner tell the contract the total winnings of a certain deckLp.
    /// @dev Only owner can call this function.
    /// @param _deckLpId    The deckLp token id.
    /// @param _totalWinnings The total rewards amount for winnings.
    /// @param _gameIds     The array of game id.
    function winningCalculation(
        uint256 _deckLpId,
        uint256 _totalWinnings,
        uint256[] memory _gameIds
    ) external;

    /// @notice Let lender & borrower claim he winnings related to a deckLp.
    /// @dev Only borrower and lender can call this function.
    /// @param _deckLpId The token id of deckLp.
    function claimWinnings(uint256 _deckLpId) external;

    /// @notice Let lender claim the interest related to a deckLp.
    /// @param _deckLpId The token id of deckLp.
    function claimInterest(uint256 _deckLpId) external;

    /// @notice Enables the buyback for a certain ERC20.
    /// @dev Only owner can call this function.
    /// @param _token           The address of token.
    /// @param _turningStatus   Status for turn on or off.
    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external;

    /// @notice Sets the buyback fee for certain ERC20.
    /// @param _token       The address of token.
    /// @param _buybackFee  Fee percent of buyback.
    function setBuybackFee(
        address _token,
        uint16 _buybackFee
    ) external;

    /// @notice Get the information about the borrowing for certain deckLp.
    /// @param _deckLpId The token id of deckLp.
    /// @return duration        Borrow duration
    /// @return prepay          Prepay amount.
    /// @return interest        Daily interest.
    /// @return winDistribution Distribution of win.
    function getReceiptDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (
        uint256 duration, 
        uint256 prepay, 
        uint256 interest, 
        WinningDistribution memory winDistribution
    );

    /// @notice Get information for certain deckLp.
    /// @param _deckLpId The token id of deckLp.
    /// @return collectionAddress  The address of collection.
    /// @return tokenIds    The array of token ids.
    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (address collectionAddress, uint256[] memory tokenIds);

    /// @notice Get deckLp count.
    /// @return Total deckLp count.
    function getAllDeckCount() external view returns (uint256);

    /// @notice Get opener address.
    function getCollectionAddress() external view returns (address[] memory);

    /// @notice Get contract address of bundles.
    function getBundlesAddress() external view returns (address[] memory);

    /// @notice Get if service fee is active and the total amount per serviceFeeId.
    function getServiceFeeInfo(uint256 _serviceFeedId) external view returns (ServiceFee memory);

    /// @notice Get how many tokens are locked by borrowers.
    function getLockedERC20(address _token) external view returns (uint256);

    /// @notice Get allowed ERC20 token addresses.
    function getAllowedTokens() external view returns (address[] memory);

    /// @notice Get allowed collection addresses.
    function getAllowedCollections() external view returns (address[] memory);

    /// @notice Get allowed bundle addresses.
    function getAllowedBundles() external view returns (address[] memory);

    event AcceptableERC20Set(address indexed token, bool status);

    event AcceptableCollectionsSet(address[] indexed opener, bool status);

    event AcceptableBundleSet(address indexed bundle, bool status);

    event ServiceFeeSet(address paymentToken, uint256 feeAmount, bool feeFlag, string feeName, uint16 burnPercent);

    event ServiceFeeLinked(uint256 serviceFeeId, address indexed collectionAddress);

    event DepositFlagSet(address indexed collectionAddress, uint256 depositLimit);

    event CollectionAmountForBundleSet(uint256 amount);

    event CollectionsDeposited(address indexed collectionAddress, uint256[] tokenIds, uint256 deckLpId);

    event BundleDeposited(address indexed bundleCollection, uint256 tokenId, uint256 deckLpId);

    event Withdraw(address indexed withdrawer, uint256 deckLpId);

    event Lend(address indexed lender, uint256 deckLpId);

    event Borrow(address indexed borrower, uint256 receiptDeckLpId);

    event WinningRewardsSet(uint256 deckLpId, uint256[] gameIds, uint256 totalWinnings);

    event WinningRewardsClaimed(address indexed claimer, uint256 deckLpId);

    event InterestClaimed(address indexed claimer, uint256 interest);
}