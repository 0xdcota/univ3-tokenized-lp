const bn = require("bignumber.js");

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

function encodePriceSqrtX96(reserve0, reserve1) {
  return new bn(reserve1.toString())
    .div(reserve0.toString())
    .sqrt()
    .multipliedBy(new bn(2).pow(96))
    .integerValue(3);
}

const arg1 = process.argv[2];
const arg2 = process.argv[3];
if (arg1 && arg2) {
  console.log(encodePriceSqrtX96(arg1, arg2).toString());
}

module.exports = encodePriceSqrtX96;
