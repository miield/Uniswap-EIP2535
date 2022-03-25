// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct Pool {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns Pool: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Pool The pool details with ordered token0 and token1 assignments
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (Pool memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return Pool({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and Pool
    /// @param factory The Swapii factory contract address
    /// @param pool The Pool
    /// @return poolAddress The contract address of the V3 pool
    function calculatePoolAddress(address factory, Pool memory pool) internal pure returns (address poolAddress) {
        require(pool.token0 < pool.token1);
        poolAddress = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        keccak256(abi.encode(pool.token0, pool.token1, pool.fee)),
                        POOL_INIT_CODE_HASH
                    )
                )
            )
        );
    }
}
