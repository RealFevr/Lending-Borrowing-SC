// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
interface OpenerMintInterface is IERC721 {

    struct MarketplaceDistribution {
        uint256[] marketplaceDistributionAmounts;
        address[] marketplaceDistributionAddresses;
    }

    function mint(uint256 tokenId) external;
    function getLastNFTID() external returns(uint256);
    function setLastNFTID(uint256 newId) external;

    function setRegisteredID(address _account, uint256 _id) external;
    function pushRegisteredIDsArray(address _account, uint256 _id) external;
    function exists(uint256 _tokenId) external view returns (bool);
    function alreadyMinted(uint256 _tokenId) external view returns (bool);
    function mintedCounts(address _account) external view returns (uint256);
    function getRegisteredIDs(address _account) external view returns (uint256[] memory);
    
    function setMarketplaceDistribution(uint256[] memory amounts, address[] memory addresses, uint256 _id) external;
    function getMarketplaceDistributionForERC721(uint256 _tokenId) external view returns(uint256[] memory, address[] memory);
}