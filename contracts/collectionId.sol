// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./interfaces/OpenerMintInterface.sol";

contract CollectionId is Ownable, ERC721URIStorage , OpenerMintInterface {

    address _opener;
    address _admin;
    uint256 private lastTokenId;

    string private _baseURIextended;
    
    // Mapping from address to bool, if egg was already claimed
    // The hash is about the userId and the nftIds array
    mapping(address => mapping(uint256 => bool)) public registeredIDs;
    mapping(address => uint256[]) public registeredIDsArray;
    mapping(uint256 => bool) public override alreadyMinted;
    mapping(address => uint256) public override mintedCounts;

    mapping(uint256 => MarketplaceDistribution) private marketplaceDistributions;

    event NftMinted(uint256 indexed tokenID);

    modifier onlyAdmin {
        require(_admin == _msgSender(), "Caller is not the admin");
        _;
    } 

    modifier onlyOpener {
        require(_opener == _msgSender(), "Caller is not the opener contract");
        _;
    }

    constructor(
        address _owner, 
        address opener,
        string memory name_, 
        string memory symbol_
    ) ERC721(name_, symbol_) {
        _opener = opener;
        lastTokenId = 1;
        _admin = _owner; 
    }

    function setBaseURI(string memory baseURI_) external onlyAdmin {
        _baseURIextended = baseURI_;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyAdmin {
        _setTokenURI(tokenId, _tokenURI);
    }

    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    function getLastNFTID() public view override returns(uint256) {
        return lastTokenId;
    }

    function getMarketplaceDistributionForERC721(
        uint256 _tokenId
    ) external override view returns(
        uint256[] memory, 
        address[] memory
    ) {
        return (marketplaceDistributions[_tokenId].marketplaceDistributionAmounts, marketplaceDistributions[_tokenId].marketplaceDistributionAddresses);
    }

    // used when creating new pack and assigning nft index
    function setLastNFTID(uint256 newId) external override onlyOpener {
        require(newId > lastTokenId, "Wrong value");
        lastTokenId = newId;
    }

    function exists(uint256 tokenId) public view override returns (bool) {
        return _exists(tokenId);
    }

    function checkRegisteredID(
        address _address, 
        uint256 _tokenIdToMint
    ) external view returns(bool) {
        return registeredIDs[_address][_tokenIdToMint];
    }

    function setRegisteredID(
        address _address, 
        uint256 _id
    ) external override onlyOpener {
        registeredIDs[_address][_id] = true;
    }

    function pushRegisteredIDsArray(
        address _address, 
        uint256 _id
    ) external override onlyOpener {
        registeredIDsArray[_address].push(_id);
    }

    function getRegisteredIDs(
        address _address
    ) public view override returns(uint256[] memory) {
        return registeredIDsArray[_address];
    }

    function mint(uint256 tokenIdToMint) external override onlyOpener {
        address account = tx.origin;
        require(registeredIDs[account][tokenIdToMint], "Token was not registered or not the rightful owner");
        require(!alreadyMinted[tokenIdToMint], "Already minted");

        alreadyMinted[tokenIdToMint] = true;
        mintedCounts[account] ++;
        _safeMint(account, tokenIdToMint);
        emit NftMinted(tokenIdToMint);
    }

    // only set by opener when pack is created
    function setMarketplaceDistribution(
        uint256[] memory _amounts, 
        address[] memory _addresses, 
        uint256 _id
    ) external override onlyOpener {
        MarketplaceDistribution memory marketplaceDistribution = MarketplaceDistribution(_amounts, _addresses);
        marketplaceDistributions[_id] = marketplaceDistribution;
    }

    // only set by admin
    function setMarketplaceDistForNFT(
        uint256 _tokenId, 
        uint256[] memory _marketplaceDistributionAmounts, 
        address[] memory _marketplaceDistributionAddresses
    ) external {
        require(msg.sender == _admin, "Not authorized");
        require(_tokenId < getLastNFTID(), "NFT has not been created");
        require(_marketplaceDistributionAmounts.length == _marketplaceDistributionAddresses.length, "Length missmatch");
        marketplaceDistributions[_tokenId].marketplaceDistributionAmounts =_marketplaceDistributionAmounts;
        marketplaceDistributions[_tokenId].marketplaceDistributionAddresses = _marketplaceDistributionAddresses;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIextended;
    }
}
