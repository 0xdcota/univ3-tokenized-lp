// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IUniswapV3TokenizedLp {
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

    error IUniswapV3TokenizedLp_ZeroAddress();
    error IUniswapV3TokenizedLp_NoAllowedTokens();
    error IUniswapV3TokenizedLp_ZeroValue();
    error IUniswapV3TokenizedLp_Token0NotAllowed();
    error IUniswapV3TokenizedLp_Token1NotAllowed();
    error IUniswapV3TokenizedLp_MoreThanMaxDeposit();
    error IUniswapV3TokenizedLp_UnexpectedBurn(uint256 line);
    error IUniswapV3TokenizedLp_MaxTotalSupplyExceeded();
    error IUniswapV3TokenizedLp_BasePositionInvalid();
    error IUniswapV3TokenizedLp_LimitPositionInvalid();
    error IUniswapV3TokenizedLp_FeeMustBeLtePrecision();
    error IUniswapV3TokenizedLp_SplitMustBeLtePrecision();
    error IUniswapV3TokenizedLp_MustBePool(uint256 line);
    error IUniswapV3TokenizedLp_UnsafeCast();
    error IUniswapV3TokenizedLp_PoolLocked();

    function pool() external view returns (address);

    function token0() external view returns (address);

    function allowToken0() external view returns (bool);

    function token1() external view returns (address);

    function allowToken1() external view returns (bool);

    function fee() external view returns (uint24);

    function tickSpacing() external view returns (int24);

    function affiliate() external view returns (address);

    function baseLower() external view returns (int24);

    function baseUpper() external view returns (int24);

    function deposit0Max() external view returns (uint256);

    function deposit1Max() external view returns (uint256);

    function maxTotalSupply() external view returns (uint256);

    function hysteresis() external view returns (uint256);

    function getTotalAmounts() external view returns (uint256, uint256);

    function deposit(uint256, uint256, address) external returns (uint256);

    function withdraw(uint256, address) external returns (uint256, uint256);

    function setDepositMax(uint256 _deposit0Max, uint256 _deposit1Max) external;

    function setAffiliate(address _affiliate) external;
}
