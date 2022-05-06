// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

                                          
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BabyBunnyClub is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant PizzapNFT_GIFT = 120;
    uint256 public constant PizzapNFT_PRIVATE = 880;
    uint256 public constant PizzapNFT_PUBLIC = 9000;
    uint256 public constant PizzapNFT_MAX = PizzapNFT_GIFT + PizzapNFT_PRIVATE + PizzapNFT_PUBLIC;
    uint256 public constant PizzapNFT_PRICE = 0.05 ether;
    uint256 public constant PizzapNFT_PER_MINT = 5;
    
    mapping(address => bool) public presalerList;
    mapping(address => uint256) public presalerListAmount;
    mapping(address => bool) public presalerListMinted;
    mapping(string => bool) private _usedNonces;
    
    string private _contractURI;
    string private _tokenBaseURI = "https://ipfs.io/ipfs/QmRuWpVhPzaj2X8ZY4EoNXV1S4n6bPfpmapK1mT1CodoAN/";

    uint256 public giftedAmount;
    uint256 public publicAmountMinted;
    uint256 public privateAmountMinted;
    uint256 public privateAmountSet;
    uint256 public presalePurchaseLimit = 10;
    bool public presaleLive;
    bool public saleLive;
    bool public locked;
    
    constructor() ERC721("BabyBunnyClub", "BabyBunnyClub") { }
    
    modifier notLocked {
        require(!locked, "Contract metadata methods are locked");
        _;
    }
    
    function addToPresaleList(address[] calldata entries, uint256[] calldata amounts) external onlyOwner {
        require((entries.length == amounts.length) && (entries.length > 0), "INPUT_ERROR");
        uint256  total_amounts = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total_amounts += amounts[i];
        }
        require(privateAmountSet + total_amounts <= PizzapNFT_PRIVATE, "EXCEED_PRIVATE");

        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            uint256 amount = amounts[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(amount > 0 , "ZERO_VALUE");
            require(amount <= presalePurchaseLimit , "EXCEED_PRESALE");
            require(!presalerList[entry], "DUPLICATE_ENTRY");

            presalerList[entry] = true;
            presalerListAmount[entry] = amount;
        }
        privateAmountSet  +=  total_amounts;
             
    }

    function removeFromPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(presalerList[entry] == true, "INPUT_ERROR");
            
            presalerList[entry] = false;
            privateAmountSet -= presalerListAmount[entry];
            presalerListAmount[entry] = 0;
            
        }
    }
    
    function hashTransaction(address sender, uint256 qty, string memory nonce) private pure returns(bytes32) {
          bytes32 hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(sender, qty, nonce)))
          );
          
          return hash;
    }
    
    function buy(bytes32 hash,  string memory nonce, uint256 tokenQuantity) external payable {
        require(saleLive, "SALE_CLOSED");
        require(!presaleLive, "ONLY_PRESALE");
        require(!_usedNonces[nonce], "HASH_USED");
        require(hashTransaction(msg.sender, tokenQuantity, nonce) == hash, "HASH_FAIL");
        require(totalSupply() < PizzapNFT_MAX, "OUT_OF_STOCK");
        require(publicAmountMinted + tokenQuantity <= PizzapNFT_PUBLIC, "EXCEED_PUBLIC");
        require(tokenQuantity <= PizzapNFT_PER_MINT, "EXCEED_PizzapNFT_PER_MINT");
        require(PizzapNFT_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        
        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicAmountMinted++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        
        _usedNonces[nonce] = true;
    }
    
    function presaleBuy() external  {
        require(!saleLive && presaleLive, "PRESALE_CLOSED");
        require(presalerList[msg.sender], "NOT_QUALIFIED");
        require(!presalerListMinted[msg.sender], "ALREADY_MINTED");
        require(totalSupply() < PizzapNFT_MAX, "OUT_OF_STOCK");
        
        uint256  tokenQuantity = presalerListAmount[msg.sender];
        for (uint256 i = 0; i < tokenQuantity; i++) {
            privateAmountMinted++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        presalerListMinted[msg.sender] = true;
    }
    
    function gift(address[] calldata receivers, uint256[] calldata quantities) external onlyOwner {
        require(receivers.length == quantities.length,"GIFT_INPUT_ERR");
        uint256  total_quantities = 0;
        for (uint256 i = 0; i < quantities.length; i++) {
            total_quantities += quantities[i];
        }
        require(totalSupply() + total_quantities <= PizzapNFT_MAX, "MAX_MINT");
        require(giftedAmount + total_quantities <= PizzapNFT_GIFT, "GIFTS_EMPTY");

        
        for (uint256 i = 0; i < receivers.length; i++) {
            require(quantities[i] > 0 , "ZERO_VALUE");
            for (uint256 j = 0; j < quantities[i]; j++) {
                giftedAmount++;
                _safeMint(receivers[i], totalSupply() + 1);
            }
        }
    }
    
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    
    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadata() external onlyOwner {
        locked = true;
    }
    
    function togglePresaleStatus() external onlyOwner {
        presaleLive = !presaleLive;
    }
    
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
    
    function setContractURI(string calldata URI) external onlyOwner notLocked {
        _contractURI = URI;
    }
    
    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        _tokenBaseURI = URI;
    }
    
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");
        
        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }
}