//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol";

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

// https://ethereum.stackexchange.com/questions/24713/how-can-a-deployed-contract-call-another-deployed-contract-by-interface-and-ad
// describe the interface
contract NFTMarketplace{
    // empty because we're not concerned with internal details
    function getListPrice() public view returns (uint256) {}
    function createToken(string memory tokenURI) public payable returns (uint) {}
    function executeCrossSale(address recipient, uint256 tokenId) public payable {}
    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {}
    function getOwner() public view returns (address) {}
}

contract MessageReceiver is AxelarExecutable {
    IAxelarGasService immutable gasReceiver;
    //owner is the contract address that created the smart contract
    address owner;
    NFTMarketplace nftMarket;

    constructor(address _gateway, address _gasReceiver)
        AxelarExecutable(_gateway)
    {
        gasReceiver = IAxelarGasService(_gasReceiver);
        owner = payable(msg.sender);
    }

    function getMarketplace() public view returns (address) {
        return address(nftMarket);
    }

    function setMarketplace(address _nftMarket) public {
        require(owner == msg.sender, "Only owner can set marketplace");
        nftMarket = NFTMarketplace(_nftMarket);
    }

    event Executed();
    event Failed(string reason);
    event Transfer(address indexed from, address indexed to, uint256 value);


    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        // decode payload
        (
            address recipient,
            uint256 tokenId
        ) = abi.decode(payload, (address, uint256));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);

        // we cannot approve contract like this, axelar txs will stucked and need to manually approve in axelarscan
        // axlToken.approve(address(nftMarket), amount);

        // transfer user balance to nftMarket (custody) - not working as execution and token transfer in same txs
        // user balance haven't get updated / commited into the block
        // therefore when we check user balance in the NftMarket contract, the data up to date
        // axlToken.transfer(address(nftMarket), amount);

        // get seller and owner info from listedInfo
        ListedToken memory targetToken = nftMarket.getListedTokenForId(tokenId);
        IERC20 axlToken = IERC20(tokenAddress);

        if (amount != targetToken.price) {
            // if sent amount is not tally with nft price, deposit to user wallet
            axlToken.transfer(recipient, amount);
            emit Failed("Nft price and payment not tally");

        } else if (targetToken.currentlyListed != true) {
            // stop purchasing off list nft
            axlToken.transfer(recipient, amount);
            emit Failed("Nft is not on sale");

        } else if (targetToken.reservedUntil < block.timestamp && recipient == targetToken.lastReservedBy) {
            // prevent contract call by non-reserved person before the reservedUtil expired
            axlToken.transfer(recipient, amount);
            emit Failed("NFT is currently reserved by someone else");

        } else {
            //Transfer the proceeds from the sale to the seller of the NFT
            uint listPrice = nftMarket.getListPrice();
            address marketplaceOwner = nftMarket.getOwner();
            uint sellerPayment = targetToken.price - listPrice;

            axlToken.transfer(targetToken.seller, sellerPayment);

            //Transfer the listing fee to the marketplace creator
            axlToken.transfer(marketplaceOwner, listPrice);

            // execute transfer nft call
            nftMarket.executeCrossSale(recipient, tokenId);

            // cannot manually emit like this
            // emit Transfer(address(this), address(targetToken.seller), sellerPayment);
            // emit Transfer(address(this), address(marketplaceOwner), listPrice);
        }

        emit Executed();
    }
}
