// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '../interfaces/ISwapiiPoolDeployer.sol';

import './SwapiiPool.sol';

import "../libraries/LibAppStorage.sol";

// import { AppStorage } from "../libraries/LibAppStorage.sol";

contract SwapiiPoolDeployer is ISwapiiPoolDeployer {    

    AppStorage internal s;

    // struct Variables {
    //     address factory; 
    //     address token0;
    //     address token1;
    //     uint24 fee;
    //     int24 markSpacing;
    // }

    /// @inheritdoc ISwapiiPoolDeployer
    // Variables public override variables;

    /// @dev post: is a pool with the given variables by setting the variables storage slot and then removing it after deploying the pool.
    /// @param factory: is the contract address of the Swapii factory
    /// @param token0: is the first token of the pool by address sort order
    /// @param token1: is the second token of the pool by address sort order
    /// @param fee: collected upon every swap in the pool, denomination is in hundredths of a bip
    /// @param markSpacing: is the spacing between usable marks
    function post(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 markSpacing
    ) internal returns (address pool) {
        s.variables = Variables({factory: factory, token0: token0, token1: token1, fee: fee, markSpacing: markSpacing});
        pool = address(new SwapiiPool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete s.variables;
    }
}