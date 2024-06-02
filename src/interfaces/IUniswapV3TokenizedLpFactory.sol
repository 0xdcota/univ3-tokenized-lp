// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IUniswapV3TokenizedLpFactory {
    event FeeRecipient(address indexed sender, address feeRecipient);

    event BaseFee(address indexed sender, uint256 baseFee);

    event BaseFeeSplit(address indexed sender, uint256 baseFeeSplit);

    event DeployUniswapV3TokenizedLpFactory(address indexed sender, address uniswapV3Factory);

    event UniswapV3TokenizedLpCreated(
        address indexed sender,
        address tokenizedLp,
        address tokenA,
        bool allowTokenA,
        address tokenB,
        bool allowTokenB,
        uint24 fee,
        uint256 count
    );

    error IUniswapV3TokenizedLpFactory_ZeroAddress();
    error IUniswapV3TokenizedLpFactory_IdenticalTokens();
    error IUniswapV3TokenizedLpFactory_NoAllowedTokens();
    error IUniswapV3TokenizedLpFactory_VaultExists();
    error IUniswapV3TokenizedLpFactory_InvalidFee();
    error IUniswapV3TokenizedLpFactory_PoolMustExist();
    error IUniswapV3TokenizedLpFactory_ObservationCardinalityTooLow();
    error IUniswapV3TokenizedLpFactory_MustBeLteToPrecision();

    function uniswapV3Factory() external view returns (address);

    function feeRecipient() external view returns (address);

    function baseFee() external view returns (uint256);

    function baseFeeSplit() external view returns (uint256);

    function setFeeRecipient(address _feeRecipient) external;

    function setBaseFee(uint256 _baseFee) external;

    function setBaseFeeSplit(uint256 _baseFeeSplit) external;

    function createUniswapV3TokenizedLp(address tokenA, bool allowTokenA, address tokenB, bool allowTokenB, uint24 fee)
        external
        returns (address tokenizedLp);

    function genKey(address deployer, address token0, address token1, uint24 fee, bool allowToken0, bool allowToken1)
        external
        pure
        returns (bytes32 key);
}
