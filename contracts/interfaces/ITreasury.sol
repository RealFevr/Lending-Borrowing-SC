// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITreasury {
    /// @notice Set lendingMaster address.
    /// @dev Only owner can call this function.
    function setLendingMaster(address _lendingMaster) external;

    /// @notice Take service fee.
    /// @dev Only lendingMaster can call this function.
    function takeServiceFee(
        address _paymentToken,
        uint256 _amount,
        uint16 _burnPercent,
        uint16 _buybackFeeRate
    ) external payable;

    /// @notice withdraw accumulated token.
    /// @dev Only owner can call this function.
    function withdrawToken(address _token) external;

    event TokenWithdrawn(address indexed token, uint256 amount);
}
