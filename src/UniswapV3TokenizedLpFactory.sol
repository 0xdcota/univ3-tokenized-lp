// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IUniswapV3TokenizedLpFactory} from "./interfaces/IUniswapV3TokenizedLpFactory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap-v3-core/interfaces/IUniswapV3Factory.sol";
import {UniV3LpDeployer} from "./libraries/UniV3LpDeployer.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract UniswapV3TokenizedLpFactory is
    IUniswapV3TokenizedLpFactory,
    ReentrancyGuard,
    Ownable
{
    address constant NULL_ADDRESS = address(0);
    uint256 constant DEFAULT_BASE_FEE = 10 ** 17; // 10%
    uint256 constant DEFAULT_BASE_FEE_SPLIT = 5 * 10 ** 17; // 50%
    uint256 constant PRECISION = 10 ** 18;
    uint32 constant DEFAULT_TWAP_PERIOD = 60 minutes;
    uint16 constant MIN_OBSERVATIONS = 50;
    address public immutable override uniswapV3Factory;
    address public override feeRecipient;
    uint256 public override baseFee;
    uint256 public override baseFeeSplit;

    mapping(bytes32 => address) public getUniswapV3TokenizedLp;
    address[] public allVaults;

    /**
     @notice creates an instance of UniswapV3TokenizedLpFactory
     @param _uniswapV3Factory Uniswap V3 factory
     */
    constructor(address _uniswapV3Factory) Ownable(msg.sender) {
        if (_uniswapV3Factory == NULL_ADDRESS)
            revert IUniswapV3TokenizedLpFactory_ZeroAddress();

        uniswapV3Factory = _uniswapV3Factory;
        feeRecipient = msg.sender;
        baseFee = DEFAULT_BASE_FEE;
        baseFeeSplit = DEFAULT_BASE_FEE_SPLIT;
        emit DeployUniswapV3TokenizedLpFactory(msg.sender, _uniswapV3Factory);
    }

    /**
     @notice creates an instance of UniswapV3TokenizedLp for specified tokenA/tokenB/fee setting. If needed creates underlying Uniswap V3 pool. AllowToken parameters control whether the UniswapV3TokenizedLp allows one-sided or two-sided liquidity provision
     @param tokenA tokenA of the Uniswap V3 pool
     @param allowTokenA flag that indicates whether tokenA is accepted during deposit
     @param tokenB tokenB of the Uniswap V3 pool
     @param allowTokenB flag that indicates whether tokenB is accepted during deposit
     @param fee fee setting of the Uniswap V3 pool
     @param uniswapV3TokenizedLp address of the created UniswapV3TokenizedLp
     */
    function createUniswapV3TokenizedLp(
        address tokenA,
        bool allowTokenA,
        address tokenB,
        bool allowTokenB,
        uint24 fee
    ) external override nonReentrant returns (address uniswapV3TokenizedLp) {
        if (tokenA == tokenB)
            revert IUniswapV3TokenizedLpFactory_IdenticalTokens();

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        (bool allowToken0, bool allowToken1) = tokenA < tokenB
            ? (allowTokenA, allowTokenB)
            : (allowTokenB, allowTokenA);

        if (token0 == NULL_ADDRESS)
            revert IUniswapV3TokenizedLpFactory_ZeroAddress();

        if (!allowTokenA && !allowTokenB)
            revert IUniswapV3TokenizedLpFactory_NoAllowedTokens();

        // deployer, token0, token1, fee, allowToken1, allowToken2 -> UniswapV3TokenizedLp address
        if (
            getUniswapV3TokenizedLp[
                genKey(
                    msg.sender,
                    token0,
                    token1,
                    fee,
                    allowToken0,
                    allowToken1
                )
            ] != NULL_ADDRESS
        ) revert IUniswapV3TokenizedLpFactory_VaultExists();

        int24 tickSpacing = IUniswapV3Factory(uniswapV3Factory)
            .feeAmountTickSpacing(fee);

        if (tickSpacing == 0) revert IUniswapV3TokenizedLpFactory_InvalidFee();

        address pool = IUniswapV3Factory(uniswapV3Factory).getPool(
            tokenA,
            tokenB,
            fee
        );

        if (pool == NULL_ADDRESS) {
            revert IUniswapV3TokenizedLpFactory_PoolMustExist();
        }

        (
            ,
            ,
            ,
            ,
            /*uint160 sqrtPriceX96*/ /*int24 tick*/ /*uint16 observationIndex*/ /*uint16 observationCardinality*/ uint16 observationCardinalityNext /*uint8 feeProtocol*/ /*bool unlocked*/,
            ,

        ) = IUniswapV3Pool(pool).slot0();

        if (observationCardinalityNext < MIN_OBSERVATIONS)
            revert IUniswapV3TokenizedLpFactory_ObservationCardinalityTooLow();

        uniswapV3TokenizedLp = UniV3LpDeployer.createUniswapV3TokenizedLp(
            pool,
            token0,
            allowToken0,
            token1,
            allowToken1,
            fee,
            tickSpacing,
            DEFAULT_TWAP_PERIOD
        );

        Ownable(uniswapV3TokenizedLp).transferOwnership(owner());

        getUniswapV3TokenizedLp[
            genKey(msg.sender, token0, token1, fee, allowToken0, allowToken1)
        ] = uniswapV3TokenizedLp;
        getUniswapV3TokenizedLp[
            genKey(msg.sender, token1, token0, fee, allowToken1, allowToken0)
        ] = uniswapV3TokenizedLp; // populate mapping in the reverse direction
        allVaults.push(uniswapV3TokenizedLp);

        emit UniswapV3TokenizedLpCreated(
            msg.sender,
            uniswapV3TokenizedLp,
            token0,
            allowToken0,
            token1,
            allowToken1,
            fee,
            allVaults.length
        );
    }

    /**
     @notice Sets the fee recipient account address, where portion of the collected swap fees will be distributed
     @dev onlyOwner
     @param _feeRecipient The fee recipient account address
     */
    function setFeeRecipient(
        address _feeRecipient
    ) external override onlyOwner {
        if (_feeRecipient == address(0))
            revert IUniswapV3TokenizedLpFactory_ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipient(msg.sender, _feeRecipient);
    }

    /**
     @notice Sets the fee percentage to be taken from the accumulated pool's swap fees. This percentage is then distributed between the feeRecipient and affiliate accounts
     @dev onlyOwner
     @param _baseFee The fee percentage to be taken from the accumulated pool's swap fee
     */
    function setBaseFee(uint256 _baseFee) external override onlyOwner {
        if (_baseFee > PRECISION)
            revert IUniswapV3TokenizedLpFactory_MustBeLteToPrecision();
        baseFee = _baseFee;
        emit BaseFee(msg.sender, _baseFee);
    }

    /**
     @notice Sets the fee split ratio between feeRecipient and affiliate accounts. The ratio is set as (baseFeeSplit)/(100 - baseFeeSplit), that is if we want 20/80 ratio (with feeRecipient getting 20%), baseFeeSplit should be set to 20
     @dev onlyOwner
     @param _baseFeeSplit The fee split ratio between feeRecipient and affiliate accounts
     */
    function setBaseFeeSplit(
        uint256 _baseFeeSplit
    ) external override onlyOwner {
        if (_baseFeeSplit > PRECISION)
            revert IUniswapV3TokenizedLpFactory_MustBeLteToPrecision();
        baseFeeSplit = _baseFeeSplit;
        emit BaseFeeSplit(msg.sender, _baseFeeSplit);
    }

    /**
     * @notice generate a key for getUniswapV3TokenizedLp
     * @param deployer vault creator
     * @param token0 the first of two tokens in the vault
     * @param token1 the second of two tokens in the vault
     * @param fee the uniswap v3 fee
     * @param allowToken0 allow deposits
     * @param allowToken1 allow deposits
     */
    function genKey(
        address deployer,
        address token0,
        address token1,
        uint24 fee,
        bool allowToken0,
        bool allowToken1
    ) public pure override returns (bytes32 key) {
        key = keccak256(
            abi.encodePacked(
                deployer,
                token0,
                token1,
                fee,
                allowToken0,
                allowToken1
            )
        );
    }
}
