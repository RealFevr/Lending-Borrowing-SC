// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDeckMaster {

    struct ServiceFee {
        address paymentToken;
        uint256 feeAmount;
        string serviceFeeName;
        bool active;
        uint16 burnPercent;
    }

    struct WinningDistribution {
        uint16 lenderRate;
        uint16 borrowerRate;
        uint16 burnRate;
    }

    struct DeckLPInfo {
        address nftAddress;
        uint256 tokenId;
        bool listedLend;
        bool lend;
        bool lendDeckLp;
    }

    struct LendInfo {
        address lender;
        address borrower;
        address paymentToken;
        uint256 deckLpId;
        uint256 dailyInterest;
        uint256 prepayAmount;
        uint256 borrowedTimestamp;
        uint256 borrowDuration;
        bool prepay;
    }

    /// @notice Set acceptable ERC20 token.
    /// @dev Only owner can call this function.
    /// @param _token   The address of ERC20 token.
    /// @param _accept  Status for accept or not.
    function setAcceptableERC20(address _token, bool _accept) external;

    /// @notice Set acceptable Opener.
    /// @dev Only owner can call this function.
    /// @param _opener The address of Opener.
    /// @param _accept The status for accept or not.
    function setAcceptableOpener(address _opener, bool _accept) external;

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

    /// @notice Linke service fee to an nft.
    /// @dev Only owner can call this function and service fee linked only once per nft.
    /// @param _serviceFeeId    ServiceFee id.
    /// @param _nftAddress      The address of nft.
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _nftAddress
    ) external;

    /// @notice Set deposit flag.
    /// @dev Only owner can call this function.
    /// @param _nftAddress      The address of nft.
    /// @param _depositLimit    The max deposit nft count.
    function setDepositFlag(
        address _nftAddress,
        uint256 _depositLimit
    ) external;

    /// @notice Deposit NFT and get deckLp.
    /// @param _nftAddress The address of nft.
    /// @param _tokenId    NFT token id.
    function depositNFTs(
        address _nftAddress,
        uint256 _tokenId
    ) external;

    /// @notice Withdraw NFTs by burning deckLp.
    /// @param _deckLpId The id of deckLp.
    function withdrawNFTs(
        uint256 _deckLpId
    ) external;

    /// @notice Lend deck/moment.
    /// @param _paymentToken    The address of payment token.
    /// @param _deckLpId        The token id of deck lp.
    /// @param _dailyInterest   The token amount of daily interest.
    /// @param _prepayAmount    The token amount for prepay.
    /// @param _prepay          Status for prepay is required or not.
    /// @param _winDist         Winning Distribution info.
    function lend(
        address _paymentToken,
        uint256 _deckLpId,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        bool _prepay,
        WinningDistribution memory _winDist
    ) external;

    /// @notice Borrow NFT with deckLp.
    /// @param _deckLpId The deckLp token id to borrow.
    function borrow(
        uint256 _deckLpId
    ) external;

    /// @notice Let the owner tell the contract the total winnings of a certain deckLp.
    /// @dev Only owner can call this function.
    /// @param _lender      The address of lender for certain deckLp.
    /// @param _borrower    The address of borrower for certain deckLp.
    /// @param _deckLpId    The deckLp token id.
    /// @param _gameIds     The array of game id.
    function winningCalculation(
        address _lender,
        address _borrower,
        uint256 _deckLpId,
        uint256[] memory _gameIds
    ) external;

    /// @notice Let lender & borrower claim he winnings related to a deckLp.
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
        uint256 _buybackFee
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
    /// @return nftAddress  The address of nft.
    /// @return tokenIds    The array of token ids.
    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (address nftAddress, uint256[] memory tokenIds);

    /// @notice Get deckLp count.
    /// @return Total deckLp count.
    function getAllDeckCount() external view returns (uint256);

    /// @notice Get opener address.
    function getOpenerAddress() external view returns (address[] memory);

    /// @notice Get contract address of bundles.
    function getBundlesAddress() external view returns (address[] memory);

    /// @notice Get if service fee is active and the total amount per serviceFeeId.
    function getServiceFeeInfo(uint256 _serviceFeedId) external view returns (uint256);

    /// @notice Get how many tokens are locked by borrowers.
    function getLockedERC20(address _token) external view returns (uint256);

    event AcceptableERC20Set(address indexed token, bool status);

    event AcceptableOpenerSet(address indexed opener, bool status);

    event AcceptableBundleSet(address indexed bundle, bool status);

    event ServiceFeeSet(address paymentToken, uint256 feeAmount, bool feeFlag, string feeName, uint16 burnPercent);

    event ServiceFeeLinked(uint256 serviceFeeId, address indexed nftAddress);

    event DepositFlagSet(address indexed nftAddress, uint256 depositLimit);

    event Deposit(address indexed nftAddress, uint256 tokenId, uint256 deckLpId);

    event Withdraw(address indexed withdrawer, uint256 deckLpId);

    event Lend(address indexed lender, uint256 deckLpId);
}