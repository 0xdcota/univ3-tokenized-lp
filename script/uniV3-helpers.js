const bn = require("bignumber.js");

/**
 * @notice Returns sqrtPriceX96 from a set of reserves.
 * Price defined by reserve1 / reserve0
 * @param reserve0
 * @param reserve1
 * @returns
 * @dev Refer to: https://blog.uniswap.org/uniswap-v3-math-primer
 */
bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });
function encodePriceSqrt(reserve0, reserve1) {
  return BigNumber.from(
    new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  );
}

/**
 * @notice Returns a price from sqrtPriceX96.
 * This method does not consider decimal interpretation of price.
 * @param priceSqrtX96
 * @returns
 */
function decodePriceSqrtX96(priceSqrtX96) {
  const bnPriceSqrtX96 = new bn(priceSqrtX96.toString());
  const dividedByX96 = bnPriceSqrtX96.div(new bn(2).pow(96));
  const raisedToPower = dividedByX96.pow(new bn(2));
  return raisedToPower;
}

/**
 * @notice Returns a price in decimal readable format from sqrtPriceX96.
 * This method considers decimal interpretation of reserve0 and reserve1.
 * @param priceSqrtX96
 * @param zeroToOnePrice
 * @param decimals0
 * @param decimals1
 * @returns
 */
function decodePriceSqrtX96ToDec(
  priceSqrtX96,
  zeroToOnePrice,
  decimals0,
  decimals1
) {
  const rawPrice = decodePriceSqrtX96(priceSqrtX96);
  const decimalPrice = rawPrice.multipliedBy(
    new bn(10).pow(decimals0 - decimals1)
  );
  if (zeroToOnePrice) {
    return Number(decimalPrice.pow(-1).toString());
  } else {
    return Number(decimalPrice.toString());
  }
}

/**
 * @notice Returns tick from sqrtPriceX96
 * @param sqrtPriceX96
 * @returns
 */
function sqrtPriceX96ToTick(sqrtPriceX96) {
  const Q96 = 2 ** 96;
  const tick = Math.floor(
    Math.log((sqrtPriceX96 / Q96) ** 2) / Math.log(1.0001)
  );
  return tick;
}

/**
 * @notice Returns tick from sqrtPriceX96
 * @param price of token1/token0
 * @returns
 */
function tickToSqrt96(tick) {
  return (1.0001 ** tick) ** (0.5) * 2 ** 96;
}

/**
 * @notice Returns tick from sqrtPriceX96
 * @param price of token1/token0
 * @returns
 */
function tickToPrice(tick) {
  return 1.0001 ** tick;
}

module.exports = {
  encodePriceSqrt,
  decodePriceSqrtX96,
  decodePriceSqrtX96ToDec,
  sqrtPriceX96ToTick,
  tickToSqrt96,
  tickToPrice
}