# realfevr-lending-borrowing-sc

Contract that contains borrowing, lending and marketplace.

# Goal

The goal of Lending and Borrowing is to allow users to lend and borrow bundles of NFTs or individual NFTs. 

# How it works

The borrowing and lending follows this steps:

1. Deploy LendingMaster.sol and Treasury.sool,
2. Configure contracts (approved tokens, approved bundles, serviceFee, etc)

# Types of deposits

There are three types of bundles that are accepted to the LendingMaster contract.

## Collections

Represent bundles that are created through the Lending contract. A user deposits one or more NFTs adn the LBundle is created.

### depositCollections function

    function depositCollection(
        address[] memory _collections,
        uint256[] memory _tokenIds,
        bool _isLBundleMode
    ) external override {
        address sender = msg.sender;
        uint256 length = Utils.compareAddressArrayLength(
            _collections,
            _tokenIds.length
        );
        require(
            !_isLBundleMode ||
                (maxAmountForBundle >= length && length >= minAmountForBundle),
            "invalid deposit amount"
        );
        require(!_isLBundleMode || LBundleMode, "LBundleMode disabled");

        for (uint256 i = 0; i < length; i++) {
            address collection = _collections[i];
            uint256 tokenId = _tokenIds[i];
            _checkCollection(collection, tokenId);
            IERC721(collection).transferFrom(sender, address(this), tokenId);

            if (!_isLBundleMode) {
                depositedIdsPerUser[sender].add(depositId);
                depositInfo[depositId] = DepositInfo(
                    sender,
                    address(0),
                    0,
                    0,
                    Utils.genUintArrayWithArg(depositId)
                );
                collectionInfoPerDeck[depositId] = CollectionInfo(
                    Utils.genAddressArrayWithArg(collection),
                    Utils.genUintArrayWithArg(tokenId)
                );
                depositedIdsPerUser[sender].add(depositId);
                totalDepositedIds.add(depositId);
                emit SingleCollectionDeposited(
                    collection,
                    tokenId,
                    depositId++
                );
            }
        }

        if (_isLBundleMode) {
            depositedIdsPerUser[sender].add(depositId);
            depositInfo[depositId] = DepositInfo(
                sender,
                address(0),
                0,
                0,
                Utils.genUintArrayWithArg(depositId)
            );
            collectionInfoPerDeck[depositId] = CollectionInfo(
                _collections,
                _tokenIds
            );
            depositedIdsPerUser[sender].add(depositId);
            totalDepositedIds.add(depositId);

            emit LBundleDeposited(_collections, _tokenIds, depositId++);
        }
    }

## LBundles

Represents bundles that were created by the LendingMaster contract. 

### LBundles Function

function depositNLBundle(
        address _bundleAddress,
        uint256 _tokenId
    ) external override {
        address sender = msg.sender;
        require(
            allowedNLBundles.contains(_bundleAddress),
            "not allowed bundle"
        );
        require(
            IERC721(_bundleAddress).ownerOf(_tokenId) == sender,
            "not bundle owner"
        );

        (, , address[] memory collections, ) = BundlesInterface(_bundleAddress)
            .getBundle(_tokenId);

        require(
            collections.length >=
                depositLimitations[_bundleAddress].minAmount &&
                collections.length <=
                depositLimitations[_bundleAddress].maxAmount,
            "exceeds to depositLimitation"
        );

        IERC721(_bundleAddress).transferFrom(sender, address(this), _tokenId);

        depositedIdsPerUser[sender].add(depositId);
        depositInfo[depositId] = DepositInfo(
            sender,
            address(0),
            0,
            0,
            Utils.genUintArrayWithArg(depositId)
        );

        collectionInfoPerDeck[depositId] = CollectionInfo(
            Utils.genAddressArrayWithArg(_bundleAddress),
            Utils.genUintArrayWithArg(_tokenId)
        );

        depositedIdsPerUser[sender].add(depositId);
        totalDepositedIds.add(depositId);

        emit NLBundleDeposited(_bundleAddress, _tokenId, depositId++);
    }

    /// @inheritdoc ILendingMaster
    function mergeDeposits(uint256[] memory _depositIds) external override {
        address sender = msg.sender;
        uint256 length = Utils.checkUintArray(_depositIds);
        require(
            maxAmountForBundle >= length && length >= minAmountForBundle,
            "invalid merge amount"
        );
        require(LBundleMode, "LBundleMode disabled");
        for (uint256 i = 0; i < length; i++) {
            uint256 _depositId = _depositIds[i];
            DepositInfo storage info = depositInfo[_depositId];
            require(
                depositedIdsPerUser[sender].contains(_depositId),
                "invalid depositId"
            );
            require(
                info.borrower == address(0) || info.endTime < block.timestamp,
                "borrowed depositId"
            );
            require(
                !listedIdsPerUser[sender].contains(_depositId),
                "listed for lend"
            );
            depositedIdsPerUser[sender].remove(_depositId);
            totalDepositedIds.remove(_depositId);
        }
        depositedIdsPerUser[sender].add(depositId);
        listedIdsPerUser[sender].add(depositId);
        depositInfo[depositId] = DepositInfo(
            sender,
            address(0),
            0,
            0,
            _depositIds
        );
        totalDepositedIds.add(depositId++);
        emit LBundleMade(_depositIds);
    }

## NLBundles 

Represents bundles that were created outside the LendingMaster contract (i.e., RealFevr Marketplace bundles).

## NLBundles Function

    function setNLBundles(
        address[] memory _nlBundles,
        bool _accept
    ) external override onlyOwner {
        uint256 length = Utils.checkAddressArray(_nlBundles);
        for (uint256 i = 0; i < length; i++) {
            Utils.updateAddressEnumerable(
                allowedNLBundles,
                _nlBundles[i],
                _accept
            );
        }

        emit NLBundlesSet(_nlBundles, _accept);
    }

## Lender steps:

1. Pick the bundle to lend and choose the requirements: duration, prepay fee, winnings share.
2. Or, create the bundle directly when depositing nfts.
3. Approve contract and deposit the bundle.
4. Claim rewards.
5. Retrieve bundle from contract.

## Borrower steps

1. Choose a bundle to borrow.
2. Approve the contract and have the necessary FEVR to complete the transaction.
3. Borrow the selected bundle,
4. When you borrow, pay the fees and prepayment (if any).
5. When you win a game, a portion of the winnings can be claimed by lender.

# Fees 

The only fees that exist are service fees set by realfevr. It is a fee on all borrowing transactions. 

## Types of Fees

There are two main types of fees:

1. Game fees: a % charged by RF on the winnings from games.
2. Service fee: a fixed fee charged by RF when borrowing.

### setRFGameFee Function

     function setRFGameFee(uint16 _gameFee) external override onlyOwner {
        require(_gameFee <= FIXED_POINT, "invalid gameFee rate");
        RF_GAME_FEE = _gameFee;
    }

### setServiceFee function

     function setServiceFee(
        address _paymentToken,
        uint256 _feeAmount,
        bool _feeFlag,
        bool _burnFlag,
        string memory _feeName
    ) external override onlyOwner {
        _checkAcceptedToken(_paymentToken);
        require(_feeAmount > 0, "invalid feeAmount");
        serviceFees[_paymentToken] = ServiceFee(
            _paymentToken,
            _feeAmount,
            _feeName,
            _burnFlag,
            _feeFlag
        );

        emit ServiceFeeSet(
            _paymentToken,
            _feeAmount,
            _feeFlag,
            _burnFlag,
            _feeName
        );
    }

# Winnings Share

The winningsShare represents how much is distributed to the lender per game win. 

# Pre Payment

The pre-payment is a fee that can be added by the lender that the borrower must pay when borrowing the bundle.

# Functions & Logic 

Below you find the list of functions and the purpose of each, as well as logic tests.   

## LendingMaster.sol 

Borrow and Lend NFTs and Bundles.

### Constructor

    contract LendingMaster is ERC721Holder, Ownable, ILendingMaster {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private allowedTokens;
    EnumerableSet.AddressSet private allowedCollections;
    EnumerableSet.AddressSet private allowedNLBundles;

    /// @notice Deposited depositIds totally.
    EnumerableSet.UintSet private totalDepositedIds;

    /// @notice Total borrowed depositIds.
    EnumerableSet.UintSet private totalBorrowedIds;

    /// @notice depositIds listed for lending totally.
    EnumerableSet.UintSet private totalListedIds;

    /// @notice deposited depositIds of each user.
    mapping(address => EnumerableSet.UintSet) private depositedIdsPerUser;

    /// @notice depositIds listed for lending of each user.
    mapping(address => EnumerableSet.UintSet) private listedIdsPerUser;

    /// @notice borrowed depositIds of each user.
    mapping(address => EnumerableSet.UintSet) private borrowedIdsPerUser;

    /// @dev Lending req for each depositId.
    mapping(uint256 => LendingReq) public lendingReqsPerDeck;

    /// The information of ServiceFee by paymentToken.
    mapping(address => ServiceFee) public serviceFees;

    /// The information of each deck.
    mapping(uint256 => DepositInfo) private depositInfo;

    /// Collection information per depositId
    mapping(uint256 => CollectionInfo) private collectionInfoPerDeck;

    /// The max amount of collection that can be deposited.
    mapping(address => DepositLimitInfo) public depositLimitations;

    /// @dev The address of treasury;
    address public treasury;

    uint256 public depositId;

    /// @dev Max collection amount that LBundle can contain.
    uint256 public maxAmountForBundle;

    uint256 public minAmountForBundle;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint16 public FIXED_POINT = 1000;

    uint16 public RF_GAME_FEE = 50; // 5%

    bool public LBundleMode;

    constructor(address _treasury) {
        require(_treasury != address(0), "zero treasury address");
        treasury = _treasury;
        depositId = 1;
    }

### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setTreasury  | Sets the Treasury contract address | Admin |
| setAcceptableERC20  | Sets the accepted ERC20s | Admin |
| setApprovedCollections  | Sets the approved NFTs contract addresses | Admin |
| enableLBundleMode  | Enables/disables bundles to be created in Lending | Admin |
| setNLBundles  | Sets the non-Lending bundles contract addresses | Admin |
| setRFGameFee  | sets the game fee charged by RF on games (%) | Admin |
| setServiceFee  | sets the fee charged by RF on borrow (uint) | Admin |
| configAmountForBundle  | Sets the min and max NFTs per bundle | Admin |
| setDepositFlag  | Enable/Disable deposits of NFTs from certain collections | Admin |
| depositCollection  | Deposits NFTs into a LBundle (bundle created on Lending) | Admin |
| setAcceptableCollections  | sets the accepted collections addresses | Admin |
| depositNLBundle  | Deposit approved bundles into LendingMaster | Admin |
| mergeDeposits  | Merge deposits into a new LBundle | Admin |
| lend  | Lends a deposited bundle of NFTs | Admin |
| borrow  | Borrows the deposited bundle of NFTs (they do not leave the contract) | Admin |
| withdrawCollection  | Withdraws deposited bundles or NFTs | Public |
| getUserDepositedIds  | Gets depositedIds per address | Public |
| getUserListedIds  | Gets the listed deposits per address  | Public |
| getUserNotListedIds  | Gets the non-listed deposits per address | Public |
| getTotalBorrowedIds  | Gets total borrowed deposits | Public |
| getDepositInfo  | Gets information about deposit by depositId | Public |
| getCollectionInfo  | Gets information of collection by depositId | Public |
| getAllowedNLBundles  | Gets allowed Bundles contracts addresses | Public |
| getAllowedTokens  | Gets allowed ERC20 tokens addresses | Public |
| getAllowedCollections  | Gets allowed collections by addresses | Public |
| getTotalListedCollections  | Gets all listed collections by addresses | Public |
| transferFrom  | Trasnfers ERC20 between addresses | Internal |
| withdrawDeck  | Withdraws the deposit | Internal |
| takeServiceFee  | Transfers tokens or bnb to treasury contract | Internal |
| checkCollection  | Get collection information by address and tokenId | Internal |
| checkAcceptedToken  | Gets accepted ERC20s | Internal |
| checkAcceptedCollection  | Gets accepted ERC721 | Internal |
| transferBNB  | Transfers BNB to address | Internal |

### Logic

- Set treasury
- Set approved ERC20s and ERC721s
- Set approved and enable bundles and collections
- Set gameFee and serviceFee
- deposit bundles/NFTs
- mergeDeposits if required
- Lend bundles/NFTs
- Borrow bundles/NFTs

## Treasury.Sol 

Manage funds from Borrowing/Lending.

### Constructor

    contract Treasury is Ownable, ITreasury {
    using SafeERC20 for IERC20;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public fevrToken;

    address public dexRouter;

    address public lendingMaster;

    uint16 public FIXED_POINT = 1000;

    modifier onlyLendingMaster() {
        require(msg.sender == lendingMaster, "only lendingMaster");
        _;
    }

    constructor(address _fevrToken, address _dexRouter) {
        require(_fevrToken != address(0), "zero fevr token address");
        require(_dexRouter != address(0), "zero dex router address");
        fevrToken = _fevrToken;
        dexRouter = _dexRouter;
    }

### Functions

| Function  | Purpose | Function Type |
| ------------- | ------------- | ------------- | 
| setLendingMaster  | Sets LendingMaster contract address | Admin |
| takeServiceFee  | Transfers the non-FEVR fees into FEVR and burns the tokens | Admin |
| withdrawToken  | Withdraws tokens | Admin |
| transferBNB  | Withdraw BNB | Internal |

### Logic

- Set the LendingMaster contract address
- Swap non-FEVR tokens for FEVR and burn FEVR
- Withdraw tokens or BNB

