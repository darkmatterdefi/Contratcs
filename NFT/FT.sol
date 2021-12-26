// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FounderToken is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public constant MAX_TOTAL_SUPPLY = 169;

    event Minted(address indexed minter, uint256 nftID);

    constructor() public ERC721("FounderToken_DarkMatter", "FT") {}

    function mintfoundertoken(address receiver)
        external
        onlyOwner
        returns (uint256)
    {
        require(
            SafeMath.add(_tokenIds.current(), 1) <= MAX_TOTAL_SUPPLY,
            "Mint reached total supply"
        );
        _tokenIds.increment();

        uint256 newNftTokenId = _tokenIds.current();
        _mint(receiver, newNftTokenId);

        emit Minted(receiver, newNftTokenId);
        return newNftTokenId;
    }

    function mintfoundertoken(address receiver, uint256 count)
        external
        onlyOwner
    {
        require(
            SafeMath.add(_tokenIds.current(), count) <= MAX_TOTAL_SUPPLY,
            "Mint reached total supply"
        );

        for (uint256 i; i < count; i++) {
            _tokenIds.increment();

            uint256 newNftTokenId = _tokenIds.current();
            _mint(receiver, newNftTokenId);

            emit Minted(receiver, newNftTokenId);
        }
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }
}
