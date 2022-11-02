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

    function sendToOne(
        string calldata destinationChain,
        string calldata destinationAddress,
        address targetWallet,
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
        bytes memory payload = abi.encode(targetWallet, tokenId);

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
