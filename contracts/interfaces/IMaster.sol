// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMaster {

    struct ServiceFee {
        address paymentToken;
        uint256 feeAmount;
        string serviceFeeName;
        bool active;
        uint16 burnPercent;
    }

    /// @notice Set acceptable ERC20 token.
    /// @dev Only owner can call this function.
    /// @param _token The address of ERC20 token.
    /// @param _accept Status for accept or not.
    function setAcceptableERC20(address _token, bool _accept) external;

    /// @notice Set acceptable Opener/NFT.
    /// @dev Only owner can call this function.
    /// @param _opener The address of Opener/NFT.
    /// @param _accept The status for accept or not.
    function setAcceptableOpener(address _opener, bool _accept) external;

    /// @notice Set service fee.
    /// @dev Only owner can call this function.
    /// @param _paymentToken The address of payment token.
    /// @param _feeAmount The amount of service fee.
    /// @param _feeFlag Status fee is active or not.
    /// @param _feeName The service fee name.
    /// @param _burnPercent The percent to burn.
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external;

    /// @notice Linke service fee to an nft.
    /// @dev Only owner can call this function and service fee linked only once per nft.
    /// @param _serviceFeeId ServiceFee id.
    /// @param _nftAddress The address of nft.
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _nftAddress
    ) external;

    /// @notice Set deposit flag.
    /// @dev Only owner can call this function.
    /// @param _nftAddress The address of nft.
    /// @param _depositLimit The max deposit nft count.
    function setDepositFlag(
        address _nftAddress,
        uint256 _depositLimit
    ) external;

    function depositNFTs(
        address _nftAddress,
        address _tokenId
    ) external;

    function withdrawNFTs(
        uint256 _deckLpId
    ) external;

    function lend(
        address _paymentToken,
        uint256 _deckLpId,
        uint256 _dailyInterest,
        uint256 _prepayAmount,
        bool _prepay
    ) external;

    function borrow(
        uint256 _deckLpId
    ) external;

    function winningCalculation(
        address _lender,
        address _borrower,
        uint256 _deckLpId,
        uint256[] memory _gameIds
    ) external;

    function claimWinnings(uint256 _gameIds) external;

    function claimInterest(uint256 _deckLpId) external;

    function buybackFeeTake(
        address _token,
        bool _turningStatus
    ) external;

    function setBuybackFee(
        address _token,
        uint256 _buybackFee
    ) external;

    function getReceiptDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (
        uint256 duration, 
        uint256 prepay, 
        uint256 interest, 
        uint256 winDistribution
    );

    function getDeckLpInfo(
        uint256 _deckLpId
    ) external view returns (address nftAddress, uint256[] memory tokenIds);

    function getAllDeckCount() external view returns (uint256);

    function getOpenerAddress() external view returns (address);

    function getBundlesAddress() external view returns (address);

    function getServiceFeeInfo(uint256 _serviceFeedId) external view returns (uint256);

    function getLockedERC20(address _token) external view returns (uint256);

    event AcceptableERC20Set(address indexed token, bool status);

    event AcceptableOpenerSet(address indexed opener, bool status);

    event ServiceFeeSet(address paymentToken, uint256 feeAmount, bool feeFlag, string feeName, uint16 burnPercent);

    event ServiceFeeLinked(uint256 serviceFeeId, address indexed nftAddress);

    event DepositFlagSet(address indexed nftAddress, uint256 depositLimit);
}