// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IUniswapV3TokenizedLp {
    /// Events
    event Deposit(address indexed sender, address indexed to, uint256 shares, uint256 amount0, uint256 amount1);

    event Withdraw(address indexed sender, address indexed to, uint256 shares, uint256 amount0, uint256 amount1);

    event Rebalance(
        int24 tick,
        uint256 totalAmount0,
        uint256 totalAmount1,
        uint256 feeAmount0,
        uint256 feeAmount1,
        uint256 totalSupply
    );

    event MaxTotalSupply(uint256 newMaxTotalSupply);

    event Hysteresis(uint256 newHysteresis);

    event DepositMax(uint256 newDeposit0Max, uint256 newDeposit1Max);

    event Affiliate(address affiliate);

    event ApprovedRebalancer(address rebalancer, bool isApproved);

    event FeeUpdate(uint256 newFee);

    event FeeRecipient(address newFeeRecipient);

    event FeeSplit(uint256 newFeeSplit);

    event UsdOracleReferences(address usd0RefOracle, address usd1RefOracle);

    event BpsRanges(uint256 newBpsRangeLower, uint256 newBpsRangeUpper);

    event ActionBlockDelay(uint256 newBlockWaitTime);

    /// Errors

    error UniswapV3TokenizedLp_alreadyInitialized();
    error UniswapV3TokenizedLp_ZeroAddress();
    error UniswapV3TokenizedLp_NoAllowedTokens();
    error UniswapV3TokenizedLp_ZeroValue();
    error UniswapV3TokenizedLp_Token0NotAllowed();
    error UniswapV3TokenizedLp_Token1NotAllowed();
    error UniswapV3TokenizedLp_MoreThanMaxDeposit();
    error UniswapV3TokenizedLp_MaxTotalSupplyExceeded();
    error UniswapV3TokenizedLp_UnexpectedBurn();
    error UniswapV3TokenizedLp_BasePositionInvalid();
    error UniswapV3TokenizedLp_LimitPositionInvalid();
    error UniswapV3TokenizedLp_FeeMustBeLtePrecision();
    error UniswapV3TokenizedLp_SplitMustBeLtePrecision();
    error UniswapV3TokenizedLp_MustBePool(uint256 instance);
    error UniswapV3TokenizedLp_UnsafeCast();
    error UniswapV3TokenizedLp_PoolLocked();
    error UniswapV3TokenizedLp_failedToQueryPool();
    error UniswapV3TokenizedLp_invalidSlot0Size();
    error UniswapV3TokenizedLp_InvalidBaseBpsRange();
    error UniswapV3TokenizedLp_PositionOutOfRange();
    error UniswapV3TokenizedLp_SetBaseTicksViaRebalanceFirst();
    error UniswapV3TokenizedLp_NotAllowed();
    error UniswapV3TokenizedLp_NoWithdrawOrTransferDuringDelay();

    /// View methods
    function pool() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function allowToken0() external view returns (bool);

    function allowToken1() external view returns (bool);

    function tickSpacing() external view returns (int24);

    function affiliate() external view returns (address);

    function baseLower() external view returns (int24);

    function baseUpper() external view returns (int24);

    function deposit0Max() external view returns (uint256);

    function deposit1Max() external view returns (uint256);

    function maxTotalSupply() external view returns (uint256);

    function hysteresis() external view returns (uint256);

    function currentTick() external view returns (int24 tick);

    function getCurrentSqrtPriceX96() external view returns (uint160 sqrtPriceX96);

    function getTimeWeightedSqrtPriceX96() external view returns (uint160 sqrtPriceX96);

    function fetchSpot(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut);

    function fetchOracle(address tokenIn_, address tokenOut_, uint256 amountIn_)
        external
        view
        returns (uint256 amountOut);

    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);

    function getBasePosition() external view returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /// Setters

    function setUsdOracles(address usdOracle0Ref_, address usdOracle1Ref_) external;

    function setMaxTotalSupply(uint256 maxTotalSupply) external;

    function setDepositMax(uint256 deposit0Max, uint256 deposit1Max) external;

    function setBpsRanges(uint256 baseBpsRangeLower, uint256 baseBpsRangeUpper) external;

    function setFeeRecipient(address feeRecipient) external;

    function setAffiliate(address affiliate) external;

    function setFee(uint256 baseFee) external;

    function setFeeSplit(uint256 baseFeeSplit) external;

    function setHysteresis(uint256 hysteresis) external;

    /// Core methods

    function deposit(uint256 deposit0, uint256 deposit1, address receiver) external returns (uint256);

    function withdraw(uint256 shares, address receiver) external returns (uint256, uint256);

    function autoRebalance(bool useOracleForNewBounds, bool withSwapping)
        external
        returns (int256 amount0, int256 amount1);

    function rebalance(int24 _baseLower, int24 _baseUpper, int256 swapQuantity, int24 tickLimit) external;

    function swapIdleAndAddToLiquidity(int256 swapInputAmount, uint160 limit, bool addToLiquidity)
        external
        returns (int256 amount0, int256 amount1);
}
