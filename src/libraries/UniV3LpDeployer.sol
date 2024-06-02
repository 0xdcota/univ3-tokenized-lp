// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {UniswapV3TokenizedLp} from "../UniswapV3TokenizedLp.sol";
import {IUniswapV3Factory} from "@uniswap-v3-core/interfaces/IUniswapV3Factory.sol";

library UniV3LpDeployer {
    function createUniswapV3TokenizedLp(
        address pool,
        address token0,
        bool allowToken0,
        address token1,
        bool allowToken1,
        uint24 fee,
        int24 tickSpacing,
        uint32 twapPeriod
    ) public returns (address uniswapV3TokenizedLp) {
        uniswapV3TokenizedLp = address(
            new UniswapV3TokenizedLp{
                salt: keccak256(abi.encodePacked(msg.sender, token0, allowToken0, token1, allowToken1, fee, tickSpacing))
            }(pool, allowToken0, allowToken1, msg.sender, twapPeriod)
        );
    }
}
