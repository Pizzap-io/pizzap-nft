// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PERC721 is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public ethFee;

    constructor(uint256 _ethFee) ERC721("PERC721", "PERC721") {
        ethFee = _ethFee;
    }

    function create(address player, string memory tokenURI)
        external
        payable
        returns (uint256)
    {
        if (ethFee > 0) {
            require(msg.value == ethFee, "error fee value");
            (bool sent, ) = address(this).call{value: ethFee}("");
            require(sent, "Failed to send ETH");
        }

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