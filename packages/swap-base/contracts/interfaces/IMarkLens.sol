// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Tick Lens
/// @notice Provides functions for fetching chunks of tick data for a pool
/// @dev This avoids the waterfall of fetching the tick bitmap, parsing the bitmap to know which ticks to fetch, and
/// then sending additional multicalls to fetch the tick data
interface IMarkLens {
    struct PopulatedMark {
        int24 mark;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /// @notice Get all the mark data for the populated marks from a word of the mark bitmap of a pool
    /// @param pool The address of the pool for which to fetch populated mark data
    /// @param markBitmapIndex The index of the word in the mark bitmap for which to parse the bitmap and
    /// fetch all the populated marks
    /// @return populatedMarks An array of mark data for the given word in the mark bitmap
    function getMarksInWord(address pool, int16 markBitmapIndex)
        external
        view
        returns (PopulatedMark[] memory populatedMarks);
}
