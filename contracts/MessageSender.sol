//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

contract MessageSender {
    IAxelarGasService immutable gasReceiver;
    IAxelarGateway immutable gateway;

    // struct OrderInfo {
    //     uint256 tokenId;
    //     string symbol;
    //     uint256 amount;
    // }

    constructor(address _gateway, address _gasReceiver) {
        gateway = IAxelarGateway(_gateway);
        gasReceiver = IAxelarGasService(_gasReceiver);
    }

    function crossChainDelist(
        string calldata destinationChain,
        string calldata destinationAddress,
        uint256 tokenId
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // delist action = 0
        bytes memory payload = abi.encode(msg.sender, 0, "", tokenId, 0, 0, "");

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function crossChainList(
        string calldata destinationChain,
        string calldata destinationAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // list action = 1
        bytes memory payload = abi.encode(msg.sender, 1, "", tokenId, amount, deadline, signature);

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function crossChainMint(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata tokenUrl
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // mint action = 2
        bytes memory payload = abi.encode(msg.sender, 2, tokenUrl, 0, 0, 0, "");

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function crossChainBuy(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount,
        uint256 tokenId
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);

        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case
        bytes memory payload = abi.encode(msg.sender, tokenId);

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCallWithToken{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                symbol,
                amount,
                msg.sender
            );
        }

        gateway.callContractWithToken(
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            amount
        );
    }
}
