// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "swapii/liquidity/contracts/interfaces/ISwapiiFactory.sol";
import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";

import "./SwapBasePayments.sol";
import "../interfaces/IPoolConfigurator.sol";

/// @title Creates and initializes Swapii Pools
abstract contract PoolConfigurator is IPoolConfigurator, SwapBasePayments {
    
    function makeAndConfigurePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);
        pool = ISwapiiFactory(factory).obtainPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = ISwapiiFactory(factory).makePool(token0, token1, fee);
            ISwapiiPool(pool).configure(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , , ) = ISwapiiPool(pool).slit0();
            if (sqrtPriceX96Existing == 0) {
                ISwapiiPool(pool).configure(sqrtPriceX96);
            }
        }
    }
}
