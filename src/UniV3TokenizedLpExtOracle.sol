// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IUniswapV3TokenizedLp} from "./interfaces/IUniswapV3TokenizedLp.sol";
import {IUniswapV3TokenizedLpFactory} from "./interfaces/IUniswapV3TokenizedLpFactory.sol";
import {IUniswapV3MintCallback} from "@uniswap-v3-core/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@uniswap-v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool, IUniswapV3PoolActions} from "@uniswap-v3-core/interfaces/IUniswapV3Pool.sol";
import {UniswapV3MathHelper} from "./libraries/UniswapV3MathHelper.sol";
import {ERC20, IERC20Metadata} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract UniV3TokenizedLpExtOracle is
    IUniswapV3TokenizedLp,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;

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

    error IUniswapV3TokenizedLp_InvalidBaseBpsRange();

    uint256 public constant PRECISION = 10 ** 18;
    uint256 public constant FULL_PERCENT = 10000;
    address public constant NULL_ADDRESS = address(0);
    uint256 public constant DEFAULT_BASE_FEE = 10 ** 17; // 10%
    uint256 public constant DEFAULT_BASE_FEE_SPLIT = 5 * 10 ** 17; // 50%

    string private _name;
    string private _symbol;

    address public immutable override pool;
    address public immutable override token0;
    address public immutable override token1;
    bool public immutable override allowToken0;
    bool public immutable override allowToken1;
    uint24 public immutable override fee;
    int24 public immutable override tickSpacing;

    int24 public override baseLower;
    int24 public override baseUpper;

    uint256 public baseBpsRangeLower;
    uint256 public baseBpsRangeUpper;

    uint256 public override deposit0Max;
    uint256 public override deposit1Max;
    uint256 public override maxTotalSupply;
    uint256 public override hysteresis;

    uint32 public twapPeriod;
    IPriceFeed public usdOracle0Ref;
    IPriceFeed public usdOracle1Ref;

    uint256 public baseFee;
    uint256 public baseFeeSplit;

    address public feeRecipient;
    address public override affiliate;

    /**
     * @notice creates an instance of UniswapV3TokenizedLp based on the pool. `allowTokenX` params control whether the UniswapV3TokenizedLp allows one-sided or two-sided liquidity provision
     * @param _pool Uniswap V3 pool for which liquidity is managed
     * @param _allowToken0 flag that indicates whether token0 is accepted during deposit
     * @param _allowToken1 flag that indicates whether token1 is accepted during deposit
     * @param _usdOracle0Ref address of token0 USD oracle
     * @param _usdOracle1Ref address of token1 USD oracle
     */
    constructor(address _pool, bool _allowToken0, bool _allowToken1, address _usdOracle0Ref, address _usdOracle1Ref)
        ERC20("", "")
        Ownable(msg.sender)
    {
        if (_pool == NULL_ADDRESS) revert IUniswapV3TokenizedLp_ZeroAddress();
        if (!_allowToken0 && !_allowToken1) {
            revert IUniswapV3TokenizedLp_NoAllowedTokens();
        }

        pool = _pool;
        token0 = IUniswapV3Pool(_pool).token0();
        token1 = IUniswapV3Pool(_pool).token1();
        string memory token0Symbol = ERC20(token0).symbol();
        string memory token1Symbol = ERC20(token1).symbol();
        _name = string(abi.encodePacked("UniV3 Lp Token: ", token0Symbol, "-", token1Symbol));
        _symbol = string(abi.encodePacked("uV3Lp-", token0Symbol, "-", token1Symbol));

        fee = IUniswapV3Pool(_pool).fee();
        allowToken0 = _allowToken0;
        allowToken1 = _allowToken1;
        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();

        maxTotalSupply = 0; // no cap
        hysteresis = (100 * PRECISION) / FULL_PERCENT; // default 1% threshold
        baseBpsRangeLower = baseBpsRangeUpper = 1250; // default 12.5% range around the current price for base position
        deposit0Max = type(uint256).max; // max uint256
        deposit1Max = type(uint256).max; // max uint256
        feeRecipient = msg.sender;
        affiliate = NULL_ADDRESS; // by default there is no affiliate address
        baseFee = DEFAULT_BASE_FEE;
        baseFeeSplit = DEFAULT_BASE_FEE_SPLIT;
        usdOracle0Ref = IPriceFeed(_usdOracle0Ref);
        usdOracle1Ref = IPriceFeed(_usdOracle1Ref);
        emit DeployUniV3TokenizedLp(
            msg.sender, _pool, _allowToken0, _allowToken1, msg.sender, _usdOracle0Ref, _usdOracle1Ref
        );
    }

    /**
     * @notice Sets the usdOracle0Ref and usdOracle1Ref addresses
     * @param usdOracle0Ref_ address of token0 USD oracle
     * @param usdOracle1Ref_ address of token1 USD oracle
     */
    function setUsdOracles(address usdOracle0Ref_, address usdOracle1Ref_) external onlyOwner {
        if (usdOracle0Ref_ == NULL_ADDRESS || usdOracle1Ref_ == NULL_ADDRESS) {
            revert IUniswapV3TokenizedLp_ZeroAddress();
        }
        usdOracle0Ref = IPriceFeed(usdOracle0Ref_);
        usdOracle1Ref = IPriceFeed(usdOracle1Ref_);
        emit UsdOracleReferences(msg.sender, usdOracle0Ref_, usdOracle1Ref_);
    }

    function setBaseBpsRanges(uint256 baseBpsRangeLower_, uint256 baseBpsRangeUpper_) external onlyOwner {
        if (
            baseBpsRangeLower_ > FULL_PERCENT || baseBpsRangeUpper_ > FULL_PERCENT || baseBpsRangeLower_ == 0
                || baseBpsRangeUpper_ == 0
        ) {
            revert IUniswapV3TokenizedLp_InvalidBaseBpsRange();
        }
        baseBpsRangeLower = baseBpsRangeLower_;
        baseBpsRangeUpper = baseBpsRangeUpper_;
    }

    /**
     * @notice Sets the fee recipient account address, where portion of the collected swap fees will be distributed
     * @dev onlyOwner
     * @param _feeRecipient The fee recipient account address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) {
            revert IUniswapV3TokenizedLp_ZeroAddress();
        }
        feeRecipient = _feeRecipient;
        emit FeeRecipient(msg.sender, _feeRecipient);
    }

    /**
     * @notice Sets the fee percentage to be taken from the accumulated pool's swap fees. This percentage is then distributed between the feeRecipient and affiliate accounts
     * @dev onlyOwner
     * @param _baseFee The fee percentage to be taken from the accumulated pool's swap fee
     */
    function setBaseFee(uint256 _baseFee) external onlyOwner {
        if (_baseFee > PRECISION) {
            revert IUniswapV3TokenizedLp_FeeMustBeLtePrecision();
        }
        baseFee = _baseFee;
        emit BaseFee(msg.sender, _baseFee);
    }

    /**
     * @notice Sets the fee split ratio between feeRecipient and affiliate accounts. The ratio is set as (baseFeeSplit)/(100 - baseFeeSplit), that is if we want 20/80 ratio (with feeRecipient getting 20%), baseFeeSplit should be set to 20
     * @dev onlyOwner
     * @param _baseFeeSplit The fee split ratio between feeRecipient and affiliate accounts
     */
    function setBaseFeeSplit(uint256 _baseFeeSplit) external onlyOwner {
        if (_baseFeeSplit > PRECISION) {
            revert IUniswapV3TokenizedLp_SplitMustBeLtePrecision();
        }
        baseFeeSplit = _baseFeeSplit;
        emit BaseFeeSplit(msg.sender, _baseFeeSplit);
    }

    /**
     * @notice Sets the maximum liquidity token supply the contract allows
     * @dev onlyOwner
     * @param _maxTotalSupply The maximum liquidity token supply the contract allows
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupply(msg.sender, _maxTotalSupply);
    }

    /**
     * @notice Sets the hysteresis threshold (in percentage points, 10**16 = 1%). When difference between spot price and TWAP exceeds the threshold, a check for a flashloan attack is executed
     * @dev onlyOwner
     * @param _hysteresis hysteresis threshold
     */
    function setHysteresis(uint256 _hysteresis) external onlyOwner {
        hysteresis = _hysteresis;
        emit Hysteresis(msg.sender, _hysteresis);
    }

    /**
     * @notice Sets the affiliate account address where portion of the collected swap fees will be distributed
     * @dev onlyOwner
     * @param _affiliate The affiliate account address
     */
    function setAffiliate(address _affiliate) external override onlyOwner {
        affiliate = _affiliate;
        emit Affiliate(msg.sender, _affiliate);
    }

    /**
     * @notice Sets the maximum token0 and token1 amounts the contract allows in a deposit
     * @dev onlyOwner
     * @param _deposit0Max The maximum amount of token0 allowed in a deposit
     * @param _deposit1Max The maximum amount of token1 allowed in a deposit
     */
    function setDepositMax(uint256 _deposit0Max, uint256 _deposit1Max) external override onlyOwner {
        deposit0Max = _deposit0Max;
        deposit1Max = _deposit1Max;
        emit DepositMax(msg.sender, _deposit0Max, _deposit1Max);
    }

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
     * @notice Distributes shares to depositor equal to the token1 value of his deposit multiplied by the ratio of total lp shares issued divided by the pool's AUM measured in token1 value.
     * @param deposit0 Amount of token0 transferred from sender to UniswapV3TokenizedLp
     * @param deposit1 Amount of token1 transferred from sender to UniswapV3TokenizedLp
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
            revert IUniswapV3TokenizedLp_Token0NotAllowed();
        }
        if (!allowToken1 && deposit1 > 0) {
            revert IUniswapV3TokenizedLp_Token1NotAllowed();
        }
        if (deposit0 == 0 && deposit1 == 0) {
            revert IUniswapV3TokenizedLp_ZeroValue();
        }
        if (deposit0 > deposit0Max || deposit1 > deposit1Max) {
            revert IUniswapV3TokenizedLp_MoreThanMaxDeposit();
        }
        if (to == NULL_ADDRESS) revert IUniswapV3TokenizedLp_ZeroAddress();

        // update fees for inclusion in total pool amounts
        (uint128 baseLiquidity,,) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            (uint256 burn0, uint256 burn1) = IUniswapV3Pool(pool).burn(baseLower, baseUpper, 0);
            if (burn0 != 0 || burn1 != 0) {
                revert IUniswapV3TokenizedLp_UnexpectedBurn(264);
            }
        }

        // Spot price of token1/token0
        uint256 price = fetchSpot(token0, token1, currentTick(), PRECISION);

        // External Oracle price of token1/token0
        uint256 oraclePrice = fetchOracle(token0, token1, PRECISION);

        // If difference between spot and oracle is too big, check if the price may have been manipulated in this block
        uint256 delta = (price > oraclePrice)
            ? ((price - oraclePrice) * PRECISION) / price
            : ((oraclePrice - price) * PRECISION) / oraclePrice;
        if (delta > hysteresis) require(_checkHysteresis(), "try later");

        (uint256 pool0, uint256 pool1) = getTotalAmounts();

        // aggregated deposit
        uint256 deposit0PricedInToken1 = (deposit0 * ((price < oraclePrice) ? price : oraclePrice)) / PRECISION;

        if (deposit0 > 0) {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), deposit0);
        }
        if (deposit1 > 0) {
            IERC20(token1).safeTransferFrom(msg.sender, address(this), deposit1);
        }

        shares = deposit1 + deposit0PricedInToken1;

        if (totalSupply() != 0) {
            uint256 pool0PricedInToken1 = (pool0 * ((price > oraclePrice) ? price : oraclePrice)) / PRECISION;
            shares = (shares * totalSupply()) / (pool0PricedInToken1 + pool1);
        }
        _mint(to, shares);
        emit Deposit(msg.sender, to, shares, deposit0, deposit1);
        // Check total supply cap not exceeded. A value of 0 means no limit.
        if (maxTotalSupply != 0 && totalSupply() > maxTotalSupply) {
            revert IUniswapV3TokenizedLp_MaxTotalSupplyExceeded();
        }
    }

    /**
     * @notice Redeems shares by sending out a percentage of the UniswapV3TokenizedLp's AUM - this percentage is equal to the percentage of total issued shares represented by the redeemed shares.
     *  @param shares Number of liquidity tokens to redeem as pool assets
     *  @param to Address to which redeemed pool assets are sent
     *  @param amount0 Amount of token0 redeemed by the submitted liquidity tokens
     *  @param amount1 Amount of token1 redeemed by the submitted liquidity tokens
     */
    function withdraw(uint256 shares, address to)
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0) revert IUniswapV3TokenizedLp_ZeroValue();
        if (to == NULL_ADDRESS) revert IUniswapV3TokenizedLp_ZeroAddress();

        // Withdraw liquidity from Uniswap pool
        (uint256 base0, uint256 base1) =
            _burnLiquidity(baseLower, baseUpper, _liquidityForShares(baseLower, baseUpper, shares), to, false);

        // Push tokens proportional to unused balances
        uint256 _totalSupply = totalSupply();
        uint256 unusedAmount0 = (IERC20(token0).balanceOf(address(this)) * (shares)) / _totalSupply;
        uint256 unusedAmount1 = (IERC20(token1).balanceOf(address(this)) * (shares)) / _totalSupply;
        if (unusedAmount0 > 0) IERC20(token0).safeTransfer(to, unusedAmount0);
        if (unusedAmount1 > 0) IERC20(token1).safeTransfer(to, unusedAmount1);

        amount0 = base0 + unusedAmount0;
        amount1 = base1 + unusedAmount1;

        _burn(msg.sender, shares);

        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /**
     * TODO WIP
     */
    function autoRebalance() public nonReentrant {
        // update fees
        (uint128 baseLiquidity,,) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            IUniswapV3Pool(pool).burn(baseLower, baseUpper, 0);
        }

        // Withdraw all liquidity and collect all fees from Uniswap pool
        (, uint256 feesBase0, uint256 feesBase1) = _position(baseLower, baseUpper);

        _burnLiquidity(baseLower, baseUpper, baseLiquidity, address(this), true);
        _distributeFees(feesBase0, feesBase1);

        uint256 token0Bal = IERC20(token0).balanceOf(address(this));
        uint256 token1Bal = IERC20(token1).balanceOf(address(this));

        emit Rebalance(currentTick(), token0Bal, token1Bal, feesBase0, feesBase1, totalSupply());

        // Get spot and external oracle prices
        uint256 price = fetchSpot(token0, token1, currentTick(), PRECISION);
        uint256 oraclePrice = fetchOracle(token0, token1, PRECISION);

        // if difference between spot and oraclePrice is too big, check if the price may have been manipulated in this block
        uint256 delta = (price > oraclePrice)
            ? ((price - oraclePrice) * PRECISION) / oraclePrice
            : ((oraclePrice - price) * PRECISION) / oraclePrice;

        if (delta > hysteresis) {
            baseLower = UniswapV3MathHelper.getTickAtSqrtRatio(
                _encodePriceSqrtX96(PRECISION, ((oraclePrice * (FULL_PERCENT - baseBpsRangeLower)) / FULL_PERCENT))
            );
            baseUpper = UniswapV3MathHelper.getTickAtSqrtRatio(
                _encodePriceSqrtX96(PRECISION, ((oraclePrice * (FULL_PERCENT + baseBpsRangeUpper)) / FULL_PERCENT))
            );
            uint128 liquidity = _liquidityForAmounts(baseLower, baseUpper, token0Bal, token1Bal);
            _mintLiquidity(baseLower, baseUpper, liquidity);
        } else {
            baseLiquidity = _liquidityForAmounts(baseLower, baseUpper, token0Bal, token1Bal);
            _mintLiquidity(baseLower, baseUpper, baseLiquidity);
        }
    }

    /**
     * @notice Updates UniswapV3TokenizedLp's LP positions.
     *  @dev The base position is placed first with as much liquidity as possible and is typically symmetric around the current price. This order should use up all of one token, leaving some unused quantity of the other. This unused amount is then placed as a single-sided order.
     *  @param _baseLower The lower tick of the base position
     *  @param _baseUpper The upper tick of the base position
     *  @param swapQuantity Quantity of tokens to swap; if quantity is positive, `swapQuantity` token0 are swapped for token1, if negative, `swapQuantity` token1 is swapped for token0
     */
    function rebalance(int24 _baseLower, int24 _baseUpper, int256 swapQuantity) public nonReentrant onlyOwner {
        if (_baseLower >= _baseUpper || _baseLower % tickSpacing != 0 || _baseUpper % tickSpacing != 0) {
            revert IUniswapV3TokenizedLp_BasePositionInvalid();
        }

        // update fees
        (uint128 baseLiquidity,,) = _position(baseLower, baseUpper);
        if (baseLiquidity > 0) {
            IUniswapV3Pool(pool).burn(baseLower, baseUpper, 0);
        }

        // Withdraw all liquidity and collect all fees from Uniswap pool
        (, uint256 feesBase0, uint256 feesBase1) = _position(baseLower, baseUpper);

        _burnLiquidity(baseLower, baseUpper, baseLiquidity, address(this), true);
        _distributeFees(feesBase0, feesBase1);

        uint256 token0Bal = IERC20(token0).balanceOf(address(this));
        uint256 token1Bal = IERC20(token1).balanceOf(address(this));

        emit Rebalance(currentTick(), token0Bal, token1Bal, feesBase0, feesBase1, totalSupply());

        // swap tokens if required
        if (swapQuantity != 0) {
            IUniswapV3Pool(pool).swap(
                address(this),
                swapQuantity > 0,
                swapQuantity > 0 ? swapQuantity : -swapQuantity,
                swapQuantity > 0 ? UniswapV3MathHelper.MIN_SQRT_RATIO + 1 : UniswapV3MathHelper.MAX_SQRT_RATIO - 1,
                abi.encode(address(this))
            );
        }

        baseLower = _baseLower;
        baseUpper = _baseUpper;
        baseLiquidity = _liquidityForAmounts(baseLower, baseUpper, token0Bal, token1Bal);
        _mintLiquidity(baseLower, baseUpper, baseLiquidity);
    }

    /**
     * @notice Sends portion of swap fees to feeRecipient and affiliate.
     *  @param fees0 fees for token0
     *  @param fees1 fees for token1
     */
    function _distributeFees(uint256 fees0, uint256 fees1) internal {
        // if there is no affiliate 100% of the baseFee should go to feeRecipient
        uint256 baseFeeSplit_ = (affiliate == NULL_ADDRESS) ? PRECISION : baseFeeSplit;

        if (baseFee > PRECISION) {
            revert IUniswapV3TokenizedLp_FeeMustBeLtePrecision();
        }
        if (baseFeeSplit_ > PRECISION) {
            revert IUniswapV3TokenizedLp_SplitMustBeLtePrecision();
        }
        if (feeRecipient == NULL_ADDRESS) {
            revert IUniswapV3TokenizedLp_ZeroAddress();
        }

        if (baseFee > 0) {
            if (fees0 > 0) {
                uint256 totalFee = (fees0 * baseFee) / PRECISION;
                uint256 toRecipient = (totalFee * baseFeeSplit_) / PRECISION;
                uint256 toAffiliate = totalFee - toRecipient;
                IERC20(token0).safeTransfer(feeRecipient, toRecipient);
                if (toAffiliate > 0) {
                    IERC20(token0).safeTransfer(affiliate, toAffiliate);
                }
            }
            if (fees1 > 0) {
                uint256 totalFee = (fees1 * baseFee) / PRECISION;
                uint256 toRecipient = (totalFee * baseFeeSplit_) / PRECISION;
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
     *  @param to The account to receive token0 and token1 amounts
     *  @param collectAll Flag that indicates whether all token0 and token1 tokens should be collected or only the ones released during this burn
     *  @param amount0 released amount of token0
     *  @param amount1 released amount of token1
     */
    function _burnLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, address to, bool collectAll)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity > 0) {
            // Burn liquidity
            (uint256 owed0, uint256 owed1) = IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);

            // Collect amount owed
            uint128 collect0 = collectAll ? type(uint128).max : _uint128Safe(owed0);
            uint128 collect1 = collectAll ? type(uint128).max : _uint128Safe(owed1);
            if (collect0 > 0 || collect1 > 0) {
                (amount0, amount1) = IUniswapV3Pool(pool).collect(to, tickLower, tickUpper, collect0, collect1);
            }
        }
    }

    /**
     * @notice Calculates liquidity amount for the given shares.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param shares number of shares
     */
    function _liquidityForShares(int24 tickLower, int24 tickUpper, uint256 shares) internal view returns (uint128) {
        (uint128 position,,) = _position(tickLower, tickUpper);
        return _uint128Safe((uint256(position) * shares) / totalSupply());
    }

    /**
     * @notice Returns information about the liquidity position.
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity liquidity amount
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
     * @notice Callback function for mint
     *  @dev this is where the payer transfers required token0 and token1 amounts
     *  @param amount0 required amount of token0
     *  @param amount1 required amount of token1
     *  @param data encoded payer's address
     */
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external override {
        if (msg.sender != address(pool)) {
            revert IUniswapV3TokenizedLp_MustBePool(523);
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
     * @notice Callback function for swap
     *  @dev this is where the payer transfers required token0 and token1 amounts
     *  @param amount0Delta required amount of token0
     *  @param amount1Delta required amount of token1
     *  @param data encoded payer's address
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        if (msg.sender != address(pool)) {
            revert IUniswapV3TokenizedLp_MustBePool(550);
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

    /**
     * @notice Checks if the last price change happened in the current block
     */
    function _checkHysteresis() private view returns (bool) {
        (,, uint16 observationIndex,,,,) = IUniswapV3Pool(pool).slot0();
        (uint32 blockTimestamp,,,) = IUniswapV3Pool(pool).observations(observationIndex);
        return (block.timestamp != blockTimestamp);
    }

    /**
     * @notice Calculates token0 and token1 amounts for liquidity in a position
     *  @param tickLower The lower tick of the liquidity position
     *  @param tickUpper The upper tick of the liquidity position
     *  @param liquidity Amount of liquidity in the position
     */
    function _amountsForLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        view
        returns (uint256, uint256)
    {
        (uint160 sqrtRatioX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        return UniswapV3MathHelper.getAmountsForLiquidity(
            sqrtRatioX96,
            UniswapV3MathHelper.getSqrtRatioAtTick(tickLower),
            UniswapV3MathHelper.getSqrtRatioAtTick(tickUpper),
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
        (uint160 sqrtRatioX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        return UniswapV3MathHelper.getLiquidityForAmounts(
            sqrtRatioX96,
            UniswapV3MathHelper.getSqrtRatioAtTick(tickLower),
            UniswapV3MathHelper.getSqrtRatioAtTick(tickUpper),
            amount0,
            amount1
        );
    }

    /**
     * @notice Calculates total quantity of token0 and token1 in both positions (and unused in the UniswapV3TokenizedLp)
     *  @param total0 Quantity of token0 in both positions (and unused in the UniswapV3TokenizedLp)
     *  @param total1 Quantity of token1 in both positions (and unused in the UniswapV3TokenizedLp)
     */
    function getTotalAmounts() public view override returns (uint256 total0, uint256 total1) {
        (, uint256 base0, uint256 base1) = getBasePosition();
        total0 = IERC20(token0).balanceOf(address(this)) + base0;
        total1 = IERC20(token1).balanceOf(address(this)) + base1;
    }

    /**
     * @notice Calculates amount of total liquidity in the base position
     *  @param liquidity Amount of total liquidity in the base position
     *  @param amount0 Estimated amount of token0 that could be collected by burning the base position
     *  @param amount1 Estimated amount of token1 that could be collected by burning the base position
     */
    function getBasePosition() public view returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        (uint128 positionLiquidity, uint128 tokensOwed0, uint128 tokensOwed1) = _position(baseLower, baseUpper);
        (amount0, amount1) = _amountsForLiquidity(baseLower, baseUpper, positionLiquidity);
        liquidity = positionLiquidity;
        amount0 = amount0 + uint256(tokensOwed0);
        amount1 = amount1 + uint256(tokensOwed1);
    }

    /**
     * @notice Returns current price tick
     *  @param tick Uniswap pool's current price tick
     */
    function currentTick() public view returns (int24 tick) {
        (, int24 tick_,,,,, bool unlocked_) = IUniswapV3Pool(pool).slot0();
        if (!unlocked_) revert IUniswapV3TokenizedLp_PoolLocked();
        tick = tick_;
    }

    /**
     * @notice returns equivalent _tokenOut for _amountIn, _tokenIn using spot pool price
     *  @param _tokenIn token the input amount is in
     *  @param _tokenOut token for the output amount
     *  @param _tick tick for the spot price
     *  @param _amountIn amount in _tokenIn
     *  @param amountOut equivalent amount in _tokenOut
     */
    function fetchSpot(address _tokenIn, address _tokenOut, int24 _tick, uint256 _amountIn)
        public
        pure
        returns (uint256 amountOut)
    {
        return UniswapV3MathHelper.getQuoteAtTick(_tick, _uint128Safe(_amountIn), _tokenIn, _tokenOut);
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
        uint256 valueIn = tokenIn_ == token0
            ? _getUsdValue(tokenIn_, amountIn_, usdOracle0Ref)
            : _getUsdValue(tokenIn_, amountIn_, usdOracle1Ref);

        amountOut = tokenOut_ == token0
            ? _getTokenFromUsdValue(tokenOut_, usdOracle0Ref, valueIn)
            : _getTokenFromUsdValue(tokenOut_, usdOracle1Ref, valueIn);
    }

    function _getUsdValue(address token_, uint256 amount_, IPriceFeed usdOracle_) internal view returns (uint256) {
        return (uint256(usdOracle_.latestAnswer()) * amount_) / (10 ** uint256(ERC20(token_).decimals()));
    }

    function _getTokenFromUsdValue(address token_, IPriceFeed usdOracle_, uint256 value_)
        internal
        view
        returns (uint256)
    {
        return (value_ * 10 ** ERC20(token_).decimals()) / uint256(usdOracle_.latestAnswer());
    }

    function _encodePriceSqrtX96(uint256 reserve0, uint256 reserve1) internal pure returns (uint160) {
        return _uint160Safe((Math.sqrt(reserve1 / reserve0)) * 2 ** 96);
    }

    /**
     * @notice uint128Safe function
     *  @param x input value
     */
    function _uint128Safe(uint256 x) internal pure returns (uint128) {
        if (x > type(uint128).max) revert IUniswapV3TokenizedLp_UnsafeCast();
        return uint128(x);
    }

    /**
     * @notice uint160Safe function
     *  @param x input value
     */
    function _uint160Safe(uint256 x) internal pure returns (uint160) {
        if (x > type(uint160).max) revert IUniswapV3TokenizedLp_UnsafeCast();
        return uint160(x);
    }
}
