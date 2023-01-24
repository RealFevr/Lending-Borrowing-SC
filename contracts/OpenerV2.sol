// SPDX-License-Identifier: MIT
 
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOpenerRealFevrV2.sol";
import "./interfaces/ICollectionIdFactory.sol";
import "./interfaces/OpenerMintInterface.sol";
import "./collectionId.sol";

contract OpenerRealFevrV2 is IOpenerRealFevrV2, Ownable {
    
    bytes32 public constant PACK_CREATOR_ROLE = keccak256("CREATOR");
    bytes32 public constant PACK_OFFEROR_ROLE = keccak256("OFFEROR");

    uint256 public packIncrementId;
    uint256 public _packsBought;
    bool public _closed;
    
    mapping(address => mapping(uint256 => bool)) public openedCollectionIds;
    mapping(uint256 => Pack) public packs;
    mapping(address => uint256) public collectionIdToSaleStart;
    mapping(address => bool) public isCollectionIdOpenPackLocked;
    mapping(address => bool) public isBuyPackLocked;
    mapping(address => whitelist) public collectionIdWhitelist; // collection id address to whitelist struct

    mapping(address => uint256) public ERC20Price; // all decimals = $1
    mapping(address => bool) public isERC20Accepted;
    mapping(address => bool) private isOpenerMintInterfaceAccepted;
    address[] public nfts;
    address private _factory;
    address public creator;
    address public offeror;

    modifier onlyCreator() {
        address sender = msg.sender;
        require (sender == owner() || sender == creator, "only Creator can create packs");
        _;
    }

    modifier onlyOfferor() {
        address sender = msg.sender;
        require (sender == owner() || sender == offeror, "only Offeror can offer packs");
        _;
    }

    constructor (
        address factory,
        string memory name, 
        string memory symbol
    ) {
        address sender = msg.sender;
        _factory = factory;
        // create the first default nft token
        address newCollectionId = ICollectionIdFactory(factory).createNewCollectionId(sender, name, symbol);
        nfts.push(newCollectionId);
        isOpenerMintInterfaceAccepted[newCollectionId] = true;
        packIncrementId = 1;
    }

    function setCreator(address _account) external onlyOwner {
        creator = _account;
    }

    function setOfferor(address _offeror) external onlyOwner {
        offeror = _offeror;
    }

    function setERC20Price(
        address _erc20, 
        uint256 _price
    ) external onlyOwner {
        ERC20Price[_erc20] = _price;
    }

    function getPackPriceInERC20(
        uint256 packId
    ) public view returns(uint256) {
        return ERC20Price[packs[packId].buyToken] == 0 ? 0 : packs[packId].packPriceUSD * 1e18 / ERC20Price[packs[packId].buyToken];
    }

    function changeCollectionWhitelistFlag(
        address collectionIdAddress
    ) external onlyOwner {
        collectionIdWhitelist[collectionIdAddress].whitelistEnabled = !collectionIdWhitelist[collectionIdAddress].whitelistEnabled;
    }
    
    function addWhiteListAddresses(
        address collectionIdAddress, 
        address[] memory _addresses
    ) external onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
           collectionIdWhitelist[collectionIdAddress].isWhitelisted[_addresses[i]] = true;
        }
    }
    function removeWhiteListAddresses(
        address collectionIdAddress, 
        address[] memory _addresses
    ) external onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
           collectionIdWhitelist[collectionIdAddress].isWhitelisted[_addresses[i]] = false;
        }
    }
 
    function buyPack(uint256 packId) public {
        require(!_closed, "Opener locked");
        require(block.timestamp >= collectionIdToSaleStart[packs[packId].NFTAddress], "Sale not started yet");
        require(packs[packId].buyer == address(0), "Pack is bought");
        require(packs[packId].packPriceUSD != 0, "Pack has to exist");
        require(!isBuyPackLocked[packs[packId].NFTAddress], "Buy pack locked");

        if(collectionIdWhitelist[packs[packId].NFTAddress].whitelistEnabled) {
            require(collectionIdWhitelist[packs[packId].NFTAddress].isWhitelisted[msg.sender], "Not whitelisted");
        }

        address from = msg.sender;

        uint256 price = getPackPriceInERC20(packId);
        require (price > 0, "price is not set yet");
        _distributePackShares(from, packId, getPackPriceInERC20(packId));

        _packsBought++;

        for(uint i = 0; i < packs[packId].nftAmount; i++){
            OpenerMintInterface(packs[packId].NFTAddress).setRegisteredID(msg.sender, packs[packId].initialNFTId+i);
            OpenerMintInterface(packs[packId].NFTAddress).pushRegisteredIDsArray(msg.sender, packs[packId].initialNFTId+i);
        }

        packs[packId].buyer = from;

        emit PackBought(from, packId);
    }

    function buyPacks(uint256[] memory packIds) external {
        for(uint i = 0; i < packIds.length; i++){
            buyPack(packIds[i]);
        } 
    }

    function getMintableCollectionIds(
        address account,
        address collectionAddress
    ) public view returns (uint256[] memory) {
        require (collectionAddress != address(0), "invalid collection address");
        OpenerMintInterface collection = OpenerMintInterface(collectionAddress);
        uint256[] memory registeredIds = collection.getRegisteredIDs(account);

        uint256 mintableCount = 0;
        for (uint256 i = 0; i < registeredIds.length; i ++) {
            uint256 id = registeredIds[i];
            if (!collection.alreadyMinted(id) && openedCollectionIds[collectionAddress][id]) {
                mintableCount ++;
            }
        }

        uint256[] memory mintableIds = new uint256[](mintableCount);
        uint256 index = 0;
        for (uint256 i = 0; i < registeredIds.length; i ++) {
            uint256 collectionId = registeredIds[i];
            if (!collection.alreadyMinted(collectionId) && openedCollectionIds[collectionAddress][collectionId]) {
                mintableIds[index ++] = collectionId;
            }
        }
        return mintableIds;
    }

    function mintArray(
        MintNFTCollectionParam[] memory mintNFTCollections
    ) public {
        uint256 length = mintNFTCollections.length;
        require(!_closed, "Opener is locked");
        require (length > 0, "empty collection array for minting");

        for (uint256 i = 0; i < length; i ++) {
            MintNFTCollectionParam memory mintNFTCollection = mintNFTCollections[i];
            address collectionAddress = mintNFTCollection.collectionAddress;
            uint256 collectionIdLength = mintNFTCollection.collectionIds.length;
            require (collectionAddress != address(0), "zero collection address");
            require (collectionIdLength > 0, "empty mint collection id array");
            for (uint256 j = 0; j < collectionIdLength; j ++) {
                uint256 collectionId = mintNFTCollection.collectionIds[j];
                require (openedCollectionIds[collectionAddress][collectionId], "Not opened collection id");
                OpenerMintInterface(collectionAddress).mint(collectionId);
                emit NftMinted(collectionAddress, collectionId);
            }
        }
    }

    function mintAll(address[] memory collectionAddrs) external {
        uint256 collectionLength = collectionAddrs.length;
        require (collectionLength > 0, "empty collection address array");
        MintNFTCollectionParam[] memory collectionParams = new MintNFTCollectionParam[](collectionLength);
        for (uint256 i = 0; i < collectionLength; i ++) {
            address collectionAddress = collectionAddrs[i];
            uint256[] memory collectionIds = getMintableCollectionIds(msg.sender, collectionAddress);
            uint256 collectionIdLength = collectionIds.length;
            if (collectionIdLength == 0) {
                revert(
                    string(
                        abi.encodePacked(
                            "no mintable collection ids for ",
                            Strings.toHexString(collectionAddress)
                        )
                    )
                );
            }
            collectionParams[i] = MintNFTCollectionParam(collectionAddress, collectionIds);
        }

        mintArray(collectionParams);
    }

    function openPackMintAll(uint256 packId) public {
        address collectionAddress = packs[packId].NFTAddress;
        require(!_closed, "Opener is locked");
        require(!packs[packId].opened, "Opened Already");
        require(packs[packId].buyer != address(0), "Pack not bought");
        require(packs[packId].buyer == msg.sender, "Not buyer");
        require(!isCollectionIdOpenPackLocked[collectionAddress], "Open locked");

        uint256 nftStartId = packs[packId].initialNFTId + packs[packId].mintCount;

        for(uint256 i = nftStartId; i < packs[packId].initialNFTId + packs[packId].nftAmount; i++) {
            openedCollectionIds[collectionAddress][i] = true;
            OpenerMintInterface(collectionAddress).mint(i);
            packs[packId].mintCount ++;
            emit NftMinted(collectionAddress, i);
        }

        packs[packId].opened = true;
    }

    function openPacksMintAll(uint256[] memory packIds) external {
        for(uint i = 0; i < packIds.length; i++){
            openPackMintAll(packIds[i]);
        } 
    }

    function openPack(uint256 packId) public {
        address collectionAddress = packs[packId].NFTAddress;
        require(!_closed, "Opener is locked");
        require(!packs[packId].opened, "Opened Already");
        require(packs[packId].buyer != address(0), "Pack not bought");
        require(packs[packId].buyer == msg.sender, "Not buyer");
        require(!isCollectionIdOpenPackLocked[collectionAddress], "Open locked");

        uint256 nftStartId = packs[packId].initialNFTId + packs[packId].mintCount;

        for(uint256 i = nftStartId; i < packs[packId].initialNFTId + packs[packId].nftAmount; i++) {
            openedCollectionIds[collectionAddress][i] = true;
        }

        packs[packId].opened = true;
        emit PackOpened(msg.sender, packId);
    }

    function openPacks(uint256[] memory packIds) external {
        for(uint i = 0; i < packIds.length; i++){
            openPack(packIds[i]);
        } 
    }

    function createMultiplePacks(
        MultiPacksParam memory param,
        address[] memory saleDistributionAddresses, 
        uint256[] memory saleDistributionAmounts,
        address[] memory marketplaceDistributionAddresses,  
        uint256[] memory marketplaceDistributionAmounts
      ) external onlyCreator {
        require(saleDistributionAddresses.length == saleDistributionAmounts.length , 
          "saleDistributionAddresses Lengths dont match with saleDistributionAmounts");
        require(marketplaceDistributionAddresses.length == marketplaceDistributionAmounts.length , 
          "marketplaceDistributionAddresses Lengths dont match with marketplaceDistributionAmounts");
        require(isOpenerMintInterfaceAccepted[param.NFTAddress], "NFT address not valid");
        require(isERC20Accepted[param.erc20], "ERC20 is not accepted as payment");

        for(uint i = 0; i < param.packsAmount; i++){
            uint256 _lastNFTid = OpenerMintInterface(param.NFTAddress).getLastNFTID();
            packs[packIncrementId].buyToken = param.erc20;
            packs[packIncrementId].NFTAddress = param.NFTAddress;
            packs[packIncrementId].packId = packIncrementId;
            packs[packIncrementId].nftAmount = param.nftAmount;
            packs[packIncrementId].initialNFTId = _lastNFTid;
            packs[packIncrementId].packPriceUSD = param.priceInUSD; 
            packs[packIncrementId].serie = param.serie;
            packs[packIncrementId].drop = param.drop;
            packs[packIncrementId].saleDistributionAddresses = saleDistributionAddresses;
            packs[packIncrementId].saleDistributionAmounts = saleDistributionAmounts;
            packs[packIncrementId].packType = param.packType;

            for(uint j = 0; j < param.nftAmount; j++){
            
                OpenerMintInterface(packs[packIncrementId].NFTAddress).setMarketplaceDistribution(
                    marketplaceDistributionAmounts, 
                    marketplaceDistributionAddresses, 
                    _lastNFTid+j
                );
            }

            emit PackCreated(packIncrementId, param.serie, param.packType, param.drop);
            OpenerMintInterface(param.NFTAddress).setLastNFTID(_lastNFTid + param.nftAmount);
            packIncrementId++;
        }
    }

    function offerPack(uint256 packId, address receivingAddress) public onlyOfferor {
        require(packs[packId].packId == packId, "Pack does not exist");
        require(packs[packId].buyer == address(0), "Pack is bought");

        packs[packId].buyer = receivingAddress;

        for(uint i = 0; i < packs[packId].nftAmount; i++){            
            OpenerMintInterface(packs[packId].NFTAddress).setRegisteredID(receivingAddress, packs[packId].initialNFTId+i);
            OpenerMintInterface(packs[packId].NFTAddress).pushRegisteredIDsArray(receivingAddress, packs[packId].initialNFTId+i);
        }
        emit PackOffered(receivingAddress, packId);
    }

    function offerPacks(uint256[] memory packIds, address[] memory receivingAddresses) external onlyOwner {
        require(packIds.length == receivingAddresses.length , "packIds Lengths dont match with receivingAddresses");
        for(uint i = 0; i < packIds.length; i++){
            offerPack(packIds[i], receivingAddresses[i]);
        }
    }


    function setERC20Accepted(address _addr) external onlyOwner {
        isERC20Accepted[_addr] = !isERC20Accepted[_addr];
    }

    function editPackInfo(
        uint256 _packId, 
        string memory serie, 
        string memory packType, 
        string memory drop, 
        uint256 priceUSD
    ) external onlyOwner {
        require(block.timestamp < collectionIdToSaleStart[packs[_packId].NFTAddress], "Sale already live");
        packs[_packId].serie = serie;
        packs[_packId].packType = packType;
        packs[_packId].drop = drop;
        packs[_packId].packPriceUSD = priceUSD;
    }

    function deletePackById(uint256 packId) external onlyOwner {
        require(block.timestamp < collectionIdToSaleStart[packs[packId].NFTAddress], "Sale already live");
        delete packs[packId];
    }

    function swapClosed() external onlyOwner {
        _closed = !_closed;
    }

    function multipleNftTransfer(
        NFTTransferParam[] memory nftTransferParams
    ) external {
        uint256 length = nftTransferParams.length;
        require (length > 0, "empty nft infors for transferring");
        for (uint256 i = 0; i < length; i ++) {
            NFTTransferParam memory nftTransferParam = nftTransferParams[i];
            address nft = nftTransferParam.nftAddress;
            uint256[] memory ids = nftTransferParam.ids;
            address[] memory recipients = nftTransferParam.recipients;
            require(isOpenerMintInterfaceAccepted[nft], "Address not valid");
            require(ids.length == recipients.length, "Length missmatch");
            for(uint256 j = 0; j < ids.length; j++)
                IERC721(nft).transferFrom(msg.sender, recipients[j], ids[j]);
        }
    }

    function createNewNFTContract(
        string memory name, 
        string memory symbol
    ) external onlyOwner {
        address newCollectionAddr = ICollectionIdFactory(_factory).createNewCollectionId(owner(), name, symbol);
        nfts.push(newCollectionAddr);
        isOpenerMintInterfaceAccepted[nfts[nfts.length-1]] = true;
    }

    function getNFTAddresses() external view returns (address[] memory) {
        uint256 length = nfts.length;
        address[] memory NFTAddresses = new address[](length);
        for (uint256 i = 0; i < length; i ++) {
            NFTAddresses[i] = nfts[i];
        }

        return NFTAddresses;
    }

    function setCollectionIdOpenPackLocked(
        address collectionIdAddress
    ) external onlyOwner {
        isCollectionIdOpenPackLocked[collectionIdAddress] = !isCollectionIdOpenPackLocked[collectionIdAddress];
    }

    function setCollectionIdBuyPackLocked(
        address collectionIdAddress
    ) external onlyOwner {
        isBuyPackLocked[collectionIdAddress] = !isBuyPackLocked[collectionIdAddress];
    }

    function setCollectionIdSaleStart(
        address collectionIdAddress, 
        uint256 saleStart
    ) external onlyOwner {
        collectionIdToSaleStart[collectionIdAddress] = saleStart;
    }

    // change rightholder fees and addresses for a specified nft
    function setMarketplaceDistributionForCollection(
        address collectionAddress, 
        uint256[] memory _amounts, 
        address[] memory _addresses, 
        uint256 _id
    ) external onlyOwner {
        require(_amounts.length == _addresses.length, "Lengths missmatch");
        OpenerMintInterface(collectionAddress).setMarketplaceDistribution(_amounts, _addresses, _id);
    }

    function _distributePackShares(
        address from, 
        uint256 packId, 
        uint256 amount
    ) internal {
        Pack memory pack = packs[packId];
        for(uint i = 0; i < pack.saleDistributionAddresses.length; i ++){
            //transfer of stake share
            IERC20(pack.buyToken).transferFrom(
                from,
                pack.saleDistributionAddresses[i],
                (pack.saleDistributionAmounts[i] * amount) / 100
            );
        }
    }
}