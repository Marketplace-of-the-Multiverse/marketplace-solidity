//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721, ERC721Permit } from "@soliditylabs/erc721-permit/contracts/ERC721Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStoragePermit is ERC721Permit {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}


contract NFTMarketplace is ReentrancyGuard, ERC721URIStoragePermit {
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

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

    constructor(address _operator, address _receivingToken) ERC721Permit("NFTMarketplace", "NFTM") {
        // consider to use ownable
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
        owner = payable(msg.sender);
        operator = _operator;
        receivingToken = _receivingToken;
    }

    function safeTransferFromWithPermit(
        address from,
        address to,
        uint256 tokenId,
        uint256 deadline,
        bytes memory signature
    ) internal {
        require(msg.sender == operator, "Only operator can access this function");
        _permit(msg.sender, tokenId, deadline, signature);
        // safeTransferFrom(from, to, tokenId, "");
        _transfer(from, to, tokenId);
    }

    function getReceivingToken() public view returns (address) {
        return receivingToken;
    }

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

    function updateOperator(address _operator) public {
        require(owner == msg.sender, "Only owner can update operator");
        operator = _operator;
    }

    function updateListPrice(uint256 _listPrice) public {
        require(owner == msg.sender, "Only owner can update listing price");
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

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
    function crossCreateToken(address recipient, string memory tokenURI) public payable {
        require(msg.sender == operator, "Only operator can access this function");
        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        //Mint the NFT with tokenId newTokenId to the address who called createToken
        _safeMint(recipient, newTokenId);

        //Map the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)
        _setTokenURI(newTokenId, tokenURI);

        //Helper function to update Global variables and emit an event
        createListedToken(newTokenId, floorPrice, recipient);
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
        createListedToken(newTokenId, floorPrice, msg.sender);

        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price, address seller) private {
        //Make sure the sender sent enough ETH to pay for listing
        // require(msg.value >= listPrice, "Hopefully sending the correct price");
        //Just sanity check
        // require(price > 0, "Make sure the price isn't negative");

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

    function crossSetListToken(address recipient, uint256 tokenId, uint256 price, uint deadline, bytes memory signature) public {
        require(msg.sender == operator, "Only operator can access this function");
        //Just sanity check
        require(price > 0, "Make sure the price isn't negative");
        //Make sure the sender sent enough ETH to pay for listing
        require(price >= listPrice, "You need to include listing price in tx");

        // seller aka holder
        require(recipient == idToListedToken[tokenId].seller, "Only nft holder can toggle listing");

        //approve the marketplace to sell NFTs on your behalf
        // approve(address(this), tokenId);
        // _transfer(seller, address(this), tokenId);
        safeTransferFromWithPermit(recipient, address(this), tokenId, deadline, signature);

        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            address(this),
            recipient,
            price,
            true,
            block.timestamp,
            address(0x0)
        );

        idToListedToken[tokenId].price = price;
        idToListedToken[tokenId].currentlyListed = true;
    }

    function setListToken(uint256 tokenId, uint256 price) public {
        //Just sanity check
        require(price > 0, "Make sure the price isn't negative");
        //Make sure the sender sent enough ETH to pay for listing
        require(price >= listPrice, "You need to include listing price in tx");

        // seller aka holder
        address seller = msg.sender;

        require(seller == idToListedToken[tokenId].seller, "Only nft holder can toggle listing");

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

    function crossDelistToken(address recipient, uint256 tokenId) public {
        require(msg.sender == operator, "Only operator can access this function");
        require(recipient == idToListedToken[tokenId].seller, "Only nft holder can toggle listing");

        //approve the marketplace to sell NFTs on your behalf
        _transfer(address(this), recipient, tokenId);

        idToListedToken[tokenId].currentlyListed = false;
    }

    function delistToken(uint256 tokenId) public {
        require(msg.sender == idToListedToken[tokenId].seller, "Only nft holder can toggle listing");

        //approve the marketplace to sell NFTs on your behalf
        _transfer(address(this), msg.sender, tokenId);

        idToListedToken[tokenId].currentlyListed = false;
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

    function crossExecuteSale(address recipient, uint256 tokenId) public {
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

        // reset reserved state
        idToListedToken[tokenId].reservedUntil = block.timestamp;
        idToListedToken[tokenId].lastReservedBy = address(0x0);
    }
}