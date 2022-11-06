import { Contract, ethers, getDefaultProvider, providers, BigNumber } from "ethers";
import {
  AxelarQueryAPI,
  Environment,
  EvmChain,
  GasToken,
} from "@axelar-network/axelarjs-sdk";

import AxelarGatewayContract from "../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol/IAxelarGateway.json";
import MessageSenderContract from "../artifacts/contracts/MessageSender.sol/MessageSender.json";
import MessageReceiverContract from "../artifacts/contracts/MessageReceiver.sol/MessageReceiver.json";
import NFTMarketplace from "../artifacts/contracts/NFTMarketplace.sol/NFTMarketplace.json";
import IERC20 from "../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol/IERC20.json";
import { isTestnet, wallet } from "../config/constants";
import { TypedDataDomain } from "@ethersproject/abstract-signer";
import _ from "lodash";

console.log(isTestnet);
let chains = isTestnet
  ? require("../config/testnet.json")
  : require("../config/local.json");

// const moonbeamChain = chains.find(
//   (chain: any) => chain.name === "Moonbeam",
// ) as any;
_.find(chains, (chain:any) => chain.name === "BscTest")
const bscChain = _.find(chains, (chain:any) => chain.name === "BscTest");
const avalancheChain = _.find(chains, (chain:any) => chain.name === "Avalanche");

if (!bscChain || !avalancheChain) process.exit(0);

const useMetamask = false; // typeof window === 'object';

const bscProvider = useMetamask
  ? new providers.Web3Provider((window as any).ethereum)
  : getDefaultProvider(bscChain.rpc);
const bscConnectedWallet = useMetamask
  ? (bscProvider as providers.Web3Provider).getSigner()
  : wallet.connect(bscProvider);
const avalancheProvider = getDefaultProvider(avalancheChain.rpc);
const avalancheConnectedWallet = wallet.connect(avalancheProvider);

const srcGatewayContract = new Contract(
  avalancheChain.gateway,
  AxelarGatewayContract.abi,
  avalancheConnectedWallet,
);

const destGatewayContract = new Contract(
  bscChain.gateway,
  AxelarGatewayContract.abi,
  bscConnectedWallet,
);

const sourceContract = new Contract(
  avalancheChain.messageSender as string,
  MessageSenderContract.abi,
  avalancheConnectedWallet,
);

const destContract = new Contract(
  bscChain.messageReceiver as string,
  MessageReceiverContract.abi,
  bscConnectedWallet,
);

const destMarketplace = new Contract(
    bscChain.nftMarketplace as string,
    NFTMarketplace.abi,
    bscConnectedWallet,
);

export function generateRecipientAddress(): string {
  return ethers.Wallet.createRandom().address;
}

export async function mintTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE,
      GasToken.AVAX,
      1000000,
      2
    );

    const receipt = await sourceContract
      .crossChainMint(
        "Binance",
        destContract.address,
        "https://api.npoint.io/efaecf7cee7cfe142516",
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

  export async function delistTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE as EvmChain,
      GasToken.AVAX,
      1000000,
      2
    );

    const receipt = await sourceContract
      .crossChainDelist(
        "Binance",
        destContract.address,
        2,
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

  export async function listTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE,
      GasToken.AVAX,
      1000000,
      2
    );

    const tokenId = 2;
    // set deadline in 1 days
    const deadline = Math.round(Date.now() / 1000 + (7 * 24 * 60 * 60));

    const contractName = await destMarketplace.name();
    const nftNonce = await destMarketplace.nonces(tokenId);
    const signature = await sign(contractName, bscChain.nftMarketplace, bscChain.messageReceiver, tokenId, bscChain.chainId, nftNonce, deadline);
    console.log(`spender: ${bscChain.messageReceiver}`);
    console.log(`nonces: ${nftNonce}`);
    console.log(`contractName: ${contractName}`);
    console.log(`signature: ${signature}`);
    console.log(`deadline: ${deadline}`);

    // const payload = await ethers.utils.defaultAbiCoder.encode(
    //     ["address", "string", "string", "uint256", "uint256", "uint256", "bytes"],
    //     [
    //         "0x801Df8bD5C0C24D9B942a20627CAF1Bd34427804",
    //         "list",
    //         "",
    //         2,
    //         100000,
    //         deadline,
    //         signature
    //     ]
    // );

    // console.log(payload);

    // const decoded = await ethers.utils.defaultAbiCoder.decode(["address", "uint256", "string", "uint256", "uint256", "uint256", "bytes"], '0x0000000000000000000000001cc5f2f37a4787f02e18704d252735fb714f35ec000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000006370ec1000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004159d912d0c1da7967f0aae7369c305f4d2f99182b7ceabd986f7e0ce703e41e56575cb0d3a840f6713c61f5c66750e1fadcb0a5dc53167ec54c8c4d5d58001fb61b00000000000000000000000000000000000000000000000000000000000000');

    // console.log(decoded);

    const receipt = await sourceContract
      .crossChainList(
        "Binance",
        destContract.address,
        2,
        ethers.utils.parseUnits('0.1', 6),
        deadline,
        signature,
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

export async function sendTokenToDestChain(
  amount: string,
  recipientAddresses: string[],
  onSent: (txhash: string) => void,
) {
  // Get token address from the gateway contract
  const tokenAddress = await srcGatewayContract.tokenAddresses("aUSDC");

  const erc20 = new Contract(
    tokenAddress,
    IERC20.abi,
    avalancheConnectedWallet,
  );

  // Approve the token for the amount to be sent
  await erc20
    .approve(sourceContract.address, ethers.utils.parseUnits(amount, 6))
    .then((tx: any) => tx.wait());

  const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

  // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
  const gasFee = await api.estimateGasFee(
    EvmChain.AVALANCHE,
    EvmChain.BINANCE,
    GasToken.AVAX,
    1000000,
    2
  );

  console.log(`amount: ${ethers.utils.parseUnits(amount, 6)}`);
  const receipt = await sourceContract
    .crossChainBuy(
      "Binance",
      destContract.address,
      "aUSDC",
      ethers.utils.parseUnits(amount, 6),
      1,
      {
        value: BigInt(isTestnet ? gasFee : 3000000)
      },
    )
    .then((tx: any) => tx.wait());

  console.log({
    txHash: receipt.transactionHash,
  });
  onSent(receipt.transactionHash);

  // Wait destination contract to execute the transaction.
  return new Promise((resolve, reject) => {
    destContract.on("Executed", () => {
      destContract.removeAllListeners("Executed");
      resolve(null);
    });
  });
}

export function truncatedAddress(address: string): string {
  return (
    address.substring(0, 6) + "..." + address.substring(address.length - 4)
  );
}

export async function getBalance(addresses: string[], isSource: boolean) {
  const contract = isSource ? srcGatewayContract : destGatewayContract;
  const connectedWallet = isSource
    ? avalancheConnectedWallet
    : bscConnectedWallet;
  const tokenAddress = await contract.tokenAddresses("aUSDC");
  const erc20 = new Contract(tokenAddress, IERC20.abi, connectedWallet);
  const balances = await Promise.all(
    addresses.map(async (address) => {
      const balance = await erc20.balanceOf(address);
      return ethers.utils.formatUnits(balance, 6);
    }),
  );
  return balances;
}


// helper to sign using (spender, tokenId, nonce, deadline) EIP 712
async function sign(
    contractName: String,
    verifyingContract: String,
    spender: String,
    tokenId: number,
    chainId: number,
    nonce: BigNumber,
    deadline: number
  ) {

    const typedData = {
      types: {
        Permit: [
          { name: "spender", type: "address" },
          { name: "tokenId", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      primaryType: "Permit",
      domain: {
        name: contractName,
        version: "1",
        chainId: chainId,
        verifyingContract: verifyingContract,
      },
      message: {
        spender,
        tokenId,
        nonce,
        deadline
      },
    };

    // sign Permit
    // assume deployer is the owner
    const deployer = bscConnectedWallet;

    const signature = await deployer._signTypedData(
      typedData.domain as TypedDataDomain,
      { Permit: typedData.types.Permit },
      typedData.message
    );

    return signature;
  }