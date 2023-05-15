// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILendingMaster {
    struct ListedDeckInfo {
        uint256 deckId;
        uint256 claimableAmount;
        uint256 startTime;
        uint256 endTime;
        address paymentToken;
        address borrower;
    }
    struct LendingReq {
        address paymentToken;
        uint256 dailyInterest;
        uint256 prepayAmount;
        uint16 maxDuration;
        bool prepay;
    }

    struct DeckInfo {
        address owner;
        address borrower;
        uint256 startTime;
        uint256 endTime;
        uint256 lockedInterestAmount;
        uint256[] deckIds;
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
    function setMaxAmountForBundle(uint256 _newAmount) external;

    /// @notice Set deposit flag.
    /// @dev Only owner can call this function.
    /// @param _collectionAddress      The address of collection.
    /// @param _depositLimit    The max deposit collection count.
    function setDepositFlag(
        address _collectionAddress,
        uint256 _depositLimit
    ) external;

    /// @notice Deposit single collection.
    /// @dev Users can deposit several collections once.
    /// @dev Every collection will be independent deck.
    function depositSingleCollection(
        address[] memory _collections,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Deposit Bundle Collection and get deckLp.
    /// @param _bundleAddress The address of bundle Collection.
    /// @param _tokenId       The token id of Bundle Collection.
    function depositNLBundle(address _bundleAddress, uint256 _tokenId) external;

    /// @notice Deposit several collections and make LBundle through lending contract.
    /// @param _collections The addresses of collection.
    /// @param _tokenIds    The tokenIds of collections.
    function depositLBundle(
        address[] memory _collections,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Make LBundle with several collections.
    /// @dev Only NLBundle owner can call this function.
    function makeLBundle(uint256[] memory _deckIds) external;

    /// @notice list decks for lending.
    /// @dev Only NLBundle owner can call this function.
    /// @param _deckIds The deckIds.
    /// @param _lendingReqs The lending requriements information.
    function lend(
        uint256[] memory _deckIds,
        LendingReq[] memory _lendingReqs
    ) external;

    /// @notice Borrow decks with deckIds.
    /// @dev Borrowers can borrow several decks but from only one lender.
    function borrow(uint256[] memory _deckIds, uint256 _duration) external;

    /// @notice Let lender claim the interests for deck related to lending/borrowing.
    function claimLendingInterest(uint256 _deckId) external;

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
    /// @param _deckIds deckIds to withdraw.
    function withdrawCollection(uint256[] memory _deckIds) external;

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

    function getUserListedDeckInfo(
        address _user
    ) external view returns (ListedDeckInfo[] memory);

    function getAllBorrowedDecks(
        address _account
    ) external view returns (uint256[] memory);

    function getDeckLpInfo(
        uint256 _deckId
    ) external view returns (DeckInfo memory);

    function getCollectionInfo(
        uint256 _deckId
    ) external view returns (CollectionInfo memory);

    function getAllowedTokens() external view returns (address[] memory);

    function getAllowedCollections() external view returns (address[] memory);

    function getAllowedNLBundles() external view returns (address[] memory);

    function getListedDecks() external view returns (uint256[] memory);
}
