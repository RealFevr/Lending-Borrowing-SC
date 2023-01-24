// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOpenerRealFevrV2 {
    struct whitelist {
        bool whitelistEnabled;
        mapping(address => bool) isWhitelisted;
    }

    struct Pack {
        address buyToken;
        uint256 packPriceUSD; // price in USD (18 decimals)
        address NFTAddress;
        uint256 packId;
        uint256 nftAmount;
        uint256 initialNFTId;
        uint256 mintCount;
        uint256[] saleDistributionAmounts;
        address[] saleDistributionAddresses;
        // Marketplace
        // Catalog info
        string serie;
        string drop;
        string packType;
        bool opened;
        address buyer;
    }

    struct MultiPacksParam {
        address erc20;
        address NFTAddress;
        uint256 packsAmount;
        uint256 nftAmount;
        uint256 priceInUSD;
        string serie;
        string packType;
        string drop;
    }

    struct MintNFTCollectionParam {
        address collectionAddress;
        uint256[] collectionIds;
    }
    
    struct NFTTransferParam {
        address nftAddress;
        uint256[] ids;
        address[] recipients;
    }

    event PackCreated(uint256 packId, string indexed serie, string indexed packType, string indexed drop);
    event PackBought(address indexed by, uint256 indexed packId);
    event PackOffered(address indexed by, uint256 indexed packId);
    event PackOpened(address indexed by, uint256 indexed packId);
    event NftMinted(address indexed NFTAddress, uint256 indexed tokenId);
}