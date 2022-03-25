// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;

import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";
import "./PoolAddress.sol";

/// @notice Provides validation for callbacks from Swapii Pools
library CallbackValidation {
    /// @notice Returns the address of a valid Swapii Pool
    /// @param factory The contract address of the Swapii factory
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The V3 pool contract address
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (ISwapiiPool pool) {
        return verifyCallback(factory, PoolAddress.getPool(tokenA, tokenB, fee));
    }

    /// @notice Returns the address of a valid Swapii Pool
    /// @param factory The contract address of the Swapii factory
    /// @param poolKey The identifying key of the Swapii pool
    /// @return pool The Swapii pool contract address
    function verifyCallback(address factory, PoolAddress.Pool memory poolKey)
        internal
        view
        returns (ISwapiiPool pool)
    {
        pool = ISwapiiPool(PoolAddress.calculatePoolAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}
