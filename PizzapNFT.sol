pragma solidity ^0.8.9;

import "./ERC721SlimNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PizzapNFT is ERC721SlimNFT, EIP712, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    event FreeMinted(address luckyAdopter, uint8 amount);

    bytes32 public constant LOTTERY_SALT = 0x495f947276749ce646f68ac8c248420045cb7b5e45cb7b5e45cb7b5eea213782;
    uint256 public constant PRICE = 0.06 ether;
    uint256 public constant INITIAL_ADOPTION = 10;

    struct Config {
        uint16 maxSupply;
        uint16 reservedMintSupply;
        uint16 fixedFreeMintSupply;
        uint16 randomFreeMintSupply;
        bool saleStarted;
    }

    struct Adopter {
        bool reservedMinted;
        bool freeMinted;
    }

    mapping(address => Adopter) public _adopters;
    Config public _config;
    string public _baseURI;
    uint256 public _randomFreeMinted;

    constructor(Config memory config, string memory baseURI) ERC721SlimNFT("PizzapNFT", "PizzapNFT") EIP712("PizzapNFT", "1") {
        config.fixedFreeMintSupply += uint16(INITIAL_ADOPTION);

        _config = config;
        _baseURI = baseURI;

        _safeBatchMint(msg.sender, INITIAL_ADOPTION);
    }

    function adoptNFTs(uint256 amount) external payable {
        Config memory config = _config;
        require(tx.origin == msg.sender, "PizzapNFT: pizzap hates bots");
        require(config.saleStarted, "PizzapNFT: sale is not started");

        uint256 totalMinted = _totalMinted();
        uint256 publicSupply = config.maxSupply - config.reservedMintSupply;
        require(totalMinted + amount <= publicSupply, "PizzapNFT: exceed public supply");

        if (totalMinted < config.fixedFreeMintSupply) {
            require(!_adopters[msg.sender].freeMinted && amount == 1, "PizzapNFT: you can only mint 1 for free");

            _adopters[msg.sender].freeMinted = true;
            _safeMint(msg.sender);
            return;
        }

        require(msg.value >= PRICE * amount, "PizzapNFT: insufficient fund");

        uint256 refundAmount = 0;
        uint256 randomFreeMinted = _randomFreeMinted;
        uint256 remainFreeMintQuota = config.randomFreeMintSupply - randomFreeMinted;
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            msg.sender,
            totalMinted,
            block.difficulty,
            LOTTERY_SALT)));

        for (uint256 i = 0; i < amount && remainFreeMintQuota > 0; i++) {
            if (uint16((randomSeed & 0xFFFF) % publicSupply) < remainFreeMintQuota) {
                refundAmount += 1;
                remainFreeMintQuota -= 1;
            }

            randomSeed = randomSeed >> 16;
        }


        if (refundAmount > 0) {
            _randomFreeMinted = randomFreeMinted + refundAmount;
            Address.sendValue(payable(msg.sender), refundAmount * PRICE);
            emit FreeMinted(msg.sender, uint8(refundAmount));
        }

        _safeBatchMint(msg.sender, amount);
    }

    function verifyAndExtractAmount(
        uint16 amountV,
        bytes32 r,
        bytes32 s
    ) internal view returns (uint256) {
        uint256 amount = uint8(amountV);
        uint8 v = uint8(amountV >> 8);

        bytes32 funcCallDigest = keccak256(abi.encode(
            keccak256("adopt(address parent,uint256 amount)"),
            msg.sender,
            amount));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            _domainSeparatorV4().toTypedDataHash(funcCallDigest)));

        require(ecrecover(digest, v, r, s) == address(owner()), "PizzapNFT: invalid signer");
        return amount;
    }

    function adoptReservedNFTs(
        uint16 amountV,
        bytes32 r,
        bytes32 s
    ) external {
        Config memory config = _config;
        uint256 totalMinted = _totalMinted();
        require(totalMinted <= config.maxSupply, "PizzapNFT: exceed max supply");
        require(!_adopters[msg.sender].reservedMinted, "PizzapNFT: already adopted");

        uint256 amount = verifyAndExtractAmount(amountV, r, s);
        _adopters[msg.sender].reservedMinted = true;

        _safeBatchMint(msg.sender, amount);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "PizzapNFT: URI query for nonexistent token");
        return string(abi.encodePacked(_baseURI, tokenId.toString(), ".json"));
    }

    // ------- Admin Operations -------

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseURI = baseURI;
    }

    function flipSaleState() external onlyOwner {
        _config.saleStarted = !_config.saleStarted;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 share1 = balance * 4 / 100;

        Address.sendValue(payable(0x3162175FF0FE037e53573C6761AFc54ea9449988), share1);
        Address.sendValue(payable(msg.sender), balance - share1);
    }
}