// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";

library PoolMarksCounter {
    /// @dev This function counts the number of initialized ticks that would incur a gas cost between tickBefore and tickAfter.
    /// When tickBefore and/or tickAfter themselves are initialized, the logic over whether we should count them depends on the
    /// direction of the swap. If we are swapping upwards (tickAfter > tickBefore) we don"t want to count tickBefore but we do
    /// want to count tickAfter. The opposite is true if we are swapping downwards.
    function countInitializedMarksCrossed(
        ISwapiiPool self,
        int24 markBefore,
        int24 markAfter
    ) internal view returns (uint32 initializedMarksCrossed) {
        int16 wordPosLower;
        int16 wordPosHigher;
        uint8 bitPosLower;
        uint8 bitPosHigher;
        bool markBeforeInitialized;
        bool markAfterInitialized;

        {
            // Get the key and offset in the tick bitmap of the active tick before and after the swap.
            int16 wordPos = int16((markBefore / self.markSpacing()) >> 8);
            uint8 bitPos = uint8((markBefore / self.markSpacing()) % 256);

            int16 wordPosAfter = int16((markAfter / self.markSpacing()) >> 8);
            uint8 bitPosAfter = uint8((markAfter / self.markSpacing()) % 256);

            // In the case where markAfter is initialized, we only want to count it if we are swapping downwards.
            // If the initializable tick after the swap is initialized, our original tickAfter is a
            // multiple of tick spacing, and we are swapping downwards we know that tickAfter is initialized
            // and we shouldn"t count it.
            markAfterInitialized =
                ((self.markBitmap(wordPosAfter) & (1 << bitPosAfter)) > 0) &&
                ((markAfter % self.markSpacing()) == 0) &&
                (markBefore > markAfter);

            // In the case where markBefore is initialized, we only want to count it if we are swapping upwards.
            // Use the same logic as above to decide whether we should count markBefore or not.
            markBeforeInitialized =
                ((self.markBitmap(wordPos) & (1 << bitPos)) > 0) &&
                ((markBefore % self.markSpacing()) == 0) &&
                (markBefore < markAfter);

            if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
                wordPosLower = wordPos;
                bitPosLower = bitPos;
                wordPosHigher = wordPosAfter;
                bitPosHigher = bitPosAfter;
            } else {
                wordPosLower = wordPosAfter;
                bitPosLower = bitPosAfter;
                wordPosHigher = wordPos;
                bitPosHigher = bitPos;
            }
        }

        // Count the number of initialized marks crossed by iterating through the mark bitmap.
        // Our first mask should include the lower mark and everything to its left.
        uint256 mask = type(uint256).max << bitPosLower;
        while (wordPosLower <= wordPosHigher) {
            // If we"re on the final mark bitmap page, ensure we only count up to our
            // ending mark.
            if (wordPosLower == wordPosHigher) {
                mask = mask & (type(uint256).max >> (255 - bitPosHigher));
            }

            uint256 masked = self.markBitmap(wordPosLower) & mask;
            initializedMarksCrossed += countOneBits(masked);
            wordPosLower++;
            // Reset our mask so we consider all bits on the next iteration.
            mask = type(uint256).max;
        }

        if (markAfterInitialized) {
            initializedMarksCrossed -= 1;
        }

        if (markBeforeInitialized) {
            initializedMarksCrossed -= 1;
        }

        return initializedMarksCrossed;
    }

    function countOneBits(uint256 x) private pure returns (uint16) {
        uint16 bits = 0;
        while (x != 0) {
            bits++;
            x &= (x - 1);
        }
        return bits;
    }
}
