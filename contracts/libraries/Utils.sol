// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library Utils {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

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

    function updateAddressEnumerable(
        EnumerableSet.AddressSet storage _addressSet,
        address _arg,
        bool _isAdd
    ) internal {
        if (_isAdd) {
            require(!_addressSet.contains(_arg), "already added");
            _addressSet.add(_arg);
        } else {
            require(_addressSet.contains(_arg), "already removed");
            _addressSet.remove(_arg);
        }
    }

    function updateUintEnumerable(
        EnumerableSet.UintSet storage _uintSet,
        uint256 _arg,
        bool _isAdd
    ) internal {
        if (_isAdd) {
            require(!_uintSet.contains(_arg), "already added");
            _uintSet.add(_arg);
        } else {
            require(_uintSet.contains(_arg), "already removed");
            _uintSet.remove(_arg);
        }
    }

    function checkLimitConfig(
        uint256 _minAmount,
        uint256 _maxAmount
    ) internal pure {
        require(
            _minAmount > 1 && _maxAmount > _minAmount,
            "invalid config amount"
        );
    }
}
