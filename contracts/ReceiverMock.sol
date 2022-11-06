//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


// https://ethereum.stackexchange.com/questions/24713/how-can-a-deployed-contract-call-another-deployed-contract-by-interface-and-ad
// describe the interface
contract NFTMarketplace{
    // empty because we're not concerned with internal details
    function getListPrice() public view returns (uint256) {}
    function createToken(string memory tokenURI) public payable returns (uint) {}
    function getOwner() public view returns (address) {}
    function crossExecuteSale(address recipient, uint256 tokenId) public payable {}
    function crossCreateToken(address recipient, string memory tokenURI) public payable {}
    function crossSetListToken(address recipient, uint256 tokenId, uint256 price, uint deadline, bytes memory signature) public {}
    function crossDelistToken(address recipient, uint256 tokenId) public {}
}

contract ReceiverMock {
    address owner;
    NFTMarketplace nftMarket;

    constructor(address _nftMarket)
    {
        nftMarket = NFTMarketplace(_nftMarket);
    }

    function getMarketplace() public view returns (address) {
        return address(nftMarket);
    }

    function setMarketplace(address _nftMarket) public {
        require(owner == msg.sender, "Only owner can set marketplace");
        nftMarket = NFTMarketplace(_nftMarket);
    }

    function execute(
        address recipient,
        string memory action,
        string memory tokenUrl,
        uint256 listTokenId,
        uint256 listPrice,
        uint256 deadline,
        bytes memory signature
    ) public {
        // (
        //     address recipient,
        //     string memory action,
        //     string memory tokenUrl,
        //     uint256 listTokenId,
        //     uint256 listPrice,
        //     uint256 deadline,
        //     bytes memory signature
        // ) = abi.decode(payload, (address, string, string, uint256, uint256, uint256, bytes));
            nftMarket.crossSetListToken(recipient, listTokenId, listPrice, deadline, signature);
    }
}
