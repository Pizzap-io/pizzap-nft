//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PERC1155 is ERC1155, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _currentTokenId;

    /// @dev <tokenId,address>
    mapping(uint256 => TokenInfo) public tokens;
    mapping(uint256 => string) private tokenURIs;

    uint256 public ethFee;

    struct TokenInfo {
        address creator;
        uint256 supply;
    }

    constructor(uint256 _ethFee, string memory _uri) ERC1155(_uri) {
        ethFee = _ethFee;
    }

    function create(
        address _initialOwner,
        uint256 _initialSupply,
        string calldata _uri,
        bytes calldata _data
    ) external payable returns (uint256) {
        if (ethFee > 0) {
            require(msg.value == ethFee, "error fee value");
            (bool sent, ) = address(this).call{value: ethFee}("");
            require(sent, "Failed to send ETH");
        }
        uint256 _id = _getNextTokenId();
        _incrementTokenId();
        tokens[_id].creator = msg.sender;

        _mint(_initialOwner, _id, _initialSupply, _data);
        tokens[_id].supply = _initialSupply;
        _setCustomURI(_id, _uri);
        return _id;
    }

    function setURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    function _setCustomURI(uint256 _tokenId, string memory _newURI) internal {
        tokenURIs[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "NONEXISTENT_TOKEN");
        bytes memory customUriBytes = bytes(tokenURIs[_id]);
        if (customUriBytes.length > 0) {
            return tokenURIs[_id];
        } else {
            return super.uri(_id);
        }
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return tokens[_id].creator != address(0);
    }

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.current().add(1);
    }

    function _incrementTokenId() private {
        _currentTokenId.increment();
    }

    function tokenIds() external view returns (uint256) {
        return _currentTokenId.current();
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