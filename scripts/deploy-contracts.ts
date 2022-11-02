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
const moonbeamChain = chains.find((chain: any) => chain.name === "Moonbeam");
const avalancheChain = chains.find((chain: any) => chain.name === "Avalanche");

// get axelar asset (usdc)
const moonbeamUsdc = '0xD1633F7Fb3d716643125d6415d4177bC36b7186b';
const avalancheUsdc = '0x57F1c63497AEe0bE305B8852b354CEc793da43bB';

// deploy script
async function main() {
  /**
   * DEPLOY ON MOONBEAM
   */
  const moonbeamProvider = getDefaultProvider(moonbeamChain.rpc);
  const moonbeamConnectedWallet = wallet.connect(moonbeamProvider);

  const moonbeamSender = await deployContract(
    moonbeamConnectedWallet,
    MessageSenderContract,
    [moonbeamChain.gateway, moonbeamChain.gasReceiver],
  );
  console.log("MessageSender deployed on Moonbeam:", moonbeamSender.address);
  moonbeamChain.messageSender = moonbeamSender.address;

  const moonbeamReceiver = await deployContract(
    moonbeamConnectedWallet,
    MessageReceiverContract,
    [moonbeamChain.gateway, moonbeamChain.gasReceiver],
  );
  console.log( "MessageReceiver deployed on Moonbeam:", moonbeamReceiver.address );
  moonbeamChain.messageReceiver = moonbeamReceiver.address;


  const moonbeamMarketplace = await deployContract(
    moonbeamConnectedWallet,
    MarketplaceContract,
    [moonbeamReceiver.address, moonbeamUsdc],
  );
  console.log( "MarketplaceContract deployed on Moonbeam:", moonbeamMarketplace.address, );
  moonbeamChain.nftMarketplace = moonbeamMarketplace.address;

  await (await moonbeamMarketplace.createToken('https://api.npoint.io/efaecf7cee7cfe142516')).wait(1);
  console.log('Minted nft in Moonbeam');
  await (await moonbeamMarketplace.setListToken(1, ethers.utils.parseUnits('0.1', 6))).wait(1);
  console.log('Listed nft in Moonbeam');
  // set nftMarketplace on MessageReceiver
  await (await moonbeamReceiver.setMarketplace(moonbeamMarketplace.address)).wait(1);
  console.log('Set moonbeamMarketplace to receiver');

  /**
   * DEPLOY ON AVALANCHE
   */
  const avalancheProvider = getDefaultProvider(avalancheChain.rpc);
  const avalancheConnectedWallet = wallet.connect(avalancheProvider);
  const avalancheSender = await deployContract(
    avalancheConnectedWallet,
    MessageSenderContract,
    [avalancheChain.gateway, avalancheChain.gasReceiver],
  );
  console.log("MessageSender deployed on Avalanche:", avalancheSender.address);
  avalancheChain.messageSender = avalancheSender.address;


  const avalancheReceiver = await deployContract(
    avalancheConnectedWallet,
    MessageReceiverContract,
    [avalancheChain.gateway, avalancheChain.gasReceiver],
  );
  console.log(
    "MessageReceiver deployed on Avalanche:",
    avalancheReceiver.address,
  );
  avalancheChain.messageReceiver = avalancheReceiver.address;


  const avalancheMarketplace = await deployContract(
    avalancheConnectedWallet,
    MarketplaceContract,
    [avalancheReceiver.address, avalancheUsdc],
  );
  console.log(
    "MarketplaceContract deployed on Avalanche:",
    avalancheMarketplace.address,
  );
  avalancheChain.nftMarketplace = avalancheMarketplace.address;

  await (await avalancheMarketplace.createToken('https://api.npoint.io/7a8a7902a4ee5625dec2')).wait(1);
  console.log('Minted nft in Avalanche');
  await (await avalancheMarketplace.setListToken(1, ethers.utils.parseUnits('0.1', 6))).wait(1);
  console.log('Listed nft in Avalanche');
  // set nftMarketplace on MessageReceiver
  await (await avalancheReceiver.setMarketplace(avalancheMarketplace.address)).wait(1);
  console.log('Set avalancheMarketplace to receiver');


  // update chains
  const updatedChains = [moonbeamChain, avalancheChain];
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
