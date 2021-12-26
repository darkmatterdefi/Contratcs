// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

pragma solidity ^0.8.0;

contract FounderTokenDMD is ERC721 {
    using Strings for uint256;

    string public baseURI;
    uint256 public _totalSupply;
    address public owner;
    string public baseExtension = ".json";

    constructor() ERC721("FounderToken", "FT_NFT") {
        baseURI = string(
            "https://gateway.pinata.cloud/ipfs/QmZVLKBp5BKdjfvjjS23YFJfGdRRHAtugxkKVCxA9VHNA4/"
        );
        owner = address(0x365e82adAD2C86D38Bec033be04768c8eCd108e4);
        _totalSupply = 169;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory uri) external {
        require(msg.sender == owner, "setBaseUri unauthorized");
        baseURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) external {
        require(msg.sender == owner, "setBaseExtension unauthorized");
        baseExtension = _newBaseExtension;
    }

    function batchMint(address[] memory addresses, uint256 start) external {
        require(msg.sender == owner, "batchMint unauthorized");
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    function burner(uint256 tokenId) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "You do not own any NFT of this collection"
        );
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }
}