// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/BundlesInterface.sol";

contract MockBundles is ERC721, Ownable, BundlesInterface {

    uint256 public bundleLpIdCounter;
    address public immutable dead;
    bool public paused;

    address[] public acceptableNFTsArray;
 
    mapping(address => bool) public isERC721Accepted;
    mapping(address => bool) public isERC721WithOwnerFees;
    mapping(uint256 => Bundle) private bundleLpIdToBundle;


    constructor() ERC721("Bundle NFT", "BUNDLE NFT") {
        dead = 0x000000000000000000000000000000000000dEaD;
        bundleLpIdCounter = 1;
    }

    function depositNFTs(address[] memory nftAddresses,  uint256[] memory ids, string memory bundleName) external {
        require(!paused, "Bundles contract is currently paused");
        require(ids.length <= 100, "Up to 100 nfts allowed");
        require(ids.length == nftAddresses.length, "Mismatched length");

        for(uint256 i = 0 ; i < ids.length; i++) {
            require(IERC721(nftAddresses[i]).ownerOf(ids[i]) == msg.sender, "You are not the owner");
            IERC721(nftAddresses[i]).transferFrom(msg.sender, address(this), ids[i]);
        }

        bundleLpIdToBundle[bundleLpIdCounter] = Bundle(
            bundleLpIdCounter, 
            bundleName, 
            ids.length, 
            nftAddresses, 
            ids
        );
        _mint(msg.sender, bundleLpIdCounter);
    }

   

    function withdrawNFTs(uint256 bundleLpId) external {
        require(IERC721(address(this)).ownerOf(bundleLpId) == msg.sender, "Not owner");
        IERC721(address(this)).transferFrom(msg.sender, dead, bundleLpId);
        for(uint256 i = 0 ; i < bundleLpIdToBundle[bundleLpId].ids.length; i++) {
            IERC721(bundleLpIdToBundle[bundleLpId].nftAddresses[i]).transferFrom(address(this), msg.sender, bundleLpIdToBundle[bundleLpId].ids[i]);
        }
    }

    function getBundle(uint256 bundleId) external view returns(uint256, string memory, address[] memory, uint256[] memory) {
        return (bundleLpIdToBundle[bundleId].bundleLpId, bundleLpIdToBundle[bundleId].name, bundleLpIdToBundle[bundleId].nftAddresses, bundleLpIdToBundle[bundleId].ids);
    }
}
