//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard {

    using Counters for Counters.Counter;
    //_tokenIds variable has the most recent minted tokenId
    Counters.Counter private _tokenIds;
    //Keeps track of the number of items sold on the marketplace
    Counters.Counter private _itemsSold;
    //owner is the contract address that created the smart contract
    address payable owner;
    //The fee charged by the marketplace to be allowed to list an NFT
    uint256 listPrice = 0.05 * (10 ** 6);
    uint256 floorPrice = 0.1 * (10 ** 6);
    // store axelar receiver address (for execution verification)
    address operator;

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
        uint256 reservedUntil;
        address lastReservedBy;
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess (
        uint256 indexed tokenId,
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed,
        uint256 reservedUntil,
        address lastReservedBy
    );

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => ListedToken) private idToListedToken;

    address receivingToken;

    constructor(address _operator, address _receivingToken) ERC721("NFTMarketplace", "NFTM") {
        // consider to use ownable
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
        owner = payable(msg.sender);
        operator = _operator;
        receivingToken = _receivingToken;
    }

    function getReceivingToken() public view returns (address) {
        return receivingToken;
    }

    // function updateOperator(address _operator) public payable {
    function updateReceivingToken(address _receivingToken) public {
        require(owner == msg.sender, "Only owner can update receiving token");
        receivingToken = _receivingToken;
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    // function updateOperator(address _operator) public payable {
    function updateOperator(address _operator) public {
        require(owner == msg.sender, "Only owner can update operator");
        operator = _operator;
    }

    // function updateListPrice(uint256 _listPrice) public payable {
    function updateListPrice(uint256 _listPrice) public {
        require(owner == msg.sender, "Only owner can update listing price");
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    // function updateFloorPrice(uint256 _floorPrice) public payable {
    function updateFloorPrice(uint256 _floorPrice) public {
        require(owner == msg.sender, "Only owner can update floor price");
        floorPrice = _floorPrice;
    }

    function getFloorPrice() public view returns (uint256) {
        return floorPrice;
    }

    function getLatestIdToListedToken() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    //The first time a token is created, it is listed here
    function createToken(string memory tokenURI) public payable returns (uint) {
        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        //Mint the NFT with tokenId newTokenId to the address who called createToken
        _safeMint(msg.sender, newTokenId);

        //Map the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)
        _setTokenURI(newTokenId, tokenURI);

        //Helper function to update Global variables and emit an event
        createListedToken(newTokenId, floorPrice);

        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        //Make sure the sender sent enough ETH to pay for listing
        // require(msg.value >= listPrice, "Hopefully sending the correct price");
        //Just sanity check
        // require(price > 0, "Make sure the price isn't negative");

        address seller = msg.sender;

        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(seller),
            price,
            false,
            block.timestamp,
            address(0x0)
        );
    }

    function setListToken(uint256 tokenId, uint256 price) public {
        //Just sanity check
        require(price > 0, "Make sure the price isn't negative");
        //Make sure the sender sent enough ETH to pay for listing
        require(price >= listPrice, "You need to include listing price in tx");

        // seller aka holder
        address seller = msg.sender;

        require(seller == idToListedToken[tokenId].seller, "Only nft holder toggle listing");

        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), tokenId);
        _transfer(seller, address(this), tokenId);
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            address(this),
            seller,
            price,
            true,
            block.timestamp,
            address(0x0)
        );

        idToListedToken[tokenId].price = price;
        idToListedToken[tokenId].currentlyListed = true;
    }

    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint currentIndex = 0;

        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for(uint i=0;i<nftCount;i++)
        {
            uint currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender) {
                uint currentId = i+1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function executeCrossSale(address recipient, uint256 tokenId) public {
        require(msg.sender == operator, "Only operator can access this function");

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = false;
        idToListedToken[tokenId].seller = payable(recipient);
        _itemsSold.increment();

        _transfer(address(this), recipient, tokenId);

        // reset reserved state
        idToListedToken[tokenId].reservedUntil = block.timestamp;
        idToListedToken[tokenId].lastReservedBy = address(0x0);
    }

    // same chain sale
    function executeSale(uint256 tokenId) public payable {
        uint price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;
        // require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        // make sure it is a listed nft
        require(idToListedToken[tokenId].currentlyListed == true, "NFT is not on sale");

        // aka buyer
        address buyer = msg.sender;

        // check if buyer have enough balance to pay
        IERC20 axlToken = IERC20(receivingToken);

        // user allowance
        uint256 userAllowance = axlToken.allowance(address(msg.sender), address(this));
        // check for allowance
        require(userAllowance > 0, 'Insufficient allowance');

        require(axlToken.balanceOf(msg.sender) >= price, 'Insufficient payment');

        // prevent contract call by non-reserved person before the reservedUtil expired
        if (idToListedToken[tokenId].reservedUntil < block.timestamp) {
            require(buyer == idToListedToken[tokenId].lastReservedBy, "NFT currently reserved by someone else");
        }

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = false;
        idToListedToken[tokenId].seller = payable(buyer);
        _itemsSold.increment();

        //Transfer the proceeds from the sale to the seller of the NFT
        axlToken.transferFrom(msg.sender, seller, price);
        // payable(seller).transfer(msg.value);

        //Transfer the listing fee to the marketplace creator
        axlToken.transferFrom(msg.sender, owner, listPrice);
        // payable(owner).transfer(listPrice);


        //Actually transfer the token to the new owner
        _transfer(address(this), buyer, tokenId);
        //approve the marketplace to sell NFTs on your behalf
        // approve(address(this), tokenId);

        // reset reserved state
        idToListedToken[tokenId].reservedUntil = block.timestamp;
        idToListedToken[tokenId].lastReservedBy = address(0x0);
    }
}