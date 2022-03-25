// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import "swapii/liquidity/contracts/interfaces/ISwapiiCallback.sol";

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is ISwapiiCallback {
    struct AccurateInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `AccurateInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function accurateInputSingle(AccurateInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct AccurateInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `AccurateInputParams` in calldata
    /// @return amountOut The amount of the received token
    function accurateInput(AccurateInputParams calldata params) external payable returns (uint256 amountOut);

    struct AccurateOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `AccurateOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function accurateOutputSingle(AccurateOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct AccurateOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `AccurateOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function accurateOutput(AccurateOutputParams calldata params) external payable returns (uint256 amountIn);
}
