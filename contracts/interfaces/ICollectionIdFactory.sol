// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICollectionIdFactory {
    function createNewCollectionId(
        address owner_,
        string memory name_,
        string memory symbol_
    ) external returns (address);
}