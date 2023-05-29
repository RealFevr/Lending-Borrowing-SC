// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Utils {
    function genUintArrayWithArg(
        uint256 _arg
    ) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = _arg;
        return array;
    }

    function genAddressArrayWithArg(
        address _arg
    ) internal pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = _arg;
        return array;
    }

    function checkAddressArray(
        address[] memory _addressArray
    ) internal pure returns (uint256 length) {
        length = _addressArray.length;
        require(length > 0, "invalid length array");
    }

    function checkUintArray(
        uint256[] memory _uintArray
    ) internal pure returns (uint256 length) {
        length = _uintArray.length;
        require(length > 0, "invalid length array");
    }

    function compareAddressArrayLength(
        address[] memory _addressArray,
        uint256 _length
    ) internal pure returns (uint256 length) {
        length = _addressArray.length;
        require(length > 0, "invalid length array");
        require(length == _length, "mismatch length array");
    }

    function compareUintArrayLength(
        uint256[] memory _uintArray,
        uint256 _length
    ) internal pure returns (uint256 length) {
        length = _uintArray.length;
        require(length > 0, "invalid length array");
        require(length == _length, "mismatch length array");
    }
}
