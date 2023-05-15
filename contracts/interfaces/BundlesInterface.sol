// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice This interface is for MockBundles contract.
interface BundlesInterface {
    struct Bundle {
        uint256 bundleLpId;
        string name;
        uint256 numberOfNFTs;
        address[] nftAddresses;
        uint256[] ids;
    }

    function getBundle(
        uint256 bundleId
    )
        external
        view
        returns (uint256, string memory, address[] memory, uint256[] memory);
}
