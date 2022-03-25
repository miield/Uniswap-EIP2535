// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISwapiiCallback{

    function swapiiSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;

     function swapiiMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;

    function swapiiFlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;


}