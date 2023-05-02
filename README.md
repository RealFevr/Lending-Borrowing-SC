# realfevr-lending-borrowing-sc

Contract that contains borrowing, lending and marketplace.

# Goal

The goal of Lending and Borrowing is to allow users to lend and borrow bundles of NFTs. 

# How it works

The borrowing and lending follows this steps:

1. Deploy collectionManager + serviceManager,
2. Deploy deckMaster,
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

Bundle NFTs together. Lend and borrow deckLps.

### Structure

    contract DeckMaster is ERC721Enumerable, ERC721Holder, Ownable, IDeckMaster {
    using SafeERC20 for IERC20;
    
    /// The information of ServiceFee by serviceFeeId.
    mapping(uint256 => ServiceFee) private serviceFees;

    /// @dev ServiceFee for accepted collection.
    mapping(address => uint256) private linkServiceFees;
    
    /// @dev Locked token amount for certain token.
    mapping(address => uint256) private lockedTokenAmount;

    /// @dev The fee infomation for buyback.
    mapping(address => BuyBackFee) private buybackFees;

    /// @dev The claimable $Fevr token amount comes from winning games.
    mapping(address => mapping(uint256 => uint256)) public claimableAmount;

    /// The address of collectionManager contract.
    ICollectionManager public collectionManager;

    /// @dev The address of serviceManager contract.
    IServiceManager public serviceManager;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @dev The address of $Fevr token.
    address public baseToken;

    /// @dev The address of uniswap router.
    address public dexRouter;

    /// @dev total DeckLP count that exist.
    uint256 public totalDeckLPCnt;

    /// @dev The id of ServiceFee.
    uint256 public serviceFeeId;

    /// @dev The id of deckLpId. deckLpId = tokenId.
    uint256 public deckLpId;

### Constructor 

    constructor (
        address _baseToken, // the token for the lending/borrowing associated to a specific deckMaster contract
        address _collectionManager, // the collection manager contract address
        address _serviceManager, // the service manager contract address
        address _dexRouter // the dex router address for buy n' burn
        

### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setCollectionAmountForBundle  | Sets/change the total nft amount for each bundle | Admin |
| setAcceptableERC20  | Sets the accepted ERC20s | Admin |
| getAllowedTokens  | Checks the accepted ERC20s | Public |
| getAllowedCollections  | Checks the accepted collection addresses | Public |
| getAllowedBundles  | Checks the accepted bundles addresses | Public |
| setAcceptableCollections  | sets the accepted collections addresses | Admin |
| setAcceptableBundles  | sets the accepted bundles addresses | Admin |
| setServiceFee  | Sets the serviceFee charged by RealFevr | Admin |
| linkServiceFee  | Links service fee to a collection by address | Admin |
| setDepositFlag  | Sets the flag for deposits by address and limit | Admin |
| depositCollections  | creates and deposits the bundle, depositor gets deckLp  | Public |
| depositBundle  | Gets the information on the bundle, depositor gets deckLp  | Public |
| withdrawCollections  | If the owner is the depositer of collection/bundle then he can withdraw  | Public |
| lend  | lends a deckLp | Public |
| borrow  | lends a deckLp  | Public |
| winningCalculation  | calculates winnings for deckLp | Admin |
| claimWinnings  | let's the borrower and lender claim winnings | Public |
| claimInterest  | let's the lender claim interest | Public |
| buybackFeeTake  | flag to activate the buy  back fee | Public |
| setBuybackFee  | creates a buy back and burn fee for certain erc20 | Public |
| getReceiptDeckLpInfo  | checks the receipt of deckLp information | Public |
| getDeckLpInfo  | checks the deckLp information | Public |
| getAllDeckCount  | checks the deckLp information | Public |
| getServiceFeeInfo  | Sets acceptable NFT collection addresses to create a bundle | Admin |
| getLockedERC20  | Sets acceptable bundle addresses from bundles contract | Admin |

### Logic

- Set the accepted NFT contracts (collections).
- Set the accepted Bundle contracts (bundle).
- Set the accepted ERC20s.
- Let users deposit NFTs or Bundles lend, borrow and receive a receipt (deckLp).
- Each bundle for lending has its own rules in terms of pre-payment, fees, etc.

## CollectionManager

Bundle NFTs together.

### Structure

    contract CollectionManager is Ownable, ICollectionManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedBundles;

    mapping(address => uint256) public depositLimitations;

    address public deckMaster;
    uint256 public collectionAmountForBundle = 50;

    modifier onlyDeckMaster {
        require (msg.sender == deckMaster, "Only DeckMaster");
        _;
    }

### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setDeckMaster  | Sets/change he Deck master contract address | Admin |
| setCollectionAmountForBundle  | Sets the nft amount required to form a bundle | Admin |
| setAcceptableERC20  | Checks the accepted ERC20s | Public |
| setAcceptableCollections  | Checks the accepted collection addresses | Public |
| setAcceptableBundle  | Checks the accepted bundles addresses | Public |
| setDepositFlag  | Sets the flag for deposits by address and limit | Admin |
| depositCollections  | creates and deposits the bundle, depositor gets deckLp  | Public |
| isAllowedToken  | checks if a token is accepted  | Public |
| checkAllowedCollection  | Checks allowed collections  | Public |
| checkCollectionAvailableForDeposit  | Checks if a collection and specific ndts are available for lending | Public |
| getAllowedTokens  | Checks the accepted ERC20s  | Public |
| getAllowedCollections  | Checks the accepted collections | Admin |
| getAllowedBundles  | Checks the accepted bundles | Public |

### Logic

- Set the deck master contraact (address).
- Set the accepted NFT contracts (collections).
- Set the accepted Bundle contracts (bundle).
- Set the accepted ERC20s.
- Let users deposit NFTs or Bundles lend, borrow and receive a receipt (deckLp).
- Each bundle for lending has its own rules in terms of pre-payment, fees, etc.

## ServiceManager

Sets the marketplace rules

### Structure

    contract ServiceManager is Ownable, IServiceManager {

    mapping(uint256 => DeckLPInfo) private deckLpInfos;
    mapping(uint256 => LendInfo) private lendInfos;

    address public deckMaster;
    
    modifier onlyDeckMaster {
        require (msg.sender == deckMaster, "Only DeckMaster");
        _;
    }


### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setDeckMaster  | Sets/change he Deck master contract address | Admin |
| addDepositedCollections  | Sets the nft amount required to form a bundle | Admin |
| addDepositedBundle  | Checks the accepted bundles addresses | Public |
| removeWithdrawedCollections  | removes withdrawed collections from contract | Admin |
| listDeckLpLend  | Lends deckLp | Public |
| borrowDeckLp  | Borrows deckLp  | Public |
| checkDeckLpAvailableForClaimInterest  | Checks if a deckLp can claim interest  | Public |
| getDeckLendInfo  | checks deckLp by deckLpId| Public |
| isLendDeckLp  | Checks if a deck is being lent out | Public |
| getReceiptDeckLpInfo  | Checks the receipt deckLp information | Admin |
| getDeckLpInfo  | Checks the deckLp information (borrower, lender, winnings) | Public |

### Logic

- Set the deck master contraact (address).
- Set the accepted NFT contracts (collections).
- Set the accepted Bundle contracts (bundle).
- Let users deposit NFTs or Bundles lend, borrow and receive a receipt (deckLp).
- Each bundle for lending has its own rules in terms of pre-payment, fees, etc.
