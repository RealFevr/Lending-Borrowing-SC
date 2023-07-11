// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IUniswapRouter02.sol";
import "./interfaces/IWBNB.sol";

contract Treasury is Ownable, ITreasury {
    using SafeERC20 for IERC20;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public fevrToken;

    address public dexRouter;

    address public lendingMaster;

    uint16 public FIXED_POINT = 1000;

    modifier onlyLendingMaster() {
        require(msg.sender == lendingMaster, "only lendingMaster");
        _;
    }

    constructor(address _fevrToken, address _dexRouter) {
        require(_fevrToken != address(0), "zero fevr token address");
        require(_dexRouter != address(0), "zero dex router address");
        fevrToken = _fevrToken;
        dexRouter = _dexRouter;
    }

    /// @inheritdoc ITreasury
    function setLendingMaster(address _lendingMaster) external onlyOwner {
        require(_lendingMaster != address(0), "zero lendingMaster address");
        lendingMaster = _lendingMaster;
    }

    /// @inheritdoc ITreasury
    function takeServiceFee(
        address _paymentToken,
        uint256 _amount,
        bool _burnFlag
    ) external payable override onlyLendingMaster {
        uint256 swappedAmount = _amount;
        if (_paymentToken != fevrToken) {
            address WETH = IUniswapV2Router02(dexRouter).WETH();
            address[] memory path;
            if (_paymentToken == address(0) || _paymentToken == WETH) {
                if (_paymentToken == address(0))
                    IWBNB(WETH).deposit{value: _amount}();
                path = new address[](2);
                path[0] = WETH;
                path[1] = fevrToken;
                _paymentToken = WETH;
            } else {
                path = new address[](3);
                path[0] = _paymentToken;
                path[1] = WETH;
                path[2] = fevrToken;
            }

            uint256 beforeBal = IERC20(fevrToken).balanceOf(address(this));
            IERC20(_paymentToken).approve(dexRouter, _amount);
            IUniswapV2Router02(dexRouter)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
            uint256 afterBal = IERC20(fevrToken).balanceOf(address(this));
            swappedAmount = afterBal - beforeBal;
        }

        if (_burnFlag) {
            IERC20(fevrToken).safeTransfer(DEAD, swappedAmount);
        }
    }

    /// @inheritdoc ITreasury
    function withdrawToken(address _token) external override onlyOwner {
        address sender = msg.sender;
        require(
            (_token == address(0) && address(this).balance > 0) ||
                (IERC20(_token).balanceOf(address(this)) > 0),
            "no withdrawable amount"
        );
        uint256 claimableAmount;
        if (_token == address(0)) {
            claimableAmount = address(this).balance;
            _transferBNB(sender, claimableAmount);
        } else {
            claimableAmount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(owner(), claimableAmount);
        }

        emit TokenWithdrawn(_token, claimableAmount);
    }

    receive() external payable {}

    function _transferBNB(address _to, uint256 _amount) internal {
        require(_amount > 0, "invalid send BNB amount");
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "sending BNB failed");
    }
}
