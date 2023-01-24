// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMaster.sol";

contract Master is Ownable, IMaster {
    mapping(address => bool) public isAllowedToken;
    mapping(address => bool) public isAllowedOpener;
    mapping(uint256 => ServiceFee) private serviceFees;
    mapping(address => uint256) private linkServiceFees;
    mapping(address => uint256) private depositLimitations;

    uint256 private serviceFeeId;

    constructor () {
        serviceFeeId = 1;
    }
    
    /// @inheritdoc IMaster
    function setAcceptableERC20(address _token, bool _accept) external onlyOwner {
        require (_token != address(0), "zero address");
        isAllowedToken[_token] = _accept;
        emit AcceptableERC20Set(_token, _accept);
    }

    /// @inheritdoc IMaster
    function setAcceptableOpener(address _opener, bool _accept) external onlyOwner {
        require (_opener != address(0), "zero address");
        isAllowedOpener[_opener] = _accept;
        emit AcceptableOpenerSet(_opener, _accept);
    }

    /// @inheritdoc IMaster
    function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        string memory _feeName,
        uint16 _burnPercent
    ) external onlyOwner {
        require (_paymentToken != address(0), "zero payment token address");
        require (isAllowedToken[_paymentToken], "not acceptable payment token address");
        serviceFees[serviceFeeId ++] = ServiceFee(_paymentToken, _feeAmount, _feeName, _feeFlag, _burnPercent);
        emit ServiceFeeSet(_paymentToken, _feeAmount, _feeFlag, _feeName, _burnPercent);
    }

    /// @inheritdoc IMaster
    function linkServiceFee(
        uint256 _serviceFeeId,
        address _nftAddress
    ) external onlyOwner {
        require (_serviceFeeId != 0 && _serviceFeeId < serviceFeeId, "invalid serviceFeeId");
        require (_nftAddress != address(0) && isAllowedOpener[_nftAddress], "not acceptable nft address");
        require (linkServiceFees[_nftAddress] == 0, "already linked to a fee");
        linkServiceFees[_nftAddress] = _serviceFeeId;
        emit ServiceFeeLinked(_serviceFeeId, _nftAddress);
    }

    /// @inheritdoc IMaster
    function setDepositFlag(
        address _nftAddress,
        uint256 _depositLimit
    ) external onlyOwner {
        require (_nftAddress != address(0) && isAllowedOpener[_nftAddress], "invalid nft address");
        depositLimitations[_nftAddress] = _depositLimit;
        emit DepositFlagSet(_nftAddress, _depositLimit);
    }

    
}