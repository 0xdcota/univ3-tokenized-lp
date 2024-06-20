require("dotenv").config();
const { ethers } = require("ethers");
const { logNewLine } = require("../utils");

const UNIV3_TOKENIZED_ABI = [
  "function autoRebalance() public",
  "function rebalance(int24 baseLower, int24 baseUpper, int256 swapQuantity) public",
  "fetchOracle(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut)",
  "fetchSpot(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut)",
];

/// Main action function
const actionFn = async () => {
  logNewLine("INFO", "Starting uniswapV3 lp auto-rebalance routine...");

  const chain = {
    chainId: process.env.LOCAL_CHAIN_ID.toString(),
    lpAddr: process.env.LOCAL_LP_ADDR,
    rpc: process.env.LOCAL_RPC,
  };
  console.log(`Chain: ${chain.chainId}`);
  console.log(`Lp Address: ${chain.lpAddr}`);
  console.log(`RPC: ${chain.rpc}`);

  if (!chain.chainId)
    throw `Please define LOCAL_CHAIN_ID in pm2-ecosystem.config.js`;
  if (!chain.rpc) throw `Please define LOCAL_RPC in pm2-ecosystem.config.js`;

  const provider = new ethers.providers.JsonRpcProvider(chain.rpc);
  if (!process.env.PRIVATE_KEY) throw "Please set PRIVATE_KEY in .env";
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
  const signer = wallet.connect(provider);
  console.log(`Signer: ${signer.address}`);

  const tokenizedLP = new ethers.Contract(
    chain.lpAddr,
    UNIV3_TOKENIZED_ABI,
    signer
  );

  logNewLine("INFO", "reading if autorebalance must be executed");

  let mustExecute = false;
  try {
    mustExecute = await tokenizedLP.staticCall.autoRebalance();
  } catch (error) {
    logNewLine("ERROR", "failed to static-read autoRebalance result");
    console.log(error);
  }

  if (mustExecute) {
    logNewLine("INFO", "executing autoRebalance...");
    try {
      const tx = await tokenizedLP.autoRebalance();
      await tx.wait();
      logNewLine("INFO", `tx hash: ${tx.hash}`);
      logNewLine("INFO", "autoRebalance executed successfully!");
    } catch (error) {
      logNewLine("ERROR", "failed to execute autoRebalance");
      console.log(error);
    }
  } else {
    logNewLine("INFO", "no need to autoRebalance");
  }
};

// Do not change this.
if (require.main === module) {
  actionFn()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

exports.actionFn = actionFn;
