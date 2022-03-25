// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './MarkMath.sol';
import './LiquidityMath.sol';

/// @title Mark library
/// @notice this library contains functions for managing mark processes and other of the relevant calculations
library Mark {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    // detail stired for each initialized individual mark
    struct Detail {
        // the variable is the total spot liquidity that references this mark
        uint128 liquidityGross;

        // this variable is the amount of net liquidity added (subtracted) when mark is moved from left to right (right to left),
        int128 liquidityNet;

        // fee growth per unit of liquidity on the _other_ side of this mark (relative to the current mark)
        // only has relative meaning, not absolute - the value depends on when the mark is initialized
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;

        // this variable is the cumulative mark value on the other side of the mark
        int56 markCumulativeOutside;

        // the variable below is the seconds per unit of liquidity on the _other_ side of the mark which is relative to the current mark only has relative meaning, not absolute — the value depends on when the mark is initialized
        uint160 secondsPerLiquidityOutsideX128;

        // the variable seconds spent on the other side of the mark which is relative to the current mark only has relative meaning, not absolute — the value depends on when the mark is initialized
        uint32 secondsOutside;

        // is true if the mark is initialized, i.e. the value is exactly equivalent to the expression liquidityGross != 0 these 8 bits are set to prevent fresh stores when moving newly initialized marks
        bool initialized;
    }
    /// @notice this derives the max liquidity per mark from given mark spacing
    /// @dev is Executed within the pool contructor
    /// @param markSpacing: is the amount of required mark seperation, realized in multiles of "markSpacing" e.g., a markSpacing of 3 requires marks to be initialized every 3rd mark i.e,. ..., -6, -3, 0, 3, 6, ...
    /// @return the max liquidity per mark
    function markSpacingToMaxLiquidityPerMark(int24 markSpacing) internal pure returns(uint128) {
        int24 minMark = (MarkMath.MIN_MARK / markSpacing) * markSpacing;
        int24 maxMark = (MarkMath.MAX_MARK / markSpacing) * markSpacing;
        uint24 numMarks = uint24((maxMark - minMark) / markSpacing) + 1;
        return type(uint128).max / numMarks;
    }

    /// @notice Obtains fee growth data
    /// @param person: is the mapping that contains all mark information for initialized marks
    /// @param markLower: is the lower mark boundary of the position
    /// @param markUpper: is the upper mark boundary of the position
    /// @param markCurrent: is the current maxMark
    /// @param feeGrowthGlobal0X128: this is the all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128: this is the all-time global fee growth, per unit of liquidity, in thken1
    /// @return feeGrowthInside0X128 this reeturns the all-time fee growth in token0, per unit of liquidity, inside the position's mark boundaries
    /// @return feeGrowthInside1X128 this returns all-time fee growth in token1, per unit of liquidity, inside the position's mark boundaries
    function obtainFeeGrowthInside(
        mapping(int24 => Mark.Detail) storage person,
        int24 markLower,
        int24 markUpper,
        int24 markCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns(uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Detail storage lower = person[markLower];
        Detail storage upper = person[markUpper]; 

        // calculate fee growth below
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (markCurrent >= markLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        //  calculate fee growth above
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
         if (markCurrent < markUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /// @notice Latest function marks and returns true if the mark was flipped from initialized to uninitialized or vice versa
    /// @param person: is the mapping containing all mark information for initialized marks
    /// @param mark: is the mark that will be updated
    /// @param markCurrent: the current mark
    /// @param liquidityDelta: is the new amount of liquidity to be added (subtracted) when mark is moved from left to right (right to left)
    /// @param feeGrowthGlobal0X128: is the all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128: is the all-time global fee growth, per unit of liquidity, in token1
    /// @param secondsPerLiquidityCumulativeX128: the all-time seconds per max(1, liquidity) of the pool
    /// @param markCumulative: the mark * time elapsed since the pool was first initialized
    /// @param time: this is the current block timestamp cast to a uint32
    /// @param upper: is true for updating a spot's upper mark, or is false for updating a spot's lower mark
    /// @param maxLiquidity is the maximum liquidity allocation for a single mark
    /// @return flipped Whether the mark was flipped from initialized to uninitialized, or vice versa
    function latest( 
        mapping(int24 => Mark.Detail) storage person,
        int24 mark,
        int24 markCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 markCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns(bool flipped) {
        Mark.Detail storage detail = person[mark];

        uint128 liquidityGrossBefore = detail.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // by convention, we assume that all growth before a mark was initialized happened _below_ the mark
            if (mark <= markCurrent) {
                detail.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                detail.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                detail.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                detail.markCumulativeOutside = markCumulative;
                detail.secondsOutside = time;
            }
            detail.initialized = true;
        }

        detail.liquidityGross = liquidityGrossAfter;
        
        // when the lower (upper) mark is moved left to right (right to left), liquidity must be added or removed 
        detail.liquidityNet = upper
            ? int256(detail.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(detail.liquidityNet).add(liquidityDelta).toInt128();
    }

    /// @notice Remove mark data
    /// @param person: is the mapping containing all initialized mark information for initialized marks
    /// @param mark: is the mark that will be removed
    function remove(mapping(int24 => Mark.Detail) storage person, int24 mark) internal {
        delete person[mark];
    }

    /// @notice Moving to next mark as needed by price movement
    /// @param person: here is the mapping containing all mark information for initialized marks
    /// @param mark: here is the destination mark of the transition
    /// @param feeGrowthGlobal0X128: is the all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128: is the all-time global fee growth, per unit of liquidity, in token1
    /// @param secondsPerLiquidityCumulativeX128: is the current seconds per liquidity
    /// @param markCumulative: is the mark * time elapsed since the pool was first initialized
    /// @param time: is the current block.timestamp
    /// @return liquidityNet returns the amount of liquidity added (subtracted) when mark is moved from left to right (right to left)
    function move (
        mapping(int24 => Mark.Detail) storage person,
        int24 mark,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 markCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Mark.Detail storage detail = person[mark];
        detail.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - detail.feeGrowthOutside0X128;
        detail.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - detail.feeGrowthOutside1X128;
        detail.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - detail.secondsPerLiquidityOutsideX128;
        detail.markCumulativeOutside = markCumulative - detail.markCumulativeOutside;
        detail.secondsOutside = time - detail.secondsOutside;
        liquidityNet = detail.liquidityNet;
    }

}

