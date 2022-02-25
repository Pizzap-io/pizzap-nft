// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/access/Ownable.sol";

contract PERC721 is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("PizzapNFT", "PizzapNFT") public {
    }

    function create(address player, string memory tokenURI)
        external
        payable
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newId = _tokenIds.current();
        _mint(address(player), newId);
        _setTokenURI(newId, tokenURI);

        return newId;
    }

    function tokenIds() external view returns (uint256) {
        return _tokenIds.current();
    }

    receive() external payable {}

    fallback() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "balance zero");
        payable(owner()).transfer(address(this).balance);
    }

    
}