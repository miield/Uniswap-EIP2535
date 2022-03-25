// SPDX-License-Identifier: GPL-2.0
pragma solidity >=0.5.0;

/// @title this is an interface for a contract that is used to deploy Swapii  Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which gives the initial code hash of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface ISwapiiPoolDeployer {
    /// @notice Get the variables to be used in building the pool, set transiently during pool creation.
    /// @dev the function is called by the pool constructor to fetch the parameters of the pool
    /// Returns factory: is the factory address
    /// Returns token0: is the first token of the pool by address sort order
    /// Returns token1: is the second token of the pool by address sort order
    /// Returns fee: is the fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// Returns markSpacing: is the minimum number of marks between initialized marks

//     function variables()
//         external
//         view
//         returns (
//             address factory,
//             address token0,
//             address token1,
//             uint24 fee,
//             int24 markSpacing
//         );
}
