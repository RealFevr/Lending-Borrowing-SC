# realfevr-lending-borrowing-sc

Contract that contains borrowing, lending and marketplace.

# Goal

The goal of Lending and Borrowing is to allow users to lend and borrow bundles of NFTs. 

# How it works

The borrowing and lending follows this steps:

1. Deploy deckMaster,
2. Deploy collectionManager + serviceManager
3. Configure contracts (approved tokens, approved bundles, serviceFee, etc)

**The lender can deposit NFTs and create the bundle in the contract, or deposit a previously created bundle in the bundle smart contract.**

## Lender steps:

1. Pick the bundle to lend and choose the requirements: duration, fee, winnings share.
2. Or, create the bundle directly when depositing nfts.
3. Approve contract and deposit the bundle.
4. Claim rewards.
5. Retrieve bundle from contract.

## Borrower steps

1. Choose a bundle to borrow.
2. Approve the contract and have the necessary FEVR to complete the transaction.
3. Borrow the selected bundle and receive an token that represents the bundle borrowed (deckLp).
4. When you borrow, pay the fees and prepayment (if any).
5. When you win a portion of the winnings can be claimed by lender.

# Bundles structure

    struct Bundle {
        uint256 bundleLpId; // the bundle identifier. works similarly to LP tokens, as it represents the underlying assets
        string name; // the name of the bundle as it can be used as a deck in the NFT web3 games
        uint256 numberOfNFTs; // the total number of NFTs in the bundle. Max=50.
        address[] nftAddresses; // the ERC721 contract address of the NFTs added. Bundles supports multiple contracts.
        uint256[] ids; // the NFTs Ids.
        uint256[][] fees; // the fees associated to the NFTs. These are automatically populated.
        address[][] addresses; // the addresses that receive the fees. These are automatically populated.

# Fees 

The only fees that exist are service fees set by realfevr. It is a fee on all borrowing transactions. 

# Winnings Share

The winningsShare represents how much is distributed to the lender per game win. 

# Pre Payment

The pre-payment is a fee that can be added by the lender that the borrower must pay when borrowing the bundle.

# Functions & Logic 

Below you find the list of functions and the purpose of each, as well as logic tests.

## DeckMaster

Bundle NFTs together.

### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setServiceFee  | Sets the serviceFee charged by RealFevr | Admin |
| linkServiceFee  | Links service fee to a collection by address | Admin |
| setDepositFlag  | Sets the flag for deposits by address and limit | Admin |
| depositCollections  | creates and deposits the bundle  | Public |
| depositBundle  | Gets the information on the bundle  | Public |
| setAcceptableCollections  | Sets acceptable NFT collection addresses to create a bundle | Admin |
| setAcceptableBundle  | Sets acceptable bundle addresses from bundles contract | Admin |

### Logic

- Set the accepted NFT contracts (collections).
- Set the accepted Bundle contracts (bundle).
- Set the accepted ERC20s.
- Let users deposit NFTs or Bundles lend, borrow and receive a receipt (deckLp).
- Each bundle for lending has its own rules in terms of pre-payment, fees, etc.

