const bn = require("bignumber.js");

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

function decodePriceSqrtX96(priceSqrtX96) {
  priceSqrtX96 = new bn(priceSqrtX96);
  const dividedByX96 = priceSqrtX96.div(new bn(2).pow(96));
  const raisedToPower = dividedByX96.pow(new bn(2));
  return raisedToPower;
}

const arg1_priceSqrtX96 = process.argv[2];
const arg2_decimals0 = process.argv[3];
const arg3_decimals1 = process.argv[4];
if (arg1_priceSqrtX96 && arg2_decimals0 && arg3_decimals1) {
  const rawPrice = decodePriceSqrtX96(arg1_priceSqrtX96);
  const decimalPrice = rawPrice.multipliedBy(
    new bn(10).pow(arg2_decimals0 - arg3_decimals1)
  );
  console.log(
    Number(decimalPrice.toString()).toFixed(18),
    "token1/token0\n",
    Number(decimalPrice.pow(-1).toString()).toFixed(18),
    "token0/token1"
  );
}

module.exports = decodePriceSqrtX96;
