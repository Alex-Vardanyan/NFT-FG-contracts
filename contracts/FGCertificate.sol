// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Certificate for the Forest Guardians Project
/// @notice one of 2 contracts of the Forest Guardians Project
/// @author Alexander Vardanyan
/// @custom:security-contact alexandervardanyan1@gmail.com
contract FGCertificate is ERC721, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");
    address public owner;
    mapping(string => bool) existingCertificates;
    event mintSuccess(string _url);

    Counters.Counter private _tokenIdCounter;

    /// @dev the minting is puased by default, and should be unpaused as soon as BOT_ROLE is granted to other contracts
    constructor() ERC721("Forest Guardians Certificate", "FGC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BOT_ROLE, msg.sender);
        owner = msg.sender;
        pause();
    }

    /// @dev A function to grant BOT_ROLE to other smart contracts of the Forest Guardians Project
    /// @param role - only BOT_ROLE can be granted for now
    /// @param account - destination address
    function grantRole(bytes32 role, address account) public override onlyRole(DEFAULT_ADMIN_ROLE){
        require(role == BOT_ROLE, "Only BOT_ROLE can be granted to new users.");
        super.grantRole(role,account);
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
    
    /// @dev standard function to mint a certificate, can be called from other contracts
    /// @param _to - address of the user to mint certificate for
    /// @param uri - string pointing to the certification generated and uploaded to ipfs
    function mint(address _to, string memory uri) public onlyRole(BOT_ROLE) returns(bool) {
        require(!existingCertificates[uri], "The certificate already exists");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingCertificates[uri] = true;
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, uri);
        return true;
    }

    /// @dev A function to test as well as generate certificates without a tradeable NFT
    /// @param uri - string pointing to the certification generated and uploaded to ipfs
    function safeMint(string memory uri) public onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        require(!existingCertificates[uri], "The certificate already exists");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        existingCertificates[uri] = true;
        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, uri);
        emit mintSuccess(string(abi.encode(_baseURI(), uri)));
        return true;
    }

    /// @notice The generated (minted) certificate is not allowed to be transferred, it contains information on particular transaction and shows ownernship
    /// @dev this prohibits certificate transfer and trade between users
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(hasRole(BOT_ROLE, msg.sender) || to == address(0), "Certificate can only be burned, not transferred.");
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}