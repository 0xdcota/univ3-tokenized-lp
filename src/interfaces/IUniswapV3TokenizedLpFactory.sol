// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IUniswapV3TokenizedLpFactory {
    event FeeRecipient(address indexed sender, address feeRecipient);

    event BaseFee(address indexed sender, uint256 baseFee);

    event BaseFeeSplit(address indexed sender, uint256 baseFeeSplit);

    event DeployUniswapV3TokenizedLpFactory(
        address indexed sender,
        address uniswapV3Factory
    );

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

    function uniswapV3Factory() external view returns (address);

    function feeRecipient() external view returns (address);

    function baseFee() external view returns (uint256);

    function baseFeeSplit() external view returns (uint256);

    function setFeeRecipient(address _feeRecipient) external;

    function setBaseFee(uint256 _baseFee) external;

    function setBaseFeeSplit(uint256 _baseFeeSplit) external;

    function createICHIVault(
        address tokenA,
        bool allowTokenA,
        address tokenB,
        bool allowTokenB,
        uint24 fee
    ) external returns (address ichiVault);

    function genKey(
        address deployer,
        address token0,
        address token1,
        uint24 fee,
        bool allowToken0,
        bool allowToken1
    ) external pure returns (bytes32 key);
}
