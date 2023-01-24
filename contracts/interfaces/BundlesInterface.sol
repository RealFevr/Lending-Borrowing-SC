// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface BundlesInterface {
    struct Bundle {
        uint256 bundleLpId;
        string name;
        uint256 numberOfNFTs;
        address[] nftAddresses;
        uint256[] ids;
        uint256[][] fees;
        address[][] addresses;
    }
    
    function getBundleDistribution(uint256 tokenId) external view returns(uint256[][] memory, address[][] memory, uint256);

    function getBundle(uint256 bundleId) external view returns(
        uint256, 
        string memory, 
        address[] memory, 
        uint256[] memory
    );
}