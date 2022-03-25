// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// @title Spot: library name
/// @notice Spot: this represent an owner address'that is the liquidity between a lower and upper mark boundary
/// @dev Spots: it stores additional state for tracking fees that is owed to the spot
library Spot {
    // the detail here is stored for each user's spot
    struct Detail {
        // the is the amount of liquidity owned by this spot
        uint128 liquidity;
        // fee growth per unit of liquidity as at the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the spot owner in token0/token1
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice the obtain function returns the Details struct of a spot, given an owner and spot boundaries
    /// @param person: is the mapping containing all the user spots
    /// @param owner: this is the address of the owner of the spot
    /// @param markLower: is the lower mark boundary of the spot
    /// @param markUpper: is the upper mark boundary of the spot
    /// @return spot is the spot detail struct of the given owners' spot
    function obtain(
        mapping(bytes32 => Detail) storage person,
        address owner,
        int24 markLower,
        int24 markUpper 
    ) internal view returns(Spot.Detail storage spot) {
        spot = person[keccak256(abi.encodePacked(owner, markLower, markUpper))];
    }

    /// @notice Credits accumulated fees to a user's spot
    /// @param person: is the individual spot to latest
    /// @param liquidityDelta: is the change in pool liquidity as a result of thr spot latest
    /// @param feeGrowthInside0X128: this is the all-time fee growth in token0, per unit of liquidity, inside the spot's mark boundaries
    /// @param feeGrowthInside1X128: this is the all-time fee growth in token1, per uint of liquidity, inside the spot's mark boundaries
    function latest(
        Detail storage person,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128 
    ) internal {
        Detail memory _person = person;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_person.liquidity > 0, 'NP'); // does not allow pokes for 0 liquidity spots
            liquidityNext = _person.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_person.liquidity, liquidityDelta);
        }

        // this is used to calculate the accumulated fees 
        uint128 tokensOwed0 = 
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _person.feeGrowthInside0LastX128,
                    _person.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 = 
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _person.feeGrowthInside1LastX128,
                    _person.liquidity,
                    FixedPoint128.Q128
                )
            );

        // update the spot
        if (liquidityDelta != 0) person.liquidity = liquidityNext;
        person.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        person.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // here, the overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            person.tokensOwed0 += tokensOwed0;
            person.tokensOwed1 += tokensOwed1;
        }
    }
}