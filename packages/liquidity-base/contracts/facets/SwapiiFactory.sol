// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '../interfaces/ISwapiiFactory.sol';

import './SwapiiPoolDeployer.sol';
import './PreventDelegateCall.sol';

import './SwapiiPool.sol'; 

/// @title Swapii factory 
/// @notice This contract deploys Swapii pools and manages holdership and control over pool protocol fees
contract SwapiiFactory is ISwapiiFactory, SwapiiPoolDeployer, PreventDelegateCall {

    // address public override holder; 

    // /// @inheritdoc ISwapiiFactory
    // mapping(uint24 => int24) public override feeAmountMarkSpacing;
    // /// @inheritdoc ISwapiiFactory
    // mapping(address => mapping(address => mapping(uint24 => address))) public override obtainPool;

    // constructor() {
    //     holder = msg.sender;
    //     emit HolderChanged(address(0), msg.sender);
    //     feeAmountMarkSpacing[500] = 10;
    //     emit FeeAmountEnabled(500, 10);
    //     feeAmountMarkSpacing[3000] = 60;
    //     emit FeeAmountEnabled(3000, 60);
    //     feeAmountMarkSpacing[10000] = 200;
    //     emit FeeAmountEnabled(10000, 200);
    // }

    /// @inheritdoc ISwapiiFactory
    function makePool(
        address token1,
        address token2,
        uint24 fee
    ) external override preventDelegateCall returns (address pool) {
        require(token1 != token2);
        (address tokenA, address tokenB) = token1 < token2 ? (token1, token2) : (token2, token1);
        require(tokenA != address(0));
        int24 markSpacing = s.feeAmountMarkSpacing[fee];
        require(markSpacing != 0);
        require(s.obtainPool[tokenA][tokenB][fee] == address(0));
        pool = post(address(this), tokenA, tokenB, fee, markSpacing);
        s.obtainPool[tokenA][tokenB][fee] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        s.obtainPool[tokenB][tokenA][fee] = pool;
        emit PoolMade(tokenA, tokenB, fee, markSpacing, pool);
    }

    /// @inheritdoc ISwapiiFactory
    function setHolder(address _holder) external override {
        require(msg.sender == s.holder);
        emit HolderChanged(s.holder, _holder);
        s.holder = _holder;
    }

    /// @inheritdoc ISwapiiFactory
    function allowCostAmount(uint24 fee, int24 markSpacing) public override {
        require(msg.sender == s.holder);
        require(fee < 1000000);
        // the mark spacing is capped at 16384 to avoid any situation where markSpacing is so large that MarkBitmap#nextInitializedMarkWithinOneWord overflows int24 container from a valid mark 16384 marks represents a >5x price change with marks of 1 bips
        require(markSpacing > 0 && markSpacing < 16384);
        require(s.feeAmountMarkSpacing[fee] == 0);

        s.feeAmountMarkSpacing[fee] = markSpacing;
        emit FeeAmountEnabled(fee, markSpacing);
    }

}
