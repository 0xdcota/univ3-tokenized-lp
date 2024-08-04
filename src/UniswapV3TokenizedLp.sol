// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

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

import {IUniswapV3TokenizedLp} from "./interfaces/IUniswapV3TokenizedLp.sol";
import {IUniswapV3MintCallback} from "@uniswap-v3-core/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@uniswap-v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool, IUniswapV3PoolActions} from "@uniswap-v3-core/interfaces/IUniswapV3Pool.sol";
import {UniV3MathHelper} from "./libraries/UniV3MathHelper.sol";
import {ERC20, IERC20Metadata} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract UniswapV3TokenizedLp is
    IUniswapV3TokenizedLp,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;

    uint256 private constant ICLPOOL_SLOT0_SIZE = 192;
    uint256 private constant IUNISWAPV3POOL_SLOT0_SIZE = 224;
    uint16 private constant CARDINALITY = 1000;
    uint32 private constant SPOT_TIME_WEIGHT_PERIOD = 5 minutes;
    string private constant NEXT_BLOCK = "try next block";

    uint256 public constant PRECISION = 10 ** 18;
    uint256 public constant FULL_PERCENT = 10000;
    address public constant NULL_ADDRESS = address(0);
    uint256 public constant DEFAULT_BASE_FEE = 10 ** 17; // 10%
    uint256 public constant DEFAULT_BASE_FEE_SPLIT = 5 * 10 ** 17; // 50%

    bool public allowToken0;
    bool public allowToken1;
    int24 public tickSpacing;
    int24 public baseLower;
    int24 public baseUpper;

    address public pool;
    address public token0;
    address public token1;
    IPriceFeed public usdOracle0Ref;
    IPriceFeed public usdOracle1Ref;

    uint256 public bpsRangeLower;
    uint256 public bpsRangeUpper;
    uint256 public hysteresis;

    uint256 public deposit0Max;
    uint256 public deposit1Max;
    uint256 public maxTotalSupply;

    uint256 public fee;
    uint256 public feeSplit;

    address public feeRecipient;
    address public override affiliate;

    string private _name;
    string private _symbol;

    mapping(address => uint256) private _callerDelayAction;
    mapping(address => bool) public approvedRebalancer;
    uint256 public actionBlockDelay;

    modifier isRebalancer() {
        if (!approvedRebalancer[msg.sender]) {
            revert UniswapV3TokenizedLp_NotAllowed();
        }
        _;
    }

    modifier checkLastBlockAction() {
        {
            uint256 permittedBlock = _callerDelayAction[msg.sender];
            if (permittedBlock != 0 && permittedBlock > block.number) {
                revert UniswapV3TokenizedLp_NoWithdrawOrTransferDuringDelay();
            }
        }
        _;
        _callerDelayAction[msg.sender] = block.number + actionBlockDelay;
    }

    /**
     * @notice Initializes this instance of {UniV3TokenizedLp} based on the `_pool`.
     * @param _pool Uniswap V3 pool for which liquidity is managed
     * @param _allowToken0 flag that indicates whether token0 is accepted during deposit
     * @param _allowToken1 flag that indicates whether token1 is accepted during deposit
     * @param _usdOracle0Ref address of token0 USD oracle
     * @param _usdOracle1Ref address of token1 USD oracle
     * @dev `allowTokenX` params control whether this {UniV3TokenizedLp} allows one-sided or
     * two-sided liquidity provision.
     * NOTE: This contract must be initialized preferably along an atomic deposit(...)` call.
     */
    constructor(address _pool, bool _allowToken0, bool _allowToken1, address _usdOracle0Ref, address _usdOracle1Ref)
        ERC20("", "")
        Ownable(msg.sender)
    {
        if (!_allowToken0 && !_allowToken1) {
            revert UniswapV3TokenizedLp_NoAllowedTokens();
        }

        pool = _pool;
        token0 = IUniswapV3Pool(_pool).token0();
        token1 = IUniswapV3Pool(_pool).token1();
        string memory token0Symbol = ERC20(token0).symbol();
        string memory token1Symbol = ERC20(token1).symbol();
        _name = string(abi.encodePacked("LpToken: ", token0Symbol, "-", token1Symbol));
        _symbol = string(abi.encodePacked("Lp-", token0Symbol, "-", token1Symbol));

        allowToken0 = _allowToken0;
        allowToken1 = _allowToken1;
        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();
        // increase pool observation cardinality
        IUniswapV3Pool(_pool).increaseObservationCardinalityNext(CARDINALITY);
        // default 1% threshold
        hysteresis = (100 * PRECISION) / FULL_PERCENT;
        // default 12.5% range around the current price for base position
        bpsRangeLower = bpsRangeUpper = 1250;
        deposit0Max = deposit1Max = type(uint256).max; // max uint256
        feeRecipient = msg.sender;
        fee = DEFAULT_BASE_FEE;
        feeSplit = DEFAULT_BASE_FEE_SPLIT;
        actionBlockDelay = type(uint8).max;
        usdOracle0Ref = IPriceFeed(_usdOracle0Ref);
        usdOracle1Ref = IPriceFeed(_usdOracle1Ref);

        approvedRebalancer[msg.sender] = true;
        emit ApprovedRebalancer(msg.sender, true);
    }

    /// Common functions

    /**
     * @notice Distributes shares to depositor equal to the token1 value of his deposit multiplied by
     * the ratio of total lp shares issued divided by the pool's AUM measured in token1 value.
     * @param deposit0 Amount of token0 transferred from sender
     * @param deposit1 Amount of token1 transferred from sender
     * @param to Address to which lp tokens are minted
     * @param shares Quantity of lp tokens minted as a result of deposit
     */
    function deposit(uint256 deposit0, uint256 deposit1, address to)
        external
        override
        nonReentrant
        returns (uint256 shares)
    {
        if (!allowToken0 && deposit0 > 0) {
            revert UniswapV3TokenizedLp_Token0NotAllowed();
        }
        if (!allowToken1 && deposit1 > 0) {
            revert UniswapV3TokenizedLp_Token1NotAllowed();
        }
        if (deposit0 == 0 && deposit1 == 0) {
            revert UniswapV3TokenizedLp_ZeroValue();
        }
        if (deposit0 > deposit0Max || deposit1 > deposit1Max) {
            revert UniswapV3TokenizedLp_MoreThanMaxDeposit();
        }
        if (to == NULL_ADDRESS) revert UniswapV3TokenizedLp_ZeroAddress();

        // Updates pending fees in pool state for inclusion when calling `getTotalAmounts()`
        {
            (uint128 baseLiquidity,,) = _position(baseLower, baseUpper);
            if (baseLiquidity > 0) {
                // Update fee state at pool
                (uint256 burn0, uint256 burn1) = _callBurnAtPool(baseLower, baseUpper, 0);
                if (burn0 != 0 || burn1 != 0) {
                    revert UniswapV3TokenizedLp_UnexpectedBurn();
                }
            }
        }

        // Check if price has not been manipulated in this block.
        (, uint256 oraclePrice) = _checkPriceDelta();

        (uint256 pool0, uint256 pool1) = _getTotalAmounts();

        // Price the `deposit0` amount in token1 at oracle price
        uint256 deposit0PricedInToken1 = (deposit0 * oraclePrice) / PRECISION;

        if (deposit0 > 0) {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), deposit0);
        }
        if (deposit1 > 0) {
            IERC20(token1).safeTransferFrom(msg.sender, address(this), deposit1);
        }

        // Shares in value of token1
        shares = deposit1 + deposit0PricedInToken1;

        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ != 0) {
            // Price the pool0 in token1 at oracle price
            uint256 pool0PricedInToken1 = (pool0 * oraclePrice) / PRECISION;
            // Compute ratio of total shares to pool AUM in token1
            shares = (shares * totalSupply_) / (pool0PricedInToken1 + pool1);

            if (shares + totalSupply_ > maxTotalSupply) revert UniswapV3TokenizedLp_MaxTotalSupplyExceeded();
        }

        // Set a delay guard for `to` attempting a withdraw action
        _callerDelayAction[to] = block.number + actionBlockDelay;
        _mint(to, shares);
        emit Deposit(msg.sender, to, shares, deposit0, deposit1);

        // If bounds are defined, mint max liquidity in the pool
        if (baseLower != 0 || baseUpper != 0) {
            _mintLiquidityFromIdleBalances();
        }
    }

    /**
     * @notice Redeems shares by sending out a portion of the UniV3TokenizedLp's AUM.
     * This portion is equal to the percentage ownership of total issued shares represented by the redeemed shares.
     * NOTE: Amounts close to one-wei-unit (or equivalent) may be lost due to division precision in
     * favor of all remaining depositors.
     * @param shares Number of liquidity tokens to redeem as pool assets
     * @param to Address to which redeemed pool assets are sent
     * @param amount0 Amount of token0 redeemed by the submitted liquidity tokens
     * @param amount1 Amount of token1 redeemed by the submitted liquidity tokens
     */
    function withdraw(uint256 shares, address to)
        external
        override
        nonReentrant
        checkLastBlockAction
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0) revert UniswapV3TokenizedLp_ZeroValue();
        if (to == NULL_ADDRESS) revert UniswapV3TokenizedLp_ZeroAddress();

        // Collect all fees from Uniswap pool
        _updatePoolCollectAndDistributeFees(true);

        // Withdraw share amount of liquidity from the Uniswap pool and collect `to`
        (uint256 base0, uint256 base1) =
            _burnLiquidity(baseLower, baseUpper, _liquidityForShares(baseLower, baseUpper, shares));
        IUniswapV3Pool(pool).collect(
            to, baseLower, baseUpper, UniV3MathHelper.uint128Safe(base0), UniV3MathHelper.uint128Safe(base1)
        );

        // Compute proportion of unused balances in this contract relative to `shares`
        // Note: Sending tokens directly to alter the balances of this address will result in a loss to the sender-caller.
        uint256 _totalSupply = totalSupply();
        uint256 unusedAmount0 = (_callBalanceOfThis(token0) * (shares)) / _totalSupply;
        uint256 unusedAmount1 = (_callBalanceOfThis(token1) * (shares)) / _totalSupply;
        if (unusedAmount0 > 0) IERC20(token0).safeTransfer(to, unusedAmount0);
        if (unusedAmount1 > 0) IERC20(token1).safeTransfer(to, unusedAmount1);

        amount0 = base0 + unusedAmount0;
        amount1 = base1 + unusedAmount1;

        _burn(msg.sender, shares);

        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /// Setter Functions

    /**
     * @notice Sets the usdOracle0Ref and usdOracle1Ref addresses
     * @param usdOracle0Ref_ address of token0 USD oracle
     * @param usdOracle1Ref_ address of token1 USD oracle
     */
    function setUsdOracles(address usdOracle0Ref_, address usdOracle1Ref_) external onlyOwner {
        if (usdOracle0Ref_ == NULL_ADDRESS || usdOracle1Ref_ == NULL_ADDRESS) {
            revert UniswapV3TokenizedLp_ZeroAddress();
        }
        usdOracle0Ref = IPriceFeed(usdOracle0Ref_);
        usdOracle1Ref = IPriceFeed(usdOracle1Ref_);
        emit UsdOracleReferences(usdOracle0Ref_, usdOracle1Ref_);
    }

    /**
     * @notice Sets the bpsRangeLower and bpsRangeUpper values
     * @param _bpsRangeLower lower bound percent below the target price
     * @param _bpsRangeUpper upper bound percent above the target price
     * @dev _bpsRangeLower and _bpsRangeUpper should be in the range [1, 10000]
     */
    function setBpsRanges(uint256 _bpsRangeLower, uint256 _bpsRangeUpper) external onlyOwner {
        if (
            _bpsRangeLower > FULL_PERCENT || _bpsRangeUpper > FULL_PERCENT || _bpsRangeLower == 0 || _bpsRangeUpper == 0
        ) {
            revert UniswapV3TokenizedLp_InvalidBaseBpsRange();
        }
        bpsRangeLower = _bpsRangeLower;
        bpsRangeUpper = _bpsRangeUpper;
        emit BpsRanges(_bpsRangeLower, _bpsRangeUpper);
    }

    /**
     * @notice Sets the fee recipient account address, where portion of the collected swap fees will be distributed
     * @param _feeRecipient The fee recipient account address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) {
            revert UniswapV3TokenizedLp_ZeroAddress();
        }
        // Settle outstanding fees
        _updatePoolCollectAndDistributeFees(true);
        feeRecipient = _feeRecipient;
        emit FeeRecipient(_feeRecipient);
    }

    /**
     * @notice Sets the fee percentage to be taken from the accumulated pool's swap fees.
     * This percentage is distributed between the feeRecipient and affiliate accounts
     * @param _fee The fee percentage to be taken from the accumulated pool's swap fee
     */
    function setFee(uint256 _fee) external onlyOwner {
        if (_fee > PRECISION) {
            revert UniswapV3TokenizedLp_FeeMustBeLtePrecision();
        }
        // Settle outstanding fees
        _updatePoolCollectAndDistributeFees(true);
        fee = _fee;
        emit FeeUpdate(_fee);
    }

    /**
     * @notice Sets the fee split ratio between feeRecipient and affiliate accounts.
     * @param _feeSplit The fee split ratio for feeRecipient
     * @dev _feeSplit should be less than PRECISION (100%)
     * Example
     * If `feeRecipient` should receive 80% of the collected swap fees,
     * then `_feeSplit` should be 8e17 (80% of 1e18)
     */
    function setFeeSplit(uint256 _feeSplit) external onlyOwner {
        if (_feeSplit > PRECISION) {
            revert UniswapV3TokenizedLp_SplitMustBeLtePrecision();
        }
        // Settle outstanding fees
        _updatePoolCollectAndDistributeFees(true);
        feeSplit = _feeSplit;
        emit FeeSplit(_feeSplit);
    }

    /**
     * @notice Sets the hysteresis threshold (in percentage from 1 ether unit, example: 10**16 = 1%).
     * When difference between spot price and external Oracle exceeds the threshold, a check for a flashloan attack is executed during deposits
     * and triggers autoRebalance position change.
     * @param _hysteresis hysteresis threshold
     * @dev _hysteresis should be less than PRECISION (100%)
     */
    function setHysteresis(uint256 _hysteresis) external onlyOwner {
        if (_hysteresis >= PRECISION) {
            revert UniswapV3TokenizedLp_FeeMustBeLtePrecision();
        }
        hysteresis = _hysteresis;
        emit Hysteresis(_hysteresis);
    }

    /**
     * @notice Sets the affiliate account address where portion of the collected swap fees will be distributed
     * @param _affiliate The affiliate account address
     * @dev If `affiliate` is set to the zero address, 100% of the fee will go to the `feeRecipient`
     */
    function setAffiliate(address _affiliate) external override onlyOwner {
        // Settle outstanding fees
        _updatePoolCollectAndDistributeFees(true);
        affiliate = _affiliate;
        emit Affiliate(_affiliate);
    }

    /**
     * @notice Sets the account address to be approved or not for rebalancing the position
     */
    function setApprovedRebalancer(address account, bool approved) external onlyOwner {
        if (account == NULL_ADDRESS) revert UniswapV3TokenizedLp_ZeroAddress();
        approvedRebalancer[account] = approved;
        emit ApprovedRebalancer(account, approved);
    }

    /**
     * @notice Sets the maximum token0 and token1 amounts the contract allows in a deposit call.
     * @param _deposit0Max The maximum amount of token0 allowed in a deposit
     * @param _deposit1Max The maximum amount of token1 allowed in a deposit
     * @dev Use this to control incoming size and ratios of token0 and token1
     */
    function setDepositMax(uint256 _deposit0Max, uint256 _deposit1Max) external override onlyOwner {
        deposit0Max = _deposit0Max;
        deposit1Max = _deposit1Max;
        emit DepositMax(_deposit0Max, _deposit1Max);
    }

    /**
     * @notice Sets the maximum total supply of the UniswapV3TokenizedLp token
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupply(_maxTotalSupply);
    }

    /**
     * @notice Sets the `actionBlockDelay` that guards against continuos `deposit()` and / or `withdraw()` calls.
     * @param _blockWaitTime defined
     * @dev Must NEVER be zero.
     */
    function setActionBlockDelay(uint256 _blockWaitTime) external onlyOwner {
        if (_blockWaitTime == 0) revert UniswapV3TokenizedLp_ZeroValue();
        actionBlockDelay = _blockWaitTime;
        emit ActionBlockDelay(_blockWaitTime);
    }

    /// View (or same as "view" intended) functions

    /**
     * @inheritdoc IERC20Metadata
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @inheritdoc IERC20Metadata
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Public method that calculates total quantity of token0 and token1 (AUM) of this UniV3TokenizedLp.
     * NOTE: This method is an approximate and does not include the latest fees collected in the position as from
     * the last "Deposit", "Withdraw", or "Rebalance" event.
     * @dev Checks price has not been manipulated in this block
     * @return total0 Quantity of token0 in both positions (and unused)
     * @return total1 Quantity of token1 in both positions (and unused)
     */
    function getTotalAmounts() public view override returns (uint256 total0, uint256 total1) {
        _checkPriceDelta();
        (total0, total1) = _getTotalAmounts();
    }

    /**
     * @notice Optional non-view method that can be used to get the latest totalAmounts including fees
     * This method updates the state of fees at the pool.
     */
    function getTotalAmountsFeeAccumulated() external returns (uint256 total0, uint256 total1) {
        _callBurnAtPool(baseLower, baseUpper, 0);
        (total0, total1) = _getTotalAmounts();
    }

    /**
     * @notice External method that calculates amount of total liquidity in the base position
     * @dev Checks price has not been manipulated in this block beyond `hysteresis`.
     * NOTE: This method is an approximate and does not include the latest fees collected in the position as from
     * the last "Deposit", "Withdraw", or "Rebalance" event.
     * @return liquidity Amount of total "virtual" liquidity in the base position
     * @return amount0 Estimated amount of token0 that could be collected by burning the base position
     * @return amount1 Estimated amount of token1 that could be collected by burning the base position
     */
    function getBasePosition() public view returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        _checkPriceDelta();
        (liquidity, amount0, amount1) = _getBasePosition();
    }

    /**
     * @notice Optional non-view method that can be used to get the latest base position including fees
     * This method updates the state of fees at the pool.
     */
    function getBasePositionFeeAccumulated() external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        _callBurnAtPool(baseLower, baseUpper, 0);
        (liquidity, amount0, amount1) = getBasePosition();
    }

    /**
     * @notice Returns current price tick
     *  @param tick Uniswap pool's current price tick
     */
    function currentTick() public view returns (int24 tick) {
        (, int24 tick_,, bool unlocked_) = _queryPoolSlot0();
        if (!unlocked_) revert UniswapV3TokenizedLp_PoolLocked();
        tick = tick_;
    }

    /**
     * @notice Returns current sqrtPriceX96 of the pool
     */
    function getCurrentSqrtPriceX96() public view returns (uint160 sqrtPriceX96) {
        (uint160 sqrtPriceX96_,,, bool unlocked_) = _queryPoolSlot0();
        if (!unlocked_) revert UniswapV3TokenizedLp_PoolLocked();
        sqrtPriceX96 = sqrtPriceX96_;
    }

    /**
     * @notice Returns the time weighted sqrtPriceX96 of the pool at `SPOT_TIME_WEIGHT_PERIOD` ago
     */
    function getTimeWeightedSqrtPriceX96() public view returns (uint160 sqrtPriceX96) {
        (,,, bool unlocked_) = _queryPoolSlot0();
        if (!unlocked_) revert UniswapV3TokenizedLp_PoolLocked();
        int24 timeWeightedAverageTick = UniV3MathHelper.consult(pool, SPOT_TIME_WEIGHT_PERIOD);
        sqrtPriceX96 = UniV3MathHelper.getSqrtRatioAtTick(timeWeightedAverageTick);
    }

    /**
     * @notice returns approximate _tokenOut for _amountIn, _tokenIn
     * using `SPOT_TIME_WEIGHT_PERIOD` pool price
     *  @param _tokenIn token the input amount is in
     *  @param _tokenOut token for the output amount
     *  @param _amountIn amount in _tokenIn
     *  @param amountOut equivalent amount in _tokenOut
     */
    function fetchSpot(address _tokenIn, address _tokenOut, uint256 _amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        int24 timeWeightedAverageTick = UniV3MathHelper.consult(pool, SPOT_TIME_WEIGHT_PERIOD);
        return UniV3MathHelper.getQuoteAtTick(
            timeWeightedAverageTick, UniV3MathHelper.uint128Safe(_amountIn), _tokenIn, _tokenOut
        );
    }

    /**
     * @notice returns equivalent _tokenOut for _amountIn, _tokenIn using external oracle price
     *  @param tokenIn_ token the input amount is in
     *  @param tokenOut_ token for the output amount
     *  @param amountIn_ amount in _tokenIn
     *  @param amountOut equivalent amount in _tokenOut
     */
    function fetchOracle(address tokenIn_, address tokenOut_, uint256 amountIn_)
        public
        view
        returns (uint256 amountOut)
    {
        // Kept `usdNormalizedX` stack vars for readability.
        (uint256 usdNormalizedIn, uint256 usdNormalizedOut) = tokenIn_ == token0
            ? (_getUsdValue(usdOracle0Ref), _getUsdValue(usdOracle1Ref))
            : (_getUsdValue(usdOracle1Ref), _getUsdValue(usdOracle0Ref));
        amountOut = (amountIn_ * usdNormalizedIn * 10 ** uint256(ERC20(tokenOut_).decimals()))
            / (usdNormalizedOut * 10 ** uint256(ERC20(tokenIn_).decimals()));
    }

    /**
     * @notice Rebalance the lp position around the target external oracle price.
     * The base position is updated to be `bpsRangeLower` percent and `bpsRangeUpper` percent around the external oracle price.
     * If `withSwapping` is true, and the difference between the spot price and the external oracle price is larger than `hysteresis`
     * the call will attempt to swap either side of the AUM tokens as required to match the target price.
     * Fees are collected and distributed in the process.
     * @dev If `withSwapping` is true and there is not external liquidity in the pool to swap the required amount
     * to establish sqrtPriceX96 to the target oracle price in range, this call will revert.
     * This is an issue if this contract is not a majority holder of the `pool`'s liquidity,
     * @param useOracleForNewBounds if true, new bounds are set around `oraclePrice`, otherwise around the `spotTimeWeightedPrice`
     * @param withSwapping If true, the contract will attempt to swap tokens to reach the target price
     * @return amount0 Amount of token0 swapped
     * @return amount1 Amount of token1 swapped
     */
    function autoRebalance(bool useOracleForNewBounds, bool withSwapping)
        public
        nonReentrant
        isRebalancer
        returns (int256 amount0, int256 amount1)
    {
        if (baseLower == 0 && baseUpper == 0) {
            revert UniswapV3TokenizedLp_SetBaseTicksViaRebalanceFirst();
        }

        (uint256 token0Bal, uint256 token1Bal) = _updateAndBurnAllPosition();

        // Get spot and external oracle prices
        uint256 spotTimeWeightedPrice = fetchSpot(token0, token1, PRECISION);
        uint256 oraclePrice = fetchOracle(token0, token1, PRECISION);

        // Check if difference between spot and oraclePrice is too big
        uint256 delta = (spotTimeWeightedPrice > oraclePrice)
            ? ((spotTimeWeightedPrice - oraclePrice) * PRECISION) / oraclePrice
            : ((oraclePrice - spotTimeWeightedPrice) * PRECISION) / oraclePrice;
        uint256 priceRefForBounds = useOracleForNewBounds ? oraclePrice : spotTimeWeightedPrice;

        // Calculate the new baseLower and baseUpper ticks. It is required to encode the price into sqrtPriceX96
        int24 baseLower_ = UniV3MathHelper.roundTick(
            UniV3MathHelper.getTickAtSqrtRatio(
                UniV3MathHelper.encodePriceSqrtX96(
                    PRECISION, ((priceRefForBounds * (FULL_PERCENT - bpsRangeLower)) / FULL_PERCENT)
                )
            ),
            tickSpacing
        );
        int24 baseUpper_ = UniV3MathHelper.roundTick(
            UniV3MathHelper.getTickAtSqrtRatio(
                UniV3MathHelper.encodePriceSqrtX96(
                    PRECISION, ((priceRefForBounds * (FULL_PERCENT + bpsRangeUpper)) / FULL_PERCENT)
                )
            ),
            tickSpacing
        );

        // Set the new baseLower and baseUpper ticks
        baseLower = baseLower_;
        baseUpper = baseUpper_;

        uint128 baseLiquidity = _liquidityForAmounts(baseLower, baseUpper, token0Bal, token1Bal);

        if ((withSwapping && (delta > hysteresis)) || baseLower != baseLower_ || baseUpper != baseUpper_) {
            // Swap tokens if required to reach the target price
            uint160 sqrtPriceRefX96 = getCurrentSqrtPriceX96();
            uint160 sqrtPriceTargetX96 = UniV3MathHelper.encodePriceSqrtX96(PRECISION, priceRefForBounds);
            if (sqrtPriceRefX96 != sqrtPriceTargetX96) {
                // Determine if it is a token0-to-token1 or opposite swap
                bool zeroToOne = sqrtPriceRefX96 > sqrtPriceTargetX96;
                (amount0, amount1) = IUniswapV3Pool(pool).swap(
                    address(this),
                    zeroToOne,
                    zeroToOne ? int256(token0Bal) : int256(token1Bal),
                    sqrtPriceTargetX96, // Swap through ticks until the target price is reached or run out of tokens
                    abi.encode(address(this))
                );
                if (!_checkPositionIsInRange(currentTick())) {
                    revert UniswapV3TokenizedLp_PositionOutOfRange();
                }
            }

            // Recalculate `baseLiquidity` after swapping
            baseLiquidity =
                _liquidityForAmounts(baseLower, baseUpper, _callBalanceOfThis(token0), _callBalanceOfThis(token1));
        }
        _mintLiquidity(baseLower, baseUpper, baseLiquidity);
    }

    /**
     * @notice Updates "force" the UniV3TokenizedLp's LP position at the specified ticks
     * and performs the indicated swap with an optional limit price.
     * @param _baseLower The lower tick of the base position
     * @param _baseUpper The upper tick of the base position
     * @param swapQuantity Quantity of tokens to swap; if quantity is positive, `swapQuantity` token0 are
     * swapped for token1, if negative, `swapQuantity` token1 is swapped for token0
     * @param tickLimit tick limit (converted internally to sqrtPriceX96) to protect against slippage of the `swapQuantity`.
     * Pass `type(int24).max` to swap through the ticks until the `swapQuantity` is exhausted.
     * Beware that passing `tickLimit` == type(int24).max is a slippage unprotected swap.
     * @dev Refer to {IUniswapV3PoolActions.swap(...)} for more details on the `limit` parameter.
     */
    function rebalance(int24 _baseLower, int24 _baseUpper, int256 swapQuantity, int24 tickLimit)
        public
        nonReentrant
        isRebalancer
    {
        if (_baseLower >= _baseUpper || _baseLower % tickSpacing != 0 || _baseUpper % tickSpacing != 0) {
            revert UniswapV3TokenizedLp_BasePositionInvalid();
        }
        (uint256 token0Bal, uint256 token1Bal) = _updateAndBurnAllPosition();

        // Swap tokens if required as specified by `swapQuantity`
        if (swapQuantity != 0) {
            uint160 sqrtPriceX96Limit = tickLimit == type(int24).max ? 0 : UniV3MathHelper.getSqrtRatioAtTick(tickLimit);
            // If no limit on the price, swap through the ticks, until the `swapQuantity` is exhausted
            uint160 swapLimit = sqrtPriceX96Limit != 0
                ? sqrtPriceX96Limit
                : swapQuantity > 0 ? UniV3MathHelper.MIN_SQRT_RATIO + 1 : UniV3MathHelper.MAX_SQRT_RATIO - 1;
            IUniswapV3Pool(pool).swap(
                address(this),
                swapQuantity > 0, // zeroToOne == true if swapQuantity is positive
                swapQuantity > 0 ? swapQuantity : -swapQuantity,
                swapLimit,
                abi.encode(address(this))
            );

            // Read balances after swap
            token0Bal = _callBalanceOfThis(token0);
            token1Bal = _callBalanceOfThis(token1);
        }

        baseLower = _baseLower;
        baseUpper = _baseUpper;

        // Mint liquidity at the new baseLower and baseUpper ticks
        uint128 baseLiquidity = _liquidityForAmounts(baseLower, baseUpper, token0Bal, token1Bal);
        _mintLiquidity(baseLower, baseUpper, baseLiquidity);
    }

    /**
     * @notice Swaps idle tokens including this contract's own liquidity and if `addToLiquidity` the new idle amounts
     * are deployed to the base position
     * @param swapInputAmount Quantity of tokens to swap; if quantity is positive, `swapInputAmount` token0 are
     * swapped for token1, if negative, `swapInputAmount` token1 is swapped for token0
     * @param tickLimit tick limit (converted internally to sqrtPriceX96) to protect against slippage of the `swapQuantity`.
     * Pass `type(int24).max` to swap through the ticks until the `swapQuantity` is exhausted.
     * Beware that passing `tickLimit` == type(int24).max is a slippage unprotected swap.
     * @param addToLiquidity If true, the contract will attempt to add the new idle liquidity to the pool at the base position
     * @dev Refer to {IUniswapV3PoolActions.swap(...)} for more details on the `limit` parameter.
     * If `swapInputAmount` is greater than the idle balance of the token, the swap will be limited to the idle balance.
     */
    function swapIdleAndAddToLiquidity(int256 swapInputAmount, int24 tickLimit, bool addToLiquidity)
        public
        nonReentrant
        isRebalancer
        returns (int256 amount0, int256 amount1)
    {
        if (baseLower == 0 && baseUpper == 0) {
            revert UniswapV3TokenizedLp_SetBaseTicksViaRebalanceFirst();
        }
        if (swapInputAmount == 0) revert UniswapV3TokenizedLp_ZeroValue();

        int256 effectiveSwapQty;
        {
            if (swapInputAmount > 0) {
                uint256 token0Bal = _callBalanceOfThis(token0);
                // It is safe to directly cast because we know `swapQuantity` is positive
                effectiveSwapQty = uint256(swapInputAmount) > token0Bal ? int256(token0Bal) : swapInputAmount;
            } else {
                uint256 token1Bal = _callBalanceOfThis(token1);
                // It is safe to directly cast because we convert known negative `swapQuantity` value to positive
                effectiveSwapQty = uint256(-swapInputAmount) > token1Bal ? -int256(token1Bal) : swapInputAmount;
            }
        }

        // If no limit on the price, swap through the ticks, until the `swapQuantity` is exhausted
        uint160 sqrtPriceX96Limit = tickLimit == type(int24).max ? 0 : UniV3MathHelper.getSqrtRatioAtTick(tickLimit);
        uint160 swapLimit = sqrtPriceX96Limit != 0
            ? sqrtPriceX96Limit
            : effectiveSwapQty > 0 ? UniV3MathHelper.MIN_SQRT_RATIO + 1 : UniV3MathHelper.MAX_SQRT_RATIO - 1;

        (amount0, amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            effectiveSwapQty > 0, // zeroToOne == true if swapQuantity is positive
            effectiveSwapQty > 0 ? effectiveSwapQty : -effectiveSwapQty,
            swapLimit,
            abi.encode(address(this))
        );
        if (addToLiquidity) {
            _mintLiquidityFromIdleBalances();
        }
    }

    /// Internal functions

    /**
     * @dev Mints liquidity with the available idle balances of this contract at
     * the existing baseLower and baseUpper ticks.
     */
    function _mintLiquidityFromIdleBalances() internal {
        uint128 baseLiquidity =
            _liquidityForAmounts(baseLower, baseUpper, _callBalanceOfThis(token0), _callBalanceOfThis(token1));
        _mintLiquidity(baseLower, baseUpper, baseLiquidity);
    }

    /**
     * @dev Checks if the price has been manipulated in this block
     */
    function _checkPriceDelta() internal view returns (uint256 spotPrice, uint256 oraclePrice) {
        // Current spot price of token1/token0 at pool
        spotPrice =
            UniV3MathHelper.getQuoteAtTick(currentTick(), UniV3MathHelper.uint128Safe(PRECISION), token0, token1);
        // External oracle price of token1/token0
        oraclePrice = fetchOracle(token0, token1, PRECISION);

        // If difference between spot and oracle is bigger than `hysteresis`, it
        // checks the timestamp of the last `observation` at the pool
        // to confirm if price has been manipulated in this block
        uint256 delta = (spotPrice > oraclePrice)
            ? ((spotPrice - oraclePrice) * PRECISION) / spotPrice
            : ((oraclePrice - spotPrice) * PRECISION) / oraclePrice;
        if (delta > hysteresis) require(_checkHysteresis(), NEXT_BLOCK);
    }

    /**
     * @dev Query the pool's slot0 and this address balances at the pool's spot sqrtPriceX96
     */
    function _getTotalAmounts() internal view returns (uint256 total0, uint256 total1) {
        (, uint256 base0, uint256 base1) = _getBasePosition();
        total0 = _callBalanceOfThis(token0) + base0;
        total1 = _callBalanceOfThis(token1) + base1;
    }

    /**
     * @dev Query the pool's base position at the pool's spot sqrtPriceX96
     */
    function _getBasePosition() internal view returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        (uint128 positionLiquidity, uint128 tokensOwed0, uint128 tokensOwed1) = _position(baseLower, baseUpper);
        (amount0, amount1) = _amountsForLiquidity(baseLower, baseUpper, positionLiquidity);
        liquidity = positionLiquidity;
        amount0 = amount0 + uint256(tokensOwed0);
        amount1 = amount1 + uint256(tokensOwed1);
    }

    /**
     * @dev Common snippet to call the {IUniswapV3Pool.burn(...)} method
     * NOTE: Passing `liquidityAmount` == 0 can be used to update the state of fees at the pool.
     * See IUniswapV3PoolActions.burn(...) interface docs
     */
    function _callBurnAtPool(int24 tickLower, int24 tickUpper, uint128 liquidityAmount)
        internal
        returns (uint256 owed0, uint256 owed1)
    {
        (owed0, owed1) = IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidityAmount);
    }

    /**
     * @dev Common snippet to call the {IERC20.balanceOf(address(this))} method
     * Used across multiple places.
     */
    function _callBalanceOfThis(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Updates the state of the pool, and if indicated distributes fees.
     * Use `distributeNow == true` when calling in `withdraw()`
     * Use `distributeNow == false` when calling in `_updateAndBurnAllPosition()`
     */
    function _updatePoolCollectAndDistributeFees(bool distributeNow)
        internal
        returns (uint128 fees0, uint128 fees1, uint128 baseLiquidity)
    {
        // Update fee state at pool
        (baseLiquidity,,) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            _callBurnAtPool(baseLower, baseUpper, 0);
        }

        // Get now the collectable fees from Uniswap pool
        (, fees0, fees1) = _position(baseLower, baseUpper);

        if (distributeNow) {
            if (fees0 > 0 || fees1 > 0) {
                IUniswapV3Pool(pool).collect(address(this), baseLower, baseUpper, fees0, fees1);
            }
            _distributeFees(fees0, fees1);
        }
    }

    /**
     * @dev Contains the common flow between rebalance and autoRebalance functions
     * - Updates fees
     * - Burns all liquidity
     * - Collects all the liquidity
     * - Distributes fees
     * - Returns token0 and token1 balances
     * @return token0Bal Amount of token0
     * @return token1Bal Amount of token1
     */
    function _updateAndBurnAllPosition() internal returns (uint256, uint256) {
        (uint256 feesBase0, uint256 feesBase1, uint128 baseLiquidity) = _updatePoolCollectAndDistributeFees(false);
        // Withdraw all liquidity
        _burnLiquidity(baseLower, baseUpper, baseLiquidity);
        IUniswapV3Pool(pool).collect(address(this), baseLower, baseUpper, type(uint128).max, type(uint128).max);
        _distributeFees(feesBase0, feesBase1);

        uint256 token0Bal = _callBalanceOfThis(token0);
        uint256 token1Bal = _callBalanceOfThis(token1);
        emit Rebalance(currentTick(), token0Bal, token1Bal, feesBase0, feesBase1, totalSupply());
        return (token0Bal, token1Bal);
    }

    /**
     * @notice Sends portion of swap fees to feeRecipient and affiliate.
     *  @param fees0 fees for token0
     *  @param fees1 fees for token1
     */
    function _distributeFees(uint256 fees0, uint256 fees1) internal {
        // if there is no affiliate 100% of the fee should go to feeRecipient
        uint256 feeSplit_ = (affiliate == NULL_ADDRESS) ? PRECISION : feeSplit;

        if (feeRecipient == NULL_ADDRESS) revert UniswapV3TokenizedLp_ZeroAddress();

        if (fee > 0) {
            if (fees0 > 0) {
                uint256 totalFee = (fees0 * fee) / PRECISION;
                uint256 toRecipient = (totalFee * feeSplit_) / PRECISION;
                uint256 toAffiliate = totalFee - toRecipient;
                IERC20(token0).safeTransfer(feeRecipient, toRecipient);
                if (toAffiliate > 0) {
                    IERC20(token0).safeTransfer(affiliate, toAffiliate);
                }
            }
            if (fees1 > 0) {
                uint256 totalFee = (fees1 * fee) / PRECISION;
                uint256 toRecipient = (totalFee * feeSplit_) / PRECISION;
                uint256 toAffiliate = totalFee - toRecipient;
                IERC20(token1).safeTransfer(feeRecipient, toRecipient);
                if (toAffiliate > 0) {
                    IERC20(token1).safeTransfer(affiliate, toAffiliate);
                }
            }
        }
    }

    /**
     * @notice Mint liquidity in Uniswap V3 pool.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity Amount of liquidity to mint
     *  @param amount0 Used amount of token0
     *  @param amount1 Used amount of token1
     */
    function _mintLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity > 0) {
            (amount0, amount1) =
                IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, abi.encode(address(this)));
        }
    }

    /**
     * @notice Burn liquidity in Uniswap V3 pool.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity amount of liquidity to burn
     *  @param owed0 released amount of token0
     *  @param owed1 released amount of token1
     */
    function _burnLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        returns (uint256 owed0, uint256 owed1)
    {
        if (liquidity > 0) {
            // Burn liquidity
            (owed0, owed1) = _callBurnAtPool(tickLower, tickUpper, liquidity);
        }
    }

    /**
     * @notice Calculates the "virtual" liquidity amount for the given shares.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param shares number of shares
     */
    function _liquidityForShares(int24 tickLower, int24 tickUpper, uint256 shares) internal view returns (uint128) {
        (uint128 position,,) = _position(tickLower, tickUpper);
        return UniV3MathHelper.uint128Safe((uint256(position) * shares) / totalSupply());
    }

    /**
     * @notice Returns information about the liquidity position.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity virtual liquidity amount
     *  @param tokensOwed0 amount of token0 owed to the owner of the position
     *  @param tokensOwed1 amount of token1 owed to the owner of the position
     */
    function _position(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        bytes32 positionKey = keccak256(abi.encodePacked(address(this), tickLower, tickUpper));
        (liquidity,,, tokensOwed0, tokensOwed1) = IUniswapV3Pool(pool).positions(positionKey);
    }

    /**
     * @notice Checks if the last price change happened in the current block
     */
    function _checkHysteresis() private view returns (bool) {
        (,, uint16 observationIndex,) = _queryPoolSlot0();
        (uint32 blockTimestamp,,,) = IUniswapV3Pool(pool).observations(observationIndex);
        return (block.timestamp != blockTimestamp);
    }

    /**
     * @notice Checks if the `refTick` is within pool's defined
     * baseLower and baseUpper ticks
     */
    function _checkPositionIsInRange(int24 refTick) private view returns (bool) {
        if (refTick >= baseLower && refTick <= baseUpper) return true;
        else return false;
    }

    /**
     * @notice Calculates token0 and token1 amounts for virtual liquidity in a position
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity Amount of virtual liquidity in the position
     */
    function _amountsForLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        view
        returns (uint256, uint256)
    {
        uint160 sqrtRatioRefX96 = getCurrentSqrtPriceX96();
        return UniV3MathHelper.getAmountsForLiquidity(
            sqrtRatioRefX96,
            UniV3MathHelper.getSqrtRatioAtTick(tickLower),
            UniV3MathHelper.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    /**
     * @notice Calculates amount of liquidity in a position for given token0 and token1 amounts
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param amount0 token0 amount
     *  @param amount1 token1 amount
     */
    function _liquidityForAmounts(int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint128)
    {
        uint160 sqrtPriceRefX96 = getCurrentSqrtPriceX96();
        return UniV3MathHelper.getLiquidityForAmounts(
            sqrtPriceRefX96,
            UniV3MathHelper.getSqrtRatioAtTick(tickLower),
            UniV3MathHelper.getSqrtRatioAtTick(tickUpper),
            amount0,
            amount1
        );
    }

    /**
     * @notice Calculates normalized USD value of token referenced in `usdOracle_`
     * @param usdOracle_  oracle to get price
     */
    function _getUsdValue(IPriceFeed usdOracle_) internal view returns (uint256) {
        return (PRECISION * uint256(usdOracle_.latestAnswer())) / 10 ** usdOracle_.decimals();
    }

    /**
     * @dev Internal method that queries the pool slot0 state
     * Note: Since the pool can be either IUniswapV3Pool or ICLPool, it tries to query both
     * @return sqrtPriceX96 The current sqrtPriceX96
     * @return tick The current tick
     * @return observationIndex The current observation index
     * @return unlocked The pool's unlocked status
     */
    function _queryPoolSlot0()
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, bool unlocked)
    {
        (bool success, bytes memory returnedData) = pool.staticcall(abi.encodeWithSignature("slot0()"));
        if (!success) revert UniswapV3TokenizedLp_failedToQueryPool();
        if (returnedData.length == ICLPOOL_SLOT0_SIZE) {
            (sqrtPriceX96, tick, observationIndex,,, unlocked) =
                abi.decode(returnedData, (uint160, int24, uint16, uint16, uint16, bool));
        } else if (returnedData.length == IUNISWAPV3POOL_SLOT0_SIZE) {
            (sqrtPriceX96, tick, observationIndex,,,, unlocked) =
                abi.decode(returnedData, (uint160, int24, uint16, uint16, uint16, uint8, bool));
        } else {
            revert UniswapV3TokenizedLp_invalidSlot0Size();
        }
    }

    /// Hooks

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        _afterTokenTransfer(from, to, value);
    }

    /**
     * @dev Carry block delay guard for all transfers except for `approvedRebalancers`
     */
    function _afterTokenTransfer(address from, address, uint256 amount) internal view {
        if (from != address(0) && amount != 0) {
            uint256 permittedBlock = _callerDelayAction[from];
            if (!approvedRebalancer[from] && permittedBlock != 0 && permittedBlock > block.number) {
                revert UniswapV3TokenizedLp_NoWithdrawOrTransferDuringDelay();
            }
        }
    }

    /// Uniswap V3 callback functions

    /**
     * @notice Callback function required by the UniswapV3 pool for minting a position
     *  @dev this is where the payer transfers required token0 and token1 amounts
     *  @param amount0 required amount of token0
     *  @param amount1 required amount of token1
     *  @param data encoded payer's address
     */
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external override {
        if (msg.sender != address(pool)) {
            revert UniswapV3TokenizedLp_MustBePool(1);
        }
        address payer = abi.decode(data, (address));

        if (payer == address(this)) {
            if (amount0 > 0) IERC20(token0).safeTransfer(msg.sender, amount0);
            if (amount1 > 0) IERC20(token1).safeTransfer(msg.sender, amount1);
        } else {
            if (amount0 > 0) {
                IERC20(token0).safeTransferFrom(payer, msg.sender, amount0);
            }
            if (amount1 > 0) {
                IERC20(token1).safeTransferFrom(payer, msg.sender, amount1);
            }
        }
    }

    /**
     * @notice Callback function required by the UniswapV3 pool for executing a swap
     *  @dev this is where the payer transfers required token0 and token1 amounts
     *  @param amount0Delta required amount of token0
     *  @param amount1Delta required amount of token1
     *  @param data encoded payer's address
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        if (msg.sender != address(pool)) {
            revert UniswapV3TokenizedLp_MustBePool(2);
        }
        address payer = abi.decode(data, (address));

        if (amount0Delta > 0) {
            if (payer == address(this)) {
                IERC20(token0).safeTransfer(msg.sender, uint256(amount0Delta));
            } else {
                IERC20(token0).safeTransferFrom(payer, msg.sender, uint256(amount0Delta));
            }
        } else if (amount1Delta > 0) {
            if (payer == address(this)) {
                IERC20(token1).safeTransfer(msg.sender, uint256(amount1Delta));
            } else {
                IERC20(token1).safeTransferFrom(payer, msg.sender, uint256(amount1Delta));
            }
        }
    }
}
