// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITreasury {
    /// @notice Set lendingMaster address.
    /// @dev Only owner can call this function.
    function setLendingMaster(address _lendingMaster) external;

    /// @notice Set DEX router address.
    /// @dev Only owner can call this function.
    function setDexRouter(address _dexRouter) external;

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
