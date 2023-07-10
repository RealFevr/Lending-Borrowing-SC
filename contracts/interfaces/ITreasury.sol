// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITreasury {
    /// @notice Set lendingMaster address.
    /// @dev Only owner can call this function.
    function setLendingMaster(address _lendingMaster) external;

    /// @notice Set slippage tolerance.
    /// @notice We are calculating `amountWithSlippage = expectedAmount * slippage / 1000.
    /// @notice So, if we set slippage to 1000, it means no slippage at all, because 1000 / 1000 = 1
    /// @notice If we want a 0.3% slippage, we need to pass the value 997 to the function.
    /// @dev Only owner can call this function.
    function setSlippage(uint256 _slippage) external;

    /// @notice Take service fee.
    /// @dev Only lendingMaster can call this function.
    function takeServiceFee(
        address _paymentToken,
        uint256 _amount,
        bool _burnFlag
    ) external payable;

    /// @notice withdraw accumulated token.
    /// @dev Only owner can call this function.
    function withdrawToken(address _token) external;

    event TokenWithdrawn(address indexed token, uint256 amount);
}
