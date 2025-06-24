// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// ──────▄▀▀▄────────────────▄▀▀▄────
// ─────▐▒▒▒▒▌──────────────▌▒▒▒▒▌───
// ─────▌▒▒▒▒▐─────────────▐▒▒▒▒▒▐───
// ────▐▒▒▒▒▒▒▌─▄▄▄▀▀▀▀▄▄▄─▌▒▒▒▒▒▒▌──
// ───▄▌▒▒▒▒▒▒▒▀▒▒▒▒▒▒▒▒▒▒▀▒▒▒▒▒▒▐───
// ─▄▀▒▐▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▌───
// ▐▒▒▒▌▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▐───
// ▌▒▒▌▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▌──
// ▒▒▐▒▒▒▒▒▒▒▒▒▄▀▀▀▀▄▒▒▒▒▒▄▀▀▀▀▄▒▒▐──
// ▒▒▌▒▒▒▒▒▒▒▒▐▌─▄▄─▐▌▒▒▒▐▌─▄▄─▐▌▒▒▌─
// ▒▐▒▒▒▒▒▒▒▒▒▐▌▐█▄▌▐▌▒▒▒▐▌▐█▄▌▐▌▒▒▐─
// ▒▌▒▒▒▒▒▒▒▒▒▐▌─▀▀─▐▌▒▒▒▐▌─▀▀─▐▌▒▒▒▌
// ▒▌▒▒▒▒▒▒▒▒▒▒▀▄▄▄▄▀▒▒▒▒▒▀▄▄▄▄▀▒▒▒▒▐
// ▒▌▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▒▒▒▒▒▒▒▒▒▒▒▐
// ▒▌▒▒▒▒▒▒▒▒▒▒▒▒▀▒▀▒▒▒▀▒▒▒▀▒▀▒▒▒▒▒▒▐
// ▒▌▒▒▒▒▒▒▒▒▒▒▒▒▒▀▒▒▒▄▀▄▒▒▒▀▒▒▒▒▒▒▒▐
// ▒▐▒▒▒▒▒▒▒▒▒▒▀▄▒▒▒▄▀▒▒▒▀▄▒▒▒▄▀▒▒▒▒▐
// ▒▓▌▒▒▒▒▒▒▒▒▒▒▒▀▀▀▒▒▒▒▒▒▒▀▀▀▒▒▒▒▒▒▐
// ▒▓▓▌▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▌
// ▒▒▓▐▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▌─
// ▒▒▓▓▀▀▄▄▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▐──
// ▒▒▒▓▓▓▓▓▀▀▄▄▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▄▄▀▀▒▌─
// ▒▒▒▒▒▓▓▓▓▓▓▓▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▒▒▒▒▒▐─
// ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▌

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniV3MathHelper} from "../libraries/UniV3MathHelper.sol";
import {IERC20Metadata} from "@openzeppelin/interfaces/IERC20Metadata.sol";

/**
 * @notice Returns the price of an asset in USD terms derived from a UniswapV3-like-pool.
 * @dev This contract is a feed adapter intended for HIGHLY LIQUID assets that is in a UniswapV3-like-pool
 *  paired with a "bluechip" asset that has an externally validated USD price feed.
 * For example: obtain a price for genericLST in USD terms from its genericLST/ETH pool and a reliable
 * ETH/USD chainlink-interfacing price feed source.
 */
contract TwapUsdAdapter is IPriceFeed {
    struct PriceFeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    /// Custom errors
    error InvalidTwapDuration();
    error ZeroAddress();
    error InvalidPairAddresses();
    error InvalidUniV3LikePoolAddress();
    error InvalidReponseCLOracle();
    error CannotComputeHistoricalPrice();
    error InvalidSlot0Size();
    error FailedToQueryPool();
    error TwapDurationTooLarge(uint32 duration, uint32 cardinalityRequired);

    uint256 private constant ICLPOOL_SLOT0_SIZE = 192;
    uint256 private constant IUNISWAPV3POOL_SLOT0_SIZE = 224;
    uint16 public constant BLOCKTIME_INTERVAL_DENOMINATOR = 1000; // milliseconds in a second

    string internal _description;
    uint8 internal immutable _decimals;
    uint32 internal _twapDuration;
    IERC20Metadata public immutable _pairedBlueAsset;

    IERC20Metadata public immutable targetAsset;
    address public immutable uniV3LikePool;
    IPriceFeed public immutable blueAssetUsdCLFeed;
    uint16 public blockTimeInterval;

    /**
     *
     * @param description_ of this adapter. (i.e. genericLST/usd from TWAP genericLST/ETH pool)
     * @param targetAsset_  address which price is intended to be calculated in USD
     * @param blueAsset_ address of the bluechip asset in the UniswapV3-like-pool
     * @param uniV3LikePool_   address of the UniswapV3-like-pool in where the target asset is paired with the bluechip
     * asset
     * @param blueAssetUsdCLFeed_  address of the external USD price feed of the bluechip asset
     * @param twapDuration_ must be at least greater than 1 minute, recommend to use 15 - 30 minutes
     * @param blockTimeInterval_ the "average" number of milliseconds time interval between blocks
     *
     * @dev NOTE: The `blueAssetUsdCLFeed_` must be externally validated.
     */
    constructor(
        string memory description_,
        address targetAsset_,
        address blueAsset_,
        address uniV3LikePool_,
        IPriceFeed blueAssetUsdCLFeed_,
        uint32 twapDuration_,
        uint16 blockTimeInterval_
    ) {
        if (targetAsset_ == address(0)) revert ZeroAddress();
        if (blueAsset_ == address(0)) revert ZeroAddress();
        if (targetAsset_ == blueAsset_) revert InvalidPairAddresses();
        if (uniV3LikePool_ == address(0)) revert ZeroAddress();
        if (address(blueAssetUsdCLFeed_) == address(0)) revert ZeroAddress();
        if (twapDuration_ < 1 minutes) revert InvalidTwapDuration();

        _description = description_;
        targetAsset = IERC20Metadata(targetAsset_);

        address token0 = IUniswapV3Pool(uniV3LikePool_).token0();
        address token1 = IUniswapV3Pool(uniV3LikePool_).token1();
        if (targetAsset_ != token0 && targetAsset_ != token1) revert InvalidUniV3LikePoolAddress();
        if (blueAsset_ != token0 && blueAsset_ != token1) revert InvalidUniV3LikePoolAddress();
        _pairedBlueAsset = token0 == targetAsset_ ? IERC20Metadata(token1) : IERC20Metadata(token0);
        uniV3LikePool = uniV3LikePool_;
        blueAssetUsdCLFeed = blueAssetUsdCLFeed_;
        _decimals = blueAssetUsdCLFeed_.decimals();

        if (blockTimeInterval_ < BLOCKTIME_INTERVAL_DENOMINATOR) {
            blockTimeInterval = BLOCKTIME_INTERVAL_DENOMINATOR;
        } else {
            blockTimeInterval = blockTimeInterval_;
        }

        // Check and set cardinality of pool: only required to check / set once
        uint16 cardinalityReqd = _calcCardinalityRequired(twapDuration_);
        _twapDuration = twapDuration_;

        (,,, uint16 observationCardinality, uint16 observationCardinalityNext,) = _queryPoolSlot0();
        if (observationCardinality < cardinalityReqd && observationCardinalityNext < cardinalityReqd) {
            IUniswapV3Pool(uniV3LikePool_).increaseObservationCardinalityNext(cardinalityReqd);
        }
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    // Returns the same decimals of the `blueAssetUsdCLFeed`
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestAnswer() external view override returns (int256) {
        PriceFeedResponse memory clResponse = _getLatestRoundBlueToUsd();
        return int256(_calculateTargetUsdPrice(clResponse.answer));
    }

    function latestTimestamp() external view returns (uint256) {
        PriceFeedResponse memory clResponse = _getLatestRoundBlueToUsd();
        return clResponse.updatedAt;
    }

    function latestRound() external view returns (uint256) {
        PriceFeedResponse memory clResponse = _getLatestRoundBlueToUsd();
        return clResponse.roundId;
    }

    function getAnswer(uint256) external pure returns (int256) {
        revert CannotComputeHistoricalPrice();
    }

    function getTimestamp(uint256 roundId) external view returns (uint256) {
        (,,, uint256 updatedAt,) = blueAssetUsdCLFeed.getRoundData(uint80(roundId));
        return updatedAt;
    }

    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert CannotComputeHistoricalPrice();
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        PriceFeedResponse memory clResponse = _getLatestRoundBlueToUsd();
        return (
            clResponse.roundId,
            int256(_calculateTargetUsdPrice(clResponse.answer)),
            clResponse.startedAt,
            clResponse.updatedAt,
            clResponse.answeredInRound
        );
    }

    function _calculateTargetUsdPrice(int256 clResponseUsdAnswer) internal view returns (uint256) {
        uint256 rateTargetToPaired = _getTwapRateTargetToPaired();
        // Safe cast to uint256 since we checked it is positive in `_getLatestRoundBlueToUsd`
        return rateTargetToPaired * uint256(clResponseUsdAnswer) / 10 ** _pairedBlueAsset.decimals();
    }

    /**
     * @dev Internal method to calculate the TWAP exchange rate of 1 unit of target asset in paired units
     */
    function _getTwapRateTargetToPaired() internal view returns (uint256) {
        int24 timeWeightedAverageTick = UniV3MathHelper.consult(uniV3LikePool, _twapDuration);
        uint128 targetUnitAmountIn = uint128(10 ** (targetAsset.decimals()));
        return UniV3MathHelper.getQuoteAtTick(
            timeWeightedAverageTick, targetUnitAmountIn, address(targetAsset), address(_pairedBlueAsset)
        );
    }

    function _getLatestRoundBlueToUsd() internal view returns (PriceFeedResponse memory response) {
        int256 receivedAnswer;
        (response.roundId, receivedAnswer, response.startedAt, response.updatedAt, response.answeredInRound) =
            blueAssetUsdCLFeed.latestRoundData();
        if (receivedAnswer <= 0) revert InvalidReponseCLOracle();
        response.answer = receivedAnswer;
    }

    /**
     * @dev Internal method that queries the pool slot0 state
     * Note: Since a  pool can be either IUniswapV3Pool (uniswap v3 and likes)
     * or ICLPool (velodrome and likes), it handles to query either
     * @return sqrtPriceX96 The current sqrtPriceX96
     * @return tick The current tick
     * @return observationIndex The current observation index
     * @return observationCardinality The current maximum number of observations stored in the pool
     * @return observationCardinalityNext The next maximum number of observations, to be updated when the observation.
     * @return unlocked The pool's unlocked status
     */
    function _queryPoolSlot0()
        internal
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            bool unlocked
        )
    {
        (bool success, bytes memory returnedData) = uniV3LikePool.staticcall(abi.encodeWithSignature("slot0()"));
        if (!success) revert FailedToQueryPool();
        if (returnedData.length == ICLPOOL_SLOT0_SIZE) {
            (sqrtPriceX96, tick, observationIndex, observationCardinality, observationCardinalityNext, unlocked) =
                abi.decode(returnedData, (uint160, int24, uint16, uint16, uint16, bool));
        } else if (returnedData.length == IUNISWAPV3POOL_SLOT0_SIZE) {
            (sqrtPriceX96, tick, observationIndex, observationCardinality, observationCardinalityNext,, unlocked) =
                abi.decode(returnedData, (uint160, int24, uint16, uint16, uint16, uint32, bool));
        } else {
            revert InvalidSlot0Size();
        }
    }

    /**
     * @dev Calculate the cardinality required for the TWAP
     * @param duration The duration of the TWAP in seconds
     */
    function _calcCardinalityRequired(uint32 duration) internal view returns (uint16) {
        uint32 cardinalityRequired =
            (duration * BLOCKTIME_INTERVAL_DENOMINATOR + blockTimeInterval - 1) / blockTimeInterval + 1;
        if (cardinalityRequired > type(uint16).max) {
            revert TwapDurationTooLarge(duration, cardinalityRequired);
        }
        return uint16(cardinalityRequired);
    }
}
