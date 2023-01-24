// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/OpenerMintInterface.sol";
import "./interfaces/BundlesInterface.sol";

contract Bundles is ERC721, Ownable, BundlesInterface {

    uint256 public bundleLpIdCounter;
    address public immutable dead;
    bool public paused;

    address[] public acceptableNFTsArray;
 
    mapping(address => bool) public isERC721Accepted;
    mapping(address => bool) public isERC721WithOwnerFees;
    mapping(uint256 => Bundle) private bundleLpIdToBundle;

    function getBundleDistribution(uint256 tokenId) external view override returns(uint256[][] memory, address[][] memory, uint256) {
        return (bundleLpIdToBundle[tokenId].fees, bundleLpIdToBundle[tokenId].addresses, bundleLpIdToBundle[tokenId].numberOfNFTs);
    }
    

    event Deposit(uint256 indexed bundleLpId, address[] indexed nftAddress, uint256[] indexed ids);
    event Withdraw(uint256 indexed bundleLpId, address[] indexed nftAddress, uint256[] indexed ids);

    constructor() ERC721("Bundle NFT", "BUNDLE NFT") {
        dead = 0x000000000000000000000000000000000000dEaD;
        bundleLpIdCounter = 1;
    }

    function depositNFTs(address[] memory nftAddresses,  uint256[] memory ids, string memory bundleName) external {
        require(!paused, "Bundles contract is currently paused");
        require(ids.length <= 100, "Up to 100 nfts allowed");
        require(ids.length == nftAddresses.length, "Mismatched length");
        
        uint256[][] memory fees = new uint256[][](ids.length);
        address[][] memory addresses = new address[][](ids.length);

        for(uint256 i = 0 ; i < ids.length; i++) {
            require(isERC721Accepted[nftAddresses[i]], "NFT is not accepted");
            require(IERC721(nftAddresses[i]).ownerOf(ids[i]) == msg.sender, "You are not the owner");
            IERC721(nftAddresses[i]).transferFrom(msg.sender, address(this), ids[i]);
            if(isERC721WithOwnerFees[nftAddresses[i]]){

                (
                    uint256[] memory marketplaceFees, 
                    address[] memory marketplaceAddrs
                ) = OpenerMintInterface(nftAddresses[i]).getMarketplaceDistributionForERC721(ids[i]);
                fees[i] = marketplaceFees;
                addresses[i] = marketplaceAddrs;
            }
        }

        bundleLpIdToBundle[bundleLpIdCounter] = Bundle(
            bundleLpIdCounter, 
            bundleName, 
            ids.length, 
            nftAddresses, 
            ids, 
            fees, 
            addresses
        );
        _mint(msg.sender, bundleLpIdCounter);

        emit Deposit(bundleLpIdCounter++, nftAddresses, ids);
    }

    function addNftAddressAccepted(address nftAddress) external onlyOwner {
        isERC721Accepted[nftAddress] = true;
        acceptableNFTsArray.push(nftAddress);
    }

    function switchIsERC721WithOwnerFeesAccepted(address nftAddress) external onlyOwner {
        isERC721WithOwnerFees[nftAddress] = !isERC721WithOwnerFees[nftAddress];
    }

    function removeNftAddressAccepted(uint256 index) external onlyOwner {
        isERC721Accepted[acceptableNFTsArray[index]] = false;
        acceptableNFTsArray[index] =  acceptableNFTsArray[acceptableNFTsArray.length - 1];
        acceptableNFTsArray.pop();
    }


    function withdrawNFTs(uint256 bundleLpId) external {
        require(!paused, "Bundles contract is currently paused");
        require(IERC721(address(this)).ownerOf(bundleLpId) == msg.sender, "Not owner");
        IERC721(address(this)).transferFrom(msg.sender, dead, bundleLpId);
        for(uint256 i = 0 ; i < bundleLpIdToBundle[bundleLpId].ids.length; i++) {
            IERC721(bundleLpIdToBundle[bundleLpId].nftAddresses[i]).transferFrom(address(this), msg.sender, bundleLpIdToBundle[bundleLpId].ids[i]);
        }

        emit Withdraw(bundleLpId, bundleLpIdToBundle[bundleLpId].nftAddresses, bundleLpIdToBundle[bundleLpId].ids);
    }

    function getBundle(uint256 bundleId) external view returns(uint256, string memory, address[] memory, uint256[] memory) {
        return (bundleLpIdToBundle[bundleId].bundleLpId, bundleLpIdToBundle[bundleId].name, bundleLpIdToBundle[bundleId].nftAddresses, bundleLpIdToBundle[bundleId].ids);
    }

    function changePaused() external onlyOwner {
        paused = !paused;
    }

}
