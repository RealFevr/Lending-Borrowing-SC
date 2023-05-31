// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MockCollectionId is Ownable, ERC721URIStorage {

    uint256 private lastTokenId;

    constructor() ERC721("Drop#1", "#1") {
        lastTokenId = 1;
    }

    function mint(address account, uint256 amount) external {
        for (uint256 i = 0; i < amount; i ++) {
            _safeMint(account, lastTokenId ++);
        }
    }
}
