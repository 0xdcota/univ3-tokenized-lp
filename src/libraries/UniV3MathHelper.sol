// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {TickMath} from "@uniswap-v3-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap-v3-periphery/libraries/LiquidityAmounts.sol";
import {OracleLibrary} from "@uniswap-v3-periphery/libraries/OracleLibrary.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";

library UniV3MathHelper {
    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 public constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 public constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    error UnsafeCast();

    /**
     *
     * Tick Math
     *
     */
    function getSqrtRatioAtTick(int24 currentTick) public pure returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(currentTick);
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) public pure returns (int24 currentTick) {
        currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /**
     *
     * LiquidityAmounts
     *
     */
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) =
            LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) public pure returns (uint128 liquidity) {
        liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1);
    }

    /**
     *
     * OracleLibrary
     *
     */
    function consult(address _pool, uint32 _twapPeriod) public view returns (int24 timeWeightedAverageTick) {
        (timeWeightedAverageTick,) = OracleLibrary.consult(_pool, _twapPeriod);
    }

    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)
        public
        pure
        returns (uint256 quoteAmount)
    {
        quoteAmount = OracleLibrary.getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
    }

    /**
     *
     * General
     *
     */

    /**
     * @dev Encodes two reserve amounts into approx ~sqrtPriceX96.
     * Precision cannot be matched with the actual sqrtPriceX96 obtained in JS with BigNumbers.
     * Higher precision could also lead to overflow.
     */
    function encodePriceSqrtX96(uint256 reserve0, uint256 reserve1) public pure returns (uint160) {
        uint160 precisionHelper = 1;
        if (reserve1 < reserve0) {
            precisionHelper = 1 ether;
            reserve1 = reserve1 * precisionHelper ** 2;
        }
        return uint160Safe((Math.sqrt(reserve1 / reserve0)) * 2 ** 96) / precisionHelper;
    }

    /**
     * @dev Rounds a tick to the nearest multiple of the tickSpacing by always
     * reducing range (i.e. moving towards zero).
     */
    function roundTick(int24 tick, int24 tickSpacing) public pure returns (int24) {
        return tick < 0 ? tick + (-tick % tickSpacing) : tick - (tick % tickSpacing);
    }

    /**
     * @notice Unit256 to uint128 safe function
     *  @param x input value
     */
    function uint128Safe(uint256 x) public pure returns (uint128) {
        if (x > type(uint128).max) revert UnsafeCast();
        return uint128(x);
    }

    /**
     * @notice Unit256 to uint160 safe function
     *  @param x input value
     */
    function uint160Safe(uint256 x) public pure returns (uint160) {
        if (x > type(uint160).max) revert UnsafeCast();
        return uint160(x);
    }
}
