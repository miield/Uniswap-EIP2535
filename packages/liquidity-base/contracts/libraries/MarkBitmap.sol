// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import './BitMath.sol';

/// @title The Packed mark initialized state library
/// @notice This library stores a packed mapping of mark index to its initialized state
/// @dev The mapping make use of int16 for keys since marks are represented as int24 and there are 256 (2^8) values per word.
library MarkBitmap {
    /// @notice this computes the spot in the mapping where the initialized bit for a mark' lives
    /// @param mark: is the mark for which to compute the spot
    /// @return wordPos returns the key in the mapping containing the word in which the bit is stored
    /// @return bitPos returns the bit spot in the word where the flag is stored
    function spot(int24 mark) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(mark >> 8);
        bitPos = uint8(mark % 256);
    }

    /// @notice TurnOvers is the initialized state for a given mark from false to true, or vice versa
    /// @param person: is the mapping in which to turnOver the mark
    /// @param mark: is the mark to turnOver
    /// @param markSpacing is the spacing between usable marks
    function turnOverMark(
        mapping(int16 => uint256) storage person,
        int24 mark,
        int24 markSpacing
    ) internal {
        require(mark % markSpacing == 0); // ensure that the mark is spaced
        (int16 wordPos, uint8 bitPos) = spot(mark / markSpacing);
        uint256 mask = 1 << bitPos;
        person[wordPos] ^= mask;
    }

    /// @notice Returns the next initialized mark contained in the same word (or adjacent word) as the mark that is either to the left (less than or equal to) or right (greater than) of the given mark
    /// @param person: in this case is the mapping in which to compute the next initialized mark
    /// @param mark: is the starting mark
    /// @param markSpacing: is the spacing between usable marks
    /// @param lte: is used whether to search for the next initialized mark to the left (less than or equal to the starting mark)
    /// @return next returns the next initialized or uninitialized mark up to 256 marks away from the current mark
    /// @return initialized returns whether the next mark is initialized, as the function only searches within up to 256 marks
    function anotherProcessedMarkInAWord(
        mapping(int16 => uint256) storage person,
        int24 mark,
        int24 markSpacing, 
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = mark / markSpacing;
        if (mark < 0 && mark % markSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPos, uint8 bitPos) = spot(compressed);
            // all the 1s at or to the right of the current bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = person[wordPos] & mask;

            // if there are no initialized marks to the right of or at the current mark, return rightmost in the word
            initialized = masked != 0;
            // here overflow/underflow is possible, but prevented externally by limiting both markSpacing and mark
            next = initialized
                ? (compressed - int24(bitPos - BitMath.mostSignificantBit(masked))) * markSpacing
                : (compressed - int24(bitPos)) * markSpacing;
        } else {
            // the start is from the word of the next mark, since the current mark state doesn't matter
            (int16 wordPos, uint8 bitPos) = spot(compressed + 1);
            // all the 1s at or to the left of the bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = person[wordPos] & mask;

            // if there are no initialized marks to the left of the current mark, return leftmost in the word
            initialized = masked != 0;
            // here overflow/underflow is also possible, but prevented externally by limiting both markSpacing and mark
            next = initialized
                ? (compressed + 1 + int24(BitMath.leastSignificantBit(masked) - bitPos)) * markSpacing
                : (compressed + 1 + int24(type(uint8).max - bitPos)) * markSpacing;
        }
    }              
}
