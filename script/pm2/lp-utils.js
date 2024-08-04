const { logData, logNewLine } = require("../utils");
const { ethers } = require("ethers");
const { tickToPrice } = require("../uniV3-helpers");

const ONE_ETH = ethers.parseEther("1");

function tokenSorter(tokenA, tokenB) {
  return Number(tokenA) < Number(tokenB) ? [tokenA, tokenB] : [tokenB, tokenA];
}

async function getAUMBalances(tokenizedLpContract, token0Addr, token0Decimals, token1Addr, token1Decimals) {
  logNewLine("INF", "checking current AUM balances in tokenizedLp...");
  let aumToken0, aumToken1;
  try {
    const [total0, total1] =
      await tokenizedLpContract.getTotalAmountsFeeAccumulated.staticCall();
    [aumToken0, aumToken1] =
      Number(token0Addr) < Number(token1Addr)
        ? [total0, total1]
        : [total1, total0];
    logData(`aum token0: ${ethers.formatUnits(aumToken0, token0Decimals)}`);
    logData(`aum token1: ${ethers.formatUnits(aumToken1, token1Decimals)}`);
    return { aumToken0, aumToken1 };
  } catch (error) {
    logNewLine("ERR", `failed to get idle balances: ${error}`);
    aumToken0 = aumToken1 = undefined;
    return { aumToken0, aumToken1 };
  }
}

async function getIdleBalances(token0Contract, token0Decimals, token1Contract, token1Decimals, lpTokenAddr) {
  logNewLine("INF", "checking current idle balances...");
  let idlingToken0, idlingToken1;
  try {
    idlingToken0 = await token0Contract.balanceOf(lpTokenAddr);
    idlingToken1 = await token1Contract.balanceOf(lpTokenAddr);
    logData(`idle TOKEN0: ${ethers.formatUnits(idlingToken0, token0Decimals)}`);
    logData(`idle TOKEN1: ${ethers.formatUnits(idlingToken1, token1Decimals)}`);
    return { idlingToken0, idlingToken1 };
  } catch (error) {
    logNewLine("ERR", `failed to get idle balances: ${error}`);
    idlingToken0 = idlingToken1 = undefined;
    return { idlingToken0, idlingToken1 };
  }
}

async function getCurrentBounds(tokenizedLpContract, token0Decimals, token1Decimals) {
  logNewLine("INF", "checking current tick, and position bounds...");

  let lowerTick, upperTick, currentTick, bpsLower, bpsUpper;
  let concentration, concentrationTarget;
  try {
    lowerTick = await tokenizedLpContract.baseLower();
    upperTick = await tokenizedLpContract.baseUpper();
    currentTick = await tokenizedLpContract.currentTick();
    bpsLower = await tokenizedLpContract.bpsRangeLower();
    bpsUpper = await tokenizedLpContract.bpsRangeUpper();

    const currentTickPrice = tickToPrice(Number(currentTick.toString())) * 10 ** (token0Decimals - token1Decimals);
    const lowerTickPrice = tickToPrice(Number(lowerTick.toString())) * 10 ** (token0Decimals - token1Decimals);
    const upperTickPrice = tickToPrice(Number(upperTick.toString())) * 10 ** (token0Decimals - token1Decimals);

    const percentBelow =
      ((currentTickPrice - lowerTickPrice) / currentTickPrice) * 100;
    const percentBelowTarget = Number(bpsLower.toString()) / 100;
    const percentAbove =
      ((upperTickPrice - currentTickPrice) / currentTickPrice) * 100;
    const percentAboveTarget = Number(bpsUpper.toString()) / 100;

    concentration =
      percentBelow > percentAbove
        ? percentBelow / percentAbove
        : percentAbove / percentBelow;
    concentrationTarget =
      percentBelowTarget > percentAboveTarget
        ? percentBelowTarget / percentAboveTarget
        : percentAboveTarget / percentBelowTarget;

    logData(`baseLower PRICE: ${lowerTickPrice.toFixed(8)}`);
    logData(
      `           tick: ${lowerTick}, percent below: ${percentBelow.toFixed(
        5
      )} %, target: ${percentBelowTarget.toFixed(2)} %`
    );
    logData(`current   PRICE: ${currentTickPrice.toFixed(8)}`);
    logData(`           tick: ${currentTick}`);
    logData(`baseUpper PRICE: ${upperTickPrice.toFixed(8)}`);
    logData(
      `           tick: ${upperTick}, percent above: ${percentAbove.toFixed(
        5
      )} %, target: ${percentAboveTarget.toFixed(2)} %`
    );
    return {
      lowerTick,
      upperTick,
      currentTick,
      bpsLower,
      bpsUpper,
      concentration,
      concentrationTarget,
    };
  } catch (error) {
    logNewLine("ERR", `failed to position bounds: ${error}`);
    lowerTick = upperTick = currentTick = bpsLower = bpsUpper = undefined;
    concentration = concentrationTarget = undefined;
  }
}

const getPriceDelta = async function (
  tokenizedLpContract,
  token0Addr,
  token0Decimals,
  token1Addr,
  token1Decimals
) {
  logNewLine("INF", "getting price delta...");
  let priceDelta, hysteresis, spotPrice, oraclePrice;
  try {
    spotPrice = await tokenizedLpContract.fetchSpot(
      token0Addr,
      token1Addr,
      ethers.parseUnits("1", token0Decimals)
    );
    oraclePrice = await tokenizedLpContract.fetchOracle(
      token0Addr,
      token1Addr,
      ethers.parseUnits("1", token0Decimals)
    );
    hysteresis = await tokenizedLpContract.hysteresis();
    const delta =
      spotPrice > oraclePrice
        ? spotPrice - oraclePrice
        : oraclePrice - spotPrice;
    priceDelta = (delta * ethers.parseUnits("1", token1Decimals)) / oraclePrice;
    logData(
      `spotPrice:   1 Token0 for ${ethers.formatUnits(spotPrice, token1Decimals)} Token1`
    );
    logData(
      `oraclePrice: 1 Token0 for ${ethers.formatUnits(oraclePrice, token1Decimals)} Token1`
    );
    logData(
      `priceDelta: ${ethers.formatEther(
        priceDelta * 100n
      )} %, hysteresis: ${ethers.formatEther(hysteresis * 100n)} %`
    );
    logData(`swap required: ${priceDelta > hysteresis}`);
    return { priceDelta, hysteresis, spotPrice, oraclePrice };
  } catch (e) {
    logNewLine("ERR", `failed getting priceDelta and hysteresis: ${e}`);
    priceDelta = hysteresis = spotPrice = oraclePrice = undefined;
    return { priceDelta, hysteresis };
  }
};

async function logPositionInfo(
  lpTokenAddr,
  tokenizedLpContract,
  token0Addr,
  token0Decimals,
  token0Contract,
  token1Addr,
  token1Decimals,
  token1Contract
) {
  let success = true;
  const { aumToken0, aumToken1 } = await getAUMBalances(
    tokenizedLpContract,
    token0Addr,
    token0Decimals,
    token1Addr,
    token1Decimals
  );
  if (aumToken0 == undefined || aumToken1 == undefined) {
    success = false;
  }
  const { idlingToken0, idlingToken1 } = await getIdleBalances(
    token0Contract,
    token0Decimals,
    token1Contract,
    token1Decimals,
    lpTokenAddr
  );
  if (idlingToken0 == undefined || idlingToken1 == undefined) success = false;
  const { lowerTick, upperTick, currentTick } = await getCurrentBounds(
    tokenizedLpContract,
    token0Decimals,
    token1Decimals
  );
  if (
    lowerTick == undefined ||
    upperTick == undefined ||
    currentTick == undefined
  )
    success = false;
  const { priceDelta, hysteresis, spotPrice, oraclePrice } =
    await getPriceDelta(tokenizedLpContract, token0Addr, token0Decimals, token1Addr, token1Decimals);
  if (
    priceDelta == undefined ||
    hysteresis == undefined ||
    spotPrice == undefined ||
    oraclePrice == undefined
  )
    success = false;
  return success;
}

async function getToken1AmtInToken0(
  idlingToken1,
  token1Addr,
  token0Addr,
  tokenizedLpContract
) {
  logNewLine(
    "INF",
    `estimating token1 amount ${ethers.formatEther(idlingToken1)} in token0`
  );
  let idlingToken1InToken0;
  try {
    idlingToken1InToken0 = await tokenizedLpContract.fetchOracle(
      token1Addr,
      token0Addr,
      idlingToken1
    );
    logData(`\tanswer: ${ethers.formatEther(idlingToken1InToken0)} Token0`);
    return idlingToken1InToken0;
  } catch (error) {
    logNewLine("ERR", `failed to fetch: ${error}`);
    return undefined;
  }
}

async function executeSwapIdle(
  tokenizedLpContract,
  swapAmount,
  direction,
  readOnly
) {
  logNewLine(
    "INF",
    `executing half idle for swap amount: ${ethers.formatEther(swapAmount)}, ${direction > 0 ? "token0 -> token1" : "token1 -> token0"
    }`
  );
  console.log("direction", direction);
  let amount0, amount1;
  try {
    [amount0, amount1] =
      await tokenizedLpContract.swapIdleAndAddToLiquidity.staticCall(
        swapAmount * BigInt(direction),
        0,
        true
      );
    if (!readOnly) {
      const tx = await tokenizedLpContract.swapIdleAndAddToLiquidity(
        swapAmount * BigInt(direction),
        0,
        true
      );
      logNewLine("INF", `txHash: ${tx.hash}`);
      logNewLine("INF", `successfully executed swapIdleAndAddToLiquidity!`);
    } else {
      logNewLine(
        "INF",
        `******************read-only mode**********************`
      );
      logNewLine(
        "INF",
        `***************** SIMULATION swap ********************`
      );
      logNewLine(
        "INF",
        `******************************************************`
      );
    }
    if (direction > 0) {
      const formatAmount0 = Number(ethers.formatEther(amount0)).toFixed(8);
      const formatAmount1 = Number(ethers.formatEther(amount1 * -1n)).toFixed(
        8
      );
      logNewLine(
        "INF",
        `traded amount0: ${formatAmount0} for ${formatAmount1}`
      );
    } else {
      const formatAmount0 = Number(ethers.formatEther(amount0 * -1n)).toFixed(
        8
      );
      const formatAmount1 = Number(ethers.formatEther(amount1)).toFixed(8);
      logNewLine(
        "INF",
        `traded amount1: ${formatAmount1} for ${formatAmount0}`
      );
    }
    return { amount0, amount1 };
  } catch (error) {
    logNewLine("ERR", `failed to swap: ${error}`);
    amount0 = amount1 = undefined;
    return { amount0, amount1 };
  }
}

async function executeAutoRebalance(
  tokenizedLpContract,
  aroundExternalOracle,
  swapRequired
) {
  logNewLine(
    "INF",
    `executing autorebalancing with params: aroundExtOracle ${aroundExternalOracle}, swapRequired ${swapRequired}`
  );
  let amount0, amount1;
  try {
    [amount0, amount1] = await tokenizedLpContract.autoRebalance.staticCall(
      aroundExternalOracle,
      swapRequired
    );
    const tx = await tokenizedLpContract.autoRebalance(
      aroundExternalOracle,
      swapRequired
    );
    logNewLine("INF", `txHash: ${tx.hash}`);
    logNewLine("INF", `successfully executed autoRebalance!`);
    return { amount0, amount1 };
  } catch (e) {
    amount0 = amount1 = undefined;
    logNewLine("ERR", `failed executing autoRebalance: ${e}`);
    return { amount0, amount1 };
  }
}

async function adjustBounds(tokenizedLpContract, newLowerTick, newUpperTick) {
  logNewLine("INF", `adjusting bounds to: ${newLowerTick}, ${newUpperTick}`);
  try {
    const tx = await tokenizedLpContract.rebalance(
      newLowerTick,
      newUpperTick,
      0,
      0
    );
    logNewLine("INF", `txHash: ${tx.hash}`);
    logNewLine("INF", `successfully adjusted bounds!`);
    return true;
  } catch (e) {
    logNewLine("ERR", `failed to adjust bounds: ${e}`);
    return false;
  }
}

module.exports = {
  adjustBounds,
  getAUMBalances,
  getCurrentBounds,
  getIdleBalances,
  getToken1AmtInToken0,
  executeSwapIdle,
  executeAutoRebalance,
  logPositionInfo,
  tokenSorter,
};
