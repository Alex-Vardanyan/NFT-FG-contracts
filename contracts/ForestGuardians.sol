// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./FGCertificate.sol";


/// @title NFT contract for the Forest Guardians Project
/// @notice one of 2 contracts of the Forest Guardians Project
/// @author Alexander Vardanyan
/// @custom:security-contact alexandervardanyan1@gmail.com
contract ForestGuardians is ERC721, ERC721URIStorage, Pausable, AccessControl, ERC721Royalty {
    using Counters for Counters.Counter;

    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");
    Counters.Counter private _tokenIdCounter;
    
    uint256 public mintPrice;
    uint256 public upgradePrice;
    uint256 public specialPrice;
    uint256 public dropSize;
    FGCertificate certificate;
    mapping(uint256 => bool) existingURIs; // ipfs json id to bool
    mapping(uint256 => bool) specials; //ipfs json id to bool
    mapping(uint256 => uint256) uris; // tokenId to ipfs json id
    struct levelStruct {uint256 headgear; uint256 armor; uint256 item;}
    mapping(uint256 => levelStruct) levels; // mapping to save current gear levels of each character
    struct upgradeStruct {bool headgear; bool armor; bool item;}
    event mintSuccess(address _owner, string nftURL, string certURL);
    event upgradeSuccess(string newURL);
    event hideUnhideSuccess(string newURL);

    /// @dev the minting is puased by default, and should be unpaused as soon as BOT_ROLE is granted to other contracts
    /// @param _certificateAddress - should supply the address of the already deployed FGCertificate contract
    constructor(address _certificateAddress) ERC721("Forest Guardians", "FRG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BOT_ROLE, msg.sender);
        certificate = FGCertificate(_certificateAddress);
        ERC2981._setDefaultRoyalty(msg.sender, 10); // 10% fee
        pause();
    }

    /// @dev neccessary checks before hiding and showing the gear
    /// @param tokenId - token's Id
    /// @param data - upgrade struct containing bool value for each gear in the following order: headgear, armor, item
    modifier beforeHideUnhide(uint256 tokenId, upgradeStruct memory data) {
        require(uris[tokenId] != 0, "token does not exist");
        require(ownerOf(tokenId) == msg.sender, "You're not allowed to upgrade this token.");
        require(!(specials[uris[tokenId]]), "You cant upgrade, special character cant be upgraded.");
        _;
    }

    /// @dev neccessary checks before upgrading the gear
    /// @param tokenId - token's Id
    /// @param data - upgrade struct containing bool value for each gear in the following order: headgear, armor, item
    modifier beforeUpgradeChecks(uint256 tokenId, upgradeStruct memory data) {
        require(uris[tokenId] != 0, "token does not exist");
        require(ownerOf(tokenId) == msg.sender, "You're not allowed to upgrade this token.");
        require((levels[tokenId].armor + (data.armor ? 1 : 0) <= 3), "You cant upgrade, armor is max level.");
        require((levels[tokenId].headgear + (data.headgear ? 1 : 0) <= 3), "You cant upgrade, headgear is max level.");
        require((levels[tokenId].item + (data.item ? 1 : 0) <= 3), "You cant upgrade, item is max level.");
        require(!(specials[uris[tokenId]]), "You cant upgrade, special character cant be upgraded.");
        require((((data.armor ? 1 : 0) * levels[tokenId].armor) + ((data.headgear ? 1 : 0) * levels[tokenId].headgear) + ((data.item ? 1 : 0) * levels[tokenId].item)) * upgradePrice == msg.value, "Wrong amount is sent.");
        _;
    }

    /// @dev A function to grant BOT_ROLE to other smart contracts of the Forest Guardians Project
    /// @param role - only BOT_ROLE can be granted for now
    /// @param account - destination address
    function grantRole(bytes32 role, address account) public override onlyRole(DEFAULT_ADMIN_ROLE){
        require(role == BOT_ROLE, "Only BOT_ROLE can be granted to new users.");
        super.grantRole(role,account);
    }

    /// @dev A function to set the mint price for non special NFTs
    /// @param price - minting price
    function setMintPrice(uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        mintPrice = price;
    }

    /// @dev A function to set the upgrade price for non special NFTs
    /// @param price - upgrade price
    function setUpgradePrice(uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        upgradePrice = price;
    }

    /// @dev A function to set the mint price for special NFTs
    /// @param price - special NFT price
    function setSpecialPrice(uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        specialPrice = price;
    }

    /// @dev A function to set the batch size
    /// @param size - size of the batch containing the specials and nonspecial NFTs
    function setDropSize(uint256 size) public onlyRole(DEFAULT_ADMIN_ROLE) {
        dropSize = size;
    }

    /// @dev A function to set the mint price for non special nfts
    /// @param uri - integer, ipfs json id
    function addSpecial(uint256 uri) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(!specials[uri], "Already added.");
        specials[uri] = true;
        dropSize++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @dev A function to upgrade gear on non special NFT
    /// @param tokenId - token Id
    /// @param data - upgrade struct containing bool value for each gear in the following order: headgear, armor, item
    function upgrade(uint256 tokenId, upgradeStruct memory data) public payable beforeUpgradeChecks(tokenId, data) returns(bool) {
        uint256 ImageN = uris[tokenId];
        levelStruct memory current = levels[tokenId];
        string memory ImageURI = string(abi.encodePacked(Strings.toString(ImageN), "-", Strings.toString((data.headgear ? 1 : 0) + current.headgear), Strings.toString((data.armor ? 1 : 0) + current.armor), Strings.toString((data.item ? 1 : 0) + current.item), ".json"));
        _setTokenURI(tokenId, ImageURI);
        levels[tokenId] = levelStruct((data.headgear ? 1 : 0) + current.headgear,(data.armor ? 1 : 0) + current.armor ,(data.item ? 1 : 0) + current.item);
        emit upgradeSuccess(string(abi.encodePacked(_baseURI(), ImageURI)));
        return true;
    }

    /// @dev A function to hide/show gears on non special NFT
    /// @param tokenId - token Id
    /// @param data - upgrade struct containing bool value for each gear in the following order: headgear, armor, item
    function hideUnhide(uint256 tokenId, upgradeStruct memory data) public beforeHideUnhide(tokenId, data) returns(bool) {
        uint256 ImageN = uris[tokenId];
        levelStruct memory current = levels[tokenId];
        string memory ImageURI = string(abi.encodePacked(Strings.toString(ImageN), "-", Strings.toString((data.headgear ? 1 : 0)*current.headgear), Strings.toString((data.armor ? 1 : 0)*current.armor), Strings.toString((data.item ? 1 : 0)*current.item), ".json"));
        _setTokenURI(tokenId, ImageURI);
        emit hideUnhideSuccess(string(abi.encodePacked(_baseURI(), ImageURI)));
        return true;
    }

    /// @dev standard function to mint an NFT
    /// @param ImageN - ipfs json id
    /// @param CertURI - ipfs uri for generated certificate to pass it to other contact
    function mint(uint256 ImageN, string memory CertURI) public payable returns(bool){
        require(msg.value >= (specials[ImageN] ? specialPrice : mintPrice), "Insufficent amount.");
        require(!existingURIs[ImageN], "The NFT already exists.");
        require(_tokenIdCounter.current() <= dropSize, "All NFTs are minted, see you next batch!");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingURIs[ImageN] = true;
        uris[tokenId] = ImageN;
        _safeMint(msg.sender, tokenId);
        if(!specials[ImageN]){
            levels[tokenId] = levelStruct(1,1,1);
        }
        string memory ImageURI = string(abi.encodePacked(Strings.toString(ImageN), specials[ImageN] ? ".json" : "-111.json"));
        _setTokenURI(tokenId, ImageURI);
        if(certificate.mint(msg.sender, CertURI)){
            emit mintSuccess(msg.sender, string(abi.encodePacked(_baseURI(), ImageURI)), string(abi.encode(_baseURI(), CertURI)));
            return true;
        }
        return false;
    }

    /// @dev A function to test as well as generate NFTs without a certificate
    /// @param ImageN - ipfs json id
    function safeMint(uint256 ImageN) public onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        require(!existingURIs[ImageN], "The certificate already exists.");
        require(_tokenIdCounter.current() <= dropSize, "All NFTs are minted, see you next batch!");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingURIs[ImageN] = true;
        uris[tokenId] = ImageN;
        _safeMint(msg.sender, tokenId);
        if(!specials[ImageN]){
            levels[tokenId] = levelStruct(1,1,1);
        }
        string memory ImageURI = string(abi.encodePacked(Strings.toString(ImageN), specials[ImageN] ? ".json" : "-111.json"));
        _setTokenURI(tokenId, ImageURI);
        emit mintSuccess(msg.sender, string(abi.encodePacked(_baseURI(), ImageURI)), "");
        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}