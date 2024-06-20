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

    event MaxTotalSupply(address indexed sender, uint256 maxTotalSupply);

    event Hysteresis(address indexed sender, uint256 hysteresis);

    event DepositMax(address indexed sender, uint256 deposit0Max, uint256 deposit1Max);

    event Affiliate(address indexed sender, address affiliate);

    event DeployUniV3TokenizedLp(
        address indexed sender,
        address indexed pool,
        bool allowToken0,
        bool allowToken1,
        address owner,
        address usdOracle0Ref,
        address usdOracle1Ref
    );

    event FeeRecipient(address indexed sender, address feeRecipient);

    event BaseFee(address indexed sender, uint256 baseFee);

    event BaseFeeSplit(address indexed sender, uint256 baseFeeSplit);

    event UsdOracleReferences(address indexed sender, address usd0RefOracle, address usd1RefOracle);

    event BaseBpsRanges(address indexed sender, uint256 baseBpsRangeLower, uint256 baseBpsRangeUpper);

    /// Errors

    error IUniswapV3TokenizedLp_alreadyInitialized();
    error IUniswapV3TokenizedLp_ZeroAddress();
    error IUniswapV3TokenizedLp_NoAllowedTokens();
    error IUniswapV3TokenizedLp_ZeroValue();
    error IUniswapV3TokenizedLp_Token0NotAllowed();
    error IUniswapV3TokenizedLp_Token1NotAllowed();
    error IUniswapV3TokenizedLp_MoreThanMaxDeposit();
    error IUniswapV3TokenizedLp_MaxTotalSupplyExceeded();
    error IUniswapV3TokenizedLp_UnexpectedBurn();
    error IUniswapV3TokenizedLp_BasePositionInvalid();
    error IUniswapV3TokenizedLp_LimitPositionInvalid();
    error IUniswapV3TokenizedLp_FeeMustBeLtePrecision();
    error IUniswapV3TokenizedLp_SplitMustBeLtePrecision();
    error IUniswapV3TokenizedLp_MustBePool(uint256 line);
    error IUniswapV3TokenizedLp_UnsafeCast();
    error IUniswapV3TokenizedLp_PoolLocked();
    error IUniswapV3TokenizedLp_InvalidBaseBpsRange();
    error IUniswapV3TokenizedLp_SetBaseTicksViaRebalanceFirst();

    /// View methods

    function pool() external view returns (address);

    function token0() external view returns (address);

    function allowToken0() external view returns (bool);

    function token1() external view returns (address);

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

    function currentSqrtPriceX96() external view returns (uint160 sqrtPriceX96);

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

    function setBaseBpsRanges(uint256 baseBpsRangeLower, uint256 baseBpsRangeUpper) external;

    function setFeeRecipient(address feeRecipient) external;

    function setAffiliate(address affiliate) external;

    function setBaseFee(uint256 baseFee) external;

    function setBaseFeeSplit(uint256 baseFeeSplit) external;

    function setHysteresis(uint256 hysteresis) external;

    /// Core methods

    function deposit(uint256 deposit0, uint256 deposit1, address receiver) external returns (uint256);

    function withdraw(uint256 shares, address receiver) external returns (uint256, uint256);

    function autoRebalance() external;

    function rebalance(int24 baseLower, int24 baseUpper, int256 swapQuantity) external;
}
