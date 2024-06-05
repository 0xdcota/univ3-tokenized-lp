// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IUniswapV3Pool, IUniswapV3PoolActions} from "@uniswap-v3-core/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap-v3-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap-v3-periphery/libraries/LiquidityAmounts.sol";
import {SwapMath} from "@uniswap-v3-core/libraries/SwapMath.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

contract SimplePoolManager is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event AddedPositionKey(address owner, address pool, int24 tickLower, int24 tickUpper, bytes32 positionKey);
    event RemovedPositionKey(address owner, address pool, int24 tickLower, int24 tickUpper, bytes32 positionKey);
    event SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes data);
    event MintCallback(uint256 amount0, uint256 amount1, bytes data);

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    mapping(address => mapping(address => bytes32[])) private _userPositionKeys;

    address private _cachedPool;
    address private _cachedToken0;
    address private _cachedToken1;
    address private _cachedMsgSender;

    function unprotectedSwap(IUniswapV3Pool pool, int256 swapAmount) public nonReentrant {
        _cachedMsgSender = msg.sender;
        _cachedPool = address(pool);
        _cachedToken0 = pool.token0();
        _cachedToken1 = pool.token1();
        pool.swap(
            msg.sender,
            swapAmount > 0,
            swapAmount > 0 ? swapAmount : -swapAmount,
            swapAmount > 0 ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(msg.sender)
        );
    }

    function mintLiquidity(IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 token0, uint128 token1)
        public
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        _cachedMsgSender = msg.sender;
        _cachedPool = address(pool);
        _cachedToken0 = pool.token0();
        _cachedToken1 = pool.token1();

        uint128 liquidity = _liquidityForAmounts(pool, tickLower, tickUpper, token0, token1);
        if (liquidity > 0) {
            (amount0, amount1) = pool.mint(address(this), tickLower, tickUpper, liquidity, abi.encode(msg.sender));
            _addPositionKey(address(pool), msg.sender, tickLower, tickUpper);
        } else {
            revert("Invalid liquidity == 0");
        }
    }

    function burnLiquidity(IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, address owner, bool collectAll)
        public
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        (uint128 liquidity,,) = position(pool, owner, tickLower, tickUpper);

        if (liquidity > 0) {
            // Burn liquidity
            (uint256 owed0, uint256 owed1) = IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);

            // Collect amount owed
            uint128 collect0 = collectAll ? type(uint128).max : _uint128Safe(owed0);
            uint128 collect1 = collectAll ? type(uint128).max : _uint128Safe(owed1);
            if (collect0 > 0 || collect1 > 0) {
                (amount0, amount1) = IUniswapV3Pool(pool).collect(owner, tickLower, tickUpper, collect0, collect1);
            }

            // Remove position key
            _removePositionKey(address(pool), owner, tickLower, tickUpper);
        }
    }

    function position(IUniswapV3Pool pool, address owner, int24 tickLower, int24 tickUpper)
        public
        view
        returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        bytes32 positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper));
        (liquidity,,, tokensOwed0, tokensOwed1) = pool.positions(positionKey);
    }

    function positionByKey(IUniswapV3Pool pool, bytes32 positionKey)
        public
        view
        returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        (liquidity,,, tokensOwed0, tokensOwed1) = pool.positions(positionKey);
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) =
            LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
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

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) public pure returns (uint160 sqrtPriceX96) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) public pure returns (int24 tick) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function encodePriceSqrtX96(uint256 reserve0, uint256 reserve1) public pure returns (uint160) {
        return _uint160Safe((Math.sqrt(reserve1 / reserve0)) * 2 ** 96);
    }

    function decodePriceSqrtX96(uint160 sqrtPriceX96, uint256 reserve0Unit)
        public
        pure
        returns (uint256 reserve0, uint256 reserve1)
    {
        reserve0 = reserve0Unit;
        reserve1 = ((sqrtPriceX96 / 2 ** 96) ** 2) * reserve0;
    }

    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Delta The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Delta The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        emit SwapCallback(amount0Delta, amount1Delta, data);
        if (msg.sender != _cachedPool) {
            revert("SwapCallback Unauthorized");
        }
        address payer = abi.decode(data, (address));

        if (amount0Delta > 0) {
            if (payer == _cachedMsgSender) {
                IERC20(_cachedToken0).safeTransferFrom(payer, msg.sender, uint256(amount0Delta));
            } else {
                IERC20(_cachedToken0).safeTransfer(msg.sender, uint256(amount0Delta));
            }
        } else if (amount1Delta > 0) {
            if (payer == _cachedMsgSender) {
                IERC20(_cachedToken1).safeTransferFrom(payer, msg.sender, uint256(amount1Delta));
            } else {
                IERC20(_cachedToken1).safeTransfer(msg.sender, uint256(amount1Delta));
            }
        }

        delete _cachedMsgSender;
        delete _cachedPool;
        delete _cachedToken0;
        delete _cachedToken1;
    }

    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0 The amount of token0 due to the pool for the minted liquidity
    /// @param amount1 The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        emit MintCallback(amount0, amount1, data);
        if (msg.sender != _cachedPool) {
            revert("MintCallback Unauthorized");
        }
        address payer = abi.decode(data, (address));

        if (payer == _cachedMsgSender) {
            if (amount0 > 0) IERC20(_cachedToken0).safeTransferFrom(payer, msg.sender, amount0);
            if (amount1 > 0) IERC20(_cachedToken1).safeTransferFrom(payer, msg.sender, amount1);
        } else {
            if (amount0 > 0) IERC20(_cachedToken0).safeTransfer(msg.sender, amount0);
            if (amount1 > 0) IERC20(_cachedToken1).safeTransfer(msg.sender, amount1);
        }

        delete _cachedPool;
        delete _cachedToken0;
        delete _cachedToken1;
        delete _cachedMsgSender;
    }

    /**
     * @notice Calculates amount of liquidity in a position for given token0 and token1 amounts
     *  @param pool The Uniswap V3 pool to get current sqrtRatioX96 from
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param amount0 token0 amount
     *  @param amount1 token1 amount
     */
    function _liquidityForAmounts(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        return getLiquidityForAmounts(
            sqrtRatioX96, getSqrtRatioAtTick(tickLower), getSqrtRatioAtTick(tickUpper), amount0, amount1
        );
    }

    function _getPositionKey(address owner, int24 tickLower, int24 tickUpper) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }

    function _addPositionKey(address pool, address owner, int24 tickLower, int24 tickUpper) internal {
        bytes32 key = _getPositionKey(owner, tickLower, tickUpper);
        _userPositionKeys[owner][pool].push(key);
        emit AddedPositionKey(owner, pool, tickLower, tickUpper, key);
    }

    function _removePositionKey(address pool, address owner, int24 tickLower, int24 tickUpper) internal {
        bytes32 positionKey = _getPositionKey(owner, tickLower, tickUpper);
        bytes32[] storage keys = _userPositionKeys[owner][pool];
        for (uint256 i = 0; i < keys.length; i++) {
            if (keys[i] == positionKey) {
                keys[i] = keys[keys.length - 1];
                keys.pop();
                break;
            }
        }
        emit RemovedPositionKey(owner, pool, tickLower, tickUpper, positionKey);
    }

    function _uint128Safe(uint256 x) internal pure returns (uint128) {
        if (x > type(uint128).max) revert("Unsafe cast");
        return uint128(x);
    }

    /**
     * @notice uint160Safe function
     *  @param x input value
     */
    function _uint160Safe(uint256 x) internal pure returns (uint160) {
        if (x > type(uint160).max) revert("Unsafe cast");
        return uint160(x);
    }
}
