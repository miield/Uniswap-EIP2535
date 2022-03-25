// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";

import "../interfaces/IMarkLens.sol";

/// @title Tick Lens contract
contract MarkLens is IMarkLens {
    /// @inheritdoc IMarkLens
    function getMarksInWord(address pool, int16 markBitmapIndex)
        public
        view
        override
        returns (PopulatedMark[] memory populatedMarks)
    {
        // fetch bitmap
        uint256 bitmap = ISwapiiPool(pool).markBitmap(markBitmapIndex);

        // calculate the number of populated ticks
        uint256 numberOfPopulatedMarks;
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) numberOfPopulatedMarks++;
        }

        // fetch populated tick data
        int24 markSpacing = ISwapiiPool(pool).markSpacing();
        populatedMarks = new PopulatedMark[](numberOfPopulatedMarks);
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) {
                int24 populatedMark = ((int24(markBitmapIndex) << 8) + int24(i)) * markSpacing;
                (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = ISwapiiPool(pool).marks(populatedMark);
                populatedMarks[--numberOfPopulatedMarks] = PopulatedMark({
                    mark: populatedMark,
                    liquidityNet: liquidityNet,
                    liquidityGross: liquidityGross
                });
            }
        }
    }
}
