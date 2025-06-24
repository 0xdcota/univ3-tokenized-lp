require("dotenv").config();
const { ethers, JsonRpcProvider } = require("ethers");
const { logNewLine, logData } = require("../utils");
const {
  executeSwapIdle,
  getCurrentBounds,
  getIdleBalances,
  getToken1AmtInToken0,
} = require("./lp-utils");

const erc20Artifact = require("../../out/ERC20.sol/ERC20.json");
const tokenizedLpArtifact = require("../../out/UniswapV3TokenizedLp.sol/UniswapV3TokenizedLp.json");

/// Main action function
const actionFn = async () => {
  console.log(
    "------------------------------------------------------------------"
  );
  logNewLine("INF", "starting lp-idle routine");

  const chain = {
    chainId: process.env.LOCAL_CHAIN_ID.toString(),
    rpc: process.env.LOCAL_RPC,
    lpTokenAddr: process.env.LOCAL_LP_TOKEN_ADDR,
    token0Addr: process.env.LOCAL_TOKEN0_ADDR,
    token0Name: process.env.LOCAL_TOKEN0_NAME,
    token0Decimals: Number(process.env.LOCAL_TOKEN0_DECIMALS),
    token1Addr: process.env.LOCAL_TOKEN1_ADDR,
    token1Name: process.env.LOCAL_TOKEN1_NAME,
    token1Decimals: Number(process.env.LOCAL_TOKEN1_DECIMALS),
    token0IdleThreshold: process.env.LOCAL_TOKEN0_IDLE_THRESHOLD,
  };

  logData(`Chain: ${chain.chainId}`);
  logData(`rpc: ${chain.rpc}`);
  logData(`lpTokenAddr: ${chain.lpTokenAddr}`);
  logData(
    `token0Addr: ${chain.token0Addr}, ${chain.token0Name}, decimals: ${chain.token0Decimals}`
  );
  logData(
    `token1Addr: ${chain.token1Addr}, ${chain.token1Name}, decimals: ${chain.token1Decimals}`
  );
  logData(
    `token0IdleThreshold: ${ethers.formatUnits(
      chain.token0IdleThreshold,
      chain.token0Decimals
    )}`
  );

  // Throw if any required env vars are missing
  if (!chain.chainId)
    throw `Please define LOCAL_CHAIN_ID in pm2-ecosystem.config.js`;
  if (!chain.rpc) throw `Please define LOCAL_RPC in pm2-ecosystem.config.js`;
  if (!chain.lpTokenAddr)
    throw `Please define LOCAL_LP_TOKEN_ADDR in pm2-ecosystem.config.js`;
  if (!chain.token0Addr)
    throw `Please define LOCAL_TOKEN0_ADDR in pm2-ecosystem.config.js`;
  if (!chain.token0Name)
    throw `Please define LOCAL_TOKEN0_NAME in pm2-ecosystem.config.js`;
  if (!chain.token0Decimals)
    throw `Please define LOCAL_TOKEN0_DECIMALS in pm2-ecosystem.config.js`;
  if (!chain.token1Addr)
    throw `Please define LOCAL_TOKEN1_ADDR in pm2-ecosystem.config.js`;
  if (!chain.token1Name)
    throw `Please define LOCAL_TOKEN1_NAME in pm2-ecosystem.config.js`;
  if (!chain.token1Decimals)
    throw `Please define LOCAL_TOKEN1_DECIMALS in pm2-ecosystem.config.js`;
  if (!chain.token0IdleThreshold)
    throw `Please define LOCAL_TOKEN0_IDLE_THRESHOLD in pm2-ecosystem.config.js`;
  if (!process.env.PRIVATE_KEY) throw `Please define PRIVATE_KEY in .env file`;

  /// Build contract instances
  const provider = new JsonRpcProvider(chain.rpc, undefined, {
    staticNetwork: true,
  });
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
  const signer = wallet.connect(provider);
  const tokenizedLp = new ethers.Contract(
    chain.lpTokenAddr,
    tokenizedLpArtifact.abi,
    signer
  );

  const token0Contract = new ethers.Contract(
    chain.token0Addr,
    erc20Artifact.abi,
    signer
  );
  const token1Contract = new ethers.Contract(
    chain.token1Addr,
    erc20Artifact.abi,
    signer
  );
  let success = true;

  const { idlingToken0, idlingToken1 } = await getIdleBalances(
    token0Contract,
    chain.token0Decimals,
    token1Contract,
    chain.token1Decimals,
    chain.lpTokenAddr
  );
  if (idlingToken0 == undefined || idlingToken1 == undefined) {
    success = false;
  }

  const idlingToken1InToken0 = await getToken1AmtInToken0(
    idlingToken1,
    chain.token0Addr,
    chain.token0Decimals,
    chain.token1Addr,
    chain.token1Decimals,
    tokenizedLp
  );
  if (idlingToken1InToken0 == undefined) {
    success = false;
  }

  const { bpsLower, bpsUpper } = await getCurrentBounds(
    tokenizedLp,
    chain.token0Decimals,
    chain.token1Decimals
  );
  if (bpsLower == undefined || bpsUpper == undefined) {
    success = false;
  }
  const range = bpsLower + bpsUpper;

  const [swapWhichTokenContract, swapDecimals] =
    idlingToken0 > idlingToken1InToken0
      ? [token0Contract, chain.token0Decimals]
      : [token1Contract, chain.token1Decimals];
  const compareIdleAmount =
    idlingToken0 > idlingToken1InToken0 ? idlingToken0 : idlingToken1InToken0;
  const swapAmount =
    idlingToken0 > idlingToken1InToken0
      ? (idlingToken0 * bpsLower) / range
      : (idlingToken1 * bpsUpper) / range;

  const direction = swapWhichTokenContract.target == chain.token0Addr ? 1 : -1;
  const formatCompareIdleAmount = Number(
    ethers.formatUnits(compareIdleAmount, chain.token0Decimals)
  ).toFixed(8);
  const formatThreshold = Number(
    ethers.formatUnits(chain.token0IdleThreshold, chain.token0Decimals)
  ).toFixed(8);
  const formatSwapAmount = Number(
    ethers.formatUnits(swapAmount, swapDecimals)
  ).toFixed(8);

  logNewLine(
    "INF",
    `should swap?: ${
      BigInt(compareIdleAmount) > BigInt(chain.token0IdleThreshold)
    }, idleAmount: ${formatCompareIdleAmount} > threshold: ${formatThreshold}`
  );

  if (BigInt(compareIdleAmount) > BigInt(chain.token0IdleThreshold)) {
    logData(
      `swapWhich: ${
        swapWhichTokenContract.target == chain.token0Addr
          ? chain.token0Name
          : chain.token1Name
      }, swapAmount: ${formatSwapAmount}`
    );

    logNewLine("INF", "attempt to swap idle amount...");
    const { amount0, amount1 } = await executeSwapIdle(
      tokenizedLp,
      swapAmount,
      swapDecimals,
      direction,
      chain.token0Decimals,
      chain.token1Decimals,
      false
    );
    if (amount0 == undefined || amount1 == undefined) {
      success = false;
    }
  }

  if (!success) {
    logNewLine("ERR", `failed execution lp-idle`);
  } else {
    logNewLine("INF", "lp-idle routine complete!");
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
