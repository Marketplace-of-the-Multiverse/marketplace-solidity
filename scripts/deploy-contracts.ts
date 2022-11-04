import fs from "fs/promises";
import { getDefaultProvider } from "ethers";
import { isTestnet, wallet } from "../config/constants";
import { ethers } from "ethers";

const {
  utils: { deployContract },
} = require("@axelar-network/axelar-local-dev");

// load contracts
const MessageSenderContract = require("../artifacts/contracts/MessageSender.sol/MessageSender.json");
const MessageReceiverContract = require("../artifacts/contracts/MessageReceiver.sol/MessageReceiver.json");

const MarketplaceContract = require("../artifacts/contracts/NFTMarketplace.sol/NFTMarketplace.json");

let chains = isTestnet
  ? require("../config/testnet.json")
  : require("../config/local.json");

// get chains
let moonbeamChain = chains.find((chain: any) => chain.name === "Moonbeam");
let avalancheChain = chains.find((chain: any) => chain.name === "Avalanche");
let bscChain = chains.find((chain: any) => chain.name === "BscTest");
let polygonChain = chains.find((chain: any) => chain.name === "Mumbai");

async function deploy(chain: any, tokenUrl: string) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const sender = await deployContract(
        connectedWallet,
        MessageSenderContract,
        [chain.gateway, chain.gasReceiver],
      );
      console.log(`MessageSender deployed on ${chain.name}:`, sender.address);
      chain.messageSender = sender.address;

      const receiver = await deployContract(
        connectedWallet,
        MessageReceiverContract,
        [chain.gateway, chain.gasReceiver],
      );
      console.log( `MessageReceiver deployed on ${chain.name}:`, receiver.address );
      chain.messageReceiver = receiver.address;

      const marketplace = await deployContract(
        connectedWallet,
        MarketplaceContract,
        [receiver.address, chain.crossChainToken],
      );
      console.log( `MarketplaceContract deployed on ${chain.name}:`, marketplace.address, );
      chain.nftMarketplace = marketplace.address;

      await (await marketplace.createToken(tokenUrl)).wait(1);
      console.log(`Minted nft in ${chain.name}`);

      await (await marketplace.setListToken(1, ethers.utils.parseUnits('0.1', 6))).wait(1);
      console.log(`Listed nft in ${chain.name}`);
      // set nftMarketplace on MessageReceiver
      await (await receiver.setMarketplace(marketplace.address)).wait(1);
      console.log(`Set marketplace [${marketplace.address}] to ${chain.name} receiver`);

      return chain;
}

// deploy script
async function main() {
  /**
   * DEPLOY ON MOONBEAM
   */
    moonbeamChain = await deploy(moonbeamChain, 'https://api.npoint.io/efaecf7cee7cfe142516');

  /**
   * DEPLOY ON AVALANCHE
   */
    avalancheChain = await deploy(avalancheChain, 'https://api.npoint.io/7a8a7902a4ee5625dec2');

  /**
   * DEPLOY ON BSC
   */
    bscChain = await deploy(bscChain, 'https://api.npoint.io/efaecf7cee7cfe142516');

  /**
   * DEPLOY ON POLYGON
   */
    polygonChain = await deploy(polygonChain, 'https://api.npoint.io/7a8a7902a4ee5625dec2');


  // update chains
  const updatedChains = [moonbeamChain, avalancheChain, bscChain, polygonChain];
  if (isTestnet) {
    await fs.writeFile(
      "config/testnet.json",
      JSON.stringify(updatedChains, null, 2),
    );
  } else {
    await fs.writeFile(
      "config/local.json",
      JSON.stringify(updatedChains, null, 2),
    );
  }
}

main();
