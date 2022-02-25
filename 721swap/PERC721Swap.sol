//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PERC721Swap is ERC721Holder, OwnableUpgradeable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum PayMod {
        MAPI,
        USDT
    }

    struct PayInfo {
        address erc20;
        uint256 fee;
        PayMod payMod;
    }

    struct NftInfo {
        address contractAddress;
        uint256 tokenId;
    }

    struct Item {
        uint256 orderId;
        NftInfo token;
        PayMod payMod;
        address seller;
        uint256 price;
        uint256 quantity;
        uint256 total;
        bool isOnline;
    }

    Counters.Counter private _currentOrderId;
    PayInfo mapiToken;
    PayInfo usdtToken;

    address public admin;

    /// @dev <seller,orderId[]>
    mapping(address => uint256[]) private onLineItems;
    /// @dev <orderId,Item>
    mapping(uint256 => Item) private allItems;

    bool private stopped;

    event PutOn(address indexed seller, uint256 orderId);
    event Off(uint256 orderId, uint256 quantity);
    event Buy(address indexed buyer, uint256 orderId);

    modifier canBuy(uint256 _orderId) {
        uint256 _quantity = 1;
        require(_quantity > 0, "Quantity error");
        require(allItems[_orderId].quantity > 0, "Out of stock");
        require(allItems[_orderId].quantity >= _quantity, "Low stocks");
        require(allItems[_orderId].isOnline == true, "Can not buy");
        require(
            allItems[_orderId].seller != _msgSender(),
            "Can not buy your owner goods"
        );
        require(!stopped, "Pause time");
        _;
    }

    modifier canPutOn() {
        require(!stopped, "Pause time");
        _;
    }

    modifier sellerOnly(uint256 _orderId) {
        require(
            allItems[_orderId].seller == _msgSender(),
            "ONLY_SELLER_ALLOWED"
        );
        _;
    }

    modifier adminOnly() {
        require(admin == _msgSender(), "ONLY_ADMIN_ALLOWED");
        _;
    }

    function initialize(address _admin) public initializer {
        admin = _admin;
        stopped = true;
        __Ownable_init();
    }

    function putOnByMapi(
        address _tokenAddr,
        uint256 _tokenId,
        uint256 _price
    ) external canPutOn returns (uint256) {
        uint256 _quantity = 1;
        require(_price > 0, "price error");
        require(_quantity > 0, "quantity error");
        require(_tokenId > 0, "tokenId error");
        // require(_tokenAddr.isContract(), "token address error");

        return _putOn(PayMod.MAPI, _tokenAddr, _tokenId, _price, _quantity);
    }

    function putOnByUsdt(
        address _tokenAddr,
        uint256 _tokenId,
        uint256 _price
    ) external canPutOn returns (uint256) {
        uint256 _quantity = 1;
        require(_price > 0, "price error");
        require(_quantity > 0, "quantity error");
        require(_tokenId > 0, "tokenId error");
        // require(_tokenAddr.isContract(), "token address error");

        return _putOn(PayMod.USDT, _tokenAddr, _tokenId, _price, _quantity);
    }

    function _putOn(
        PayMod _payMod,
        address _tokenAddr,
        uint256 _tokenId,
        uint256 _price,
        uint256 _quantity
    ) internal returns (uint256) {
        _currentOrderId.increment();
        uint256 _orderId = _currentOrderId.current();

        NftInfo memory nft = NftInfo(_tokenAddr, _tokenId);
        Item memory item = Item(
            _orderId,
            nft,
            _payMod,
            _msgSender(),
            _price,
            _quantity,
            _quantity,
            true
        );

        IERC721 nftToken = IERC721(_tokenAddr);
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);

        onLineItems[_msgSender()].push(_orderId);
        allItems[_orderId] = item;
        emit PutOn(_msgSender(), _orderId);
        return _orderId;
    }

    function buyByMapi(uint256 _orderId)
        external
        canBuy(_orderId)
        returns (uint256)
    {
        require(allItems[_orderId].payMod == PayMod.MAPI, "PayMod error");
        uint256 _quantity = 1;
        uint256 price = allItems[_orderId].price;
        uint256 total = price.mul(_quantity);
        uint256 fee = calculateFeeMapi(total);

        IERC20 token = IERC20(mapiToken.erc20);
        require(
            buy(token, _orderId, _quantity, fee) == true,
            "buyByMapi success"
        );

        return _orderId;
    }

    function buyByUsdt(uint256 _orderId)
        external
        canBuy(_orderId)
        returns (uint256)
    {
        uint256 _quantity = 1;
        require(allItems[_orderId].payMod == PayMod.USDT, "PayMod error");

        uint256 price = allItems[_orderId].price;
        uint256 total = price.mul(_quantity);
        uint256 fee = calculateFeeUsdt(total);

        IERC20 token = IERC20(usdtToken.erc20);
        require(
            buy(token, _orderId, _quantity, fee) == true,
            "buyByUsdt success"
        );
        return _orderId;
    }

    function buy(
        IERC20 _token,
        uint256 _orderId,
        uint256 _quantity,
        uint256 fee
    ) internal returns (bool) {
        uint256 price = allItems[_orderId].price;
        uint256 total = price.mul(_quantity);
        uint256 amount = total.sub(fee);
        address seller = allItems[_orderId].seller;
        if (fee > 0) _token.safeTransferFrom(_msgSender(), address(this), fee);
        _token.safeTransferFrom(_msgSender(), seller, amount);
        allItems[_orderId].quantity = allItems[_orderId].quantity.sub(
            _quantity
        );
        require(allItems[_orderId].quantity >= 0, "buy failed");

        require(
            transferNftTo(_msgSender(), _orderId) == true,
            "nft transfer fail"
        );

        emit Buy(_msgSender(), _orderId);
        return true;
    }

    function off(uint256 _orderId)
        public
        sellerOnly(_orderId)
        returns (uint256)
    {
        require(allItems[_orderId].isOnline == true, "Item has been off");
        uint256 left = 0;
        if (allItems[_orderId].quantity > 0) {
            Item memory item = allItems[_orderId];
            NftInfo memory nft = item.token;
            left = item.quantity;
            IERC721 nftToken = IERC721(nft.contractAddress);
            nftToken.safeTransferFrom(address(this), item.seller, nft.tokenId);
        }

        allItems[_orderId].isOnline = false;
        allItems[_orderId].quantity = 0;
        emit Off(_orderId, left);
        return _orderId;
    }

    function calculateFeeMapi(uint256 _total) internal view returns (uint256) {
        return _total.mul(mapiToken.fee).div(10000);
    }

    function setFeeMapi(uint256 _fee) external adminOnly {
        mapiToken.fee = _fee;
    }

    function setMapiAddress(address _addr) external adminOnly {
        mapiToken.erc20 = _addr;
        mapiToken.payMod = PayMod.MAPI;
    }

    function feeMapi() external view returns (uint256) {
        return mapiToken.fee;
    }

    function mapiAddress() external view returns (address) {
        return mapiToken.erc20;
    }

    function calculateFeeUsdt(uint256 _total) internal view returns (uint256) {
        return _total.mul(usdtToken.fee).div(10000);
    }

    function setFeeUsdt(uint256 _fee) external adminOnly {
        usdtToken.fee = _fee;
    }

    function setUsdtAddress(address _addr) external adminOnly {
        usdtToken.erc20 = _addr;
        usdtToken.payMod = PayMod.USDT;
    }

    function feeUsdt() external view returns (uint256) {
        return usdtToken.fee;
    }

    function usdtAddress() external view returns (address) {
        return usdtToken.erc20;
    }

    function orderInfo(uint256 _orderId) external view returns (Item memory) {
        return allItems[_orderId];
    }

    function orderIdsOf(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        return onLineItems[_seller];
    }

    function setAdmin(address _admin) external adminOnly {
        admin = _admin;
    }

    function contractAddress() public view returns (address) {
        return address(this);
    }

    function currentOrderId() public view returns (uint256) {
        return _currentOrderId.current();
    }

    function getNftInfo(uint256 _orderId) public view returns (NftInfo memory) {
        return allItems[_orderId].token;
    }

    function transferNftTo(address to, uint256 _orderId)
        internal
        returns (bool)
    {
        NftInfo memory nft = allItems[_orderId].token;
        IERC721 nftToken = IERC721(nft.contractAddress);
        nftToken.safeTransferFrom(address(this), to, nft.tokenId);
        return true;
    }

    function setStopped(bool _value) external adminOnly returns (bool) {
        stopped = _value;
        return stopped;
    }

    function isStopped() external view returns (bool) {
        return stopped;
    }

    function withdraw() external adminOnly {
        IERC20 usdt = IERC20(usdtToken.erc20);
        IERC20 mapi = IERC20(mapiToken.erc20);

        uint256 usdtAmount = usdt.balanceOf(address(this));
        uint256 mapiAmount = mapi.balanceOf(address(this));
        if (usdtAmount > 0) usdt.safeTransfer(owner(), usdtAmount);
        if (mapiAmount > 0) mapi.safeTransfer(owner(), mapiAmount);
    }
}