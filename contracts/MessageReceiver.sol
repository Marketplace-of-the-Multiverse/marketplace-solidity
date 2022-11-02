//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol";

// https://ethereum.stackexchange.com/questions/24713/how-can-a-deployed-contract-call-another-deployed-contract-by-interface-and-ad
// describe the interface
contract NFTMarketplace{
    // empty because we're not concerned with internal details
    function getListPrice() public view returns (uint256) {}
    function createToken(string memory tokenURI) public payable returns (uint) {}
    function executeSale(address recipient, uint256 tokenId) public payable {}
    function addFund(address recipient, uint256 amount) public {}
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

        // we cnanot approve contract like this, axelar txs will stucked and have to manually approve in axelarscan
        // IERC20(tokenAddress).approve(address(nftMarket), amount);

        // transfer user balance to nftMarket (custody)
        IERC20(tokenAddress).transfer(address(nftMarket), amount);

        // update user balance
        nftMarket.addFund(recipient, amount);

        // execute buy nft call
        nftMarket.executeSale(recipient, tokenId);

        emit Transfer(address(this), address(nftMarket), amount);
        emit Executed();
    }
}
