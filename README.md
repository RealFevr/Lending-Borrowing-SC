# realfevr-fusion-sc
NFT Fusion smart contract

# How to use

- Deploy nftId (or opener v2)
- Deploy Fusion
- Deploy FusionNFT (link to fusion)
- Approve Fusion on ERC20 
- Approve Fusion on NFTId or Openerv2
- Run function ***setFusionNFT***: link to fusionNFT contract
- Run function ***fillTier one*** to ***fillTier four***: each tier matches Common, Special, Epic, Legendary
- add name of player
- add array of NFTIds of the player (ex [1,100,245,124291,123])
- Run ***editTierTokens*** if you need to change the FEVR charged per level
- Run ***fuse*** 
- add nftAddress 
- add array of tokenIds to fuse
- add names (should be the same)
- add amount (check ***getTierToTokens*** function)

# How it works

The goal of fusion is to fuse an array of tokenIds (NFTs). The new Fused NFT contain the properties of the old NFT, such as the marketplace fee distribution and addresses. 

Fusion is divided into the following levels:

| Tier  | Max per Player | Max Fused LvL1 | Max Fused LvL2 | Max Fused LvL3 | Max Fused LvL4 | Max Fused LvL5 |
| ------------- | ------------- |------------- |------------- |------------- |------------- |------------- |
| 1 - Common  | 5000 | 1000 | 200 | 50 | 12 | 4 |
| 2- Special  | 2500  | 625 | 156 | 39 | 13 | 4 |
| 3 - Epic  | 500  | 166 | 55 | 18 | 9 | 4 |
| 4 - Legendary  | 50  | 25 | 12 | 6 | 3 | 1 |

# Functions

Below you find the list of functions and the purpose of each

## Fusion

| Function  | Purpose |
| ------------- | ------------- |
| setFusionNFT  | Sets fusionNFT address |
| fillTier one - four  | Fills tiers with tokenIds to be fused  |
| editTierTokens  | Edit tier fees  |
| fuse  | Fuse tokenIds  |
| getTierToTokens  | What is the fee of a tier |
| getTierFromNameAndId  | What is the tier by name and tokenId |
| getTierFromNameAndIdFused  | What is the tier by name and fused tokenId  |

## FusionNFT (pushed by Fusion contract)

| Function  | Purpose |
| ------------- | ------------- |
| setTierRangesForTier  | Sets the ranges of tokenIds for each fused tier  |
| mint  | Mints fused nfts  |
