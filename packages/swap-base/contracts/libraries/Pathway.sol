// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "./BytesLib.sol";

/// @title Functions for manipulating path data for multihop swaps
library Pathway {
    using BytesLib for bytes;

    /// @dev The length of the bytes encoded address
    uint256 private constant ADDRESS_LENGTH = 20;
    /// @dev The length of the bytes encoded fee
    uint256 private constant FEE_LENGTH = 3;

    /// @dev The offset of a single token address and pool fee
    uint256 private constant NEXT_OFFSET = ADDRESS_LENGTH + FEE_LENGTH;
    /// @dev The offset of an encoded pool key
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDRESS_LENGTH;
    /// @dev The minimum length of an encoding that contains 2 or more pools
    uint256 private constant MIN_POOLS_LENGTH = POP_OFFSET + NEXT_OFFSET;

    /// @notice Returns true if the pathway contains two or more pools
    /// @param pathway The encoded swap pathway
    /// @return True if pathway contains two or more pools, otherwise false
    function hasPools(bytes memory pathway) internal pure returns (bool) {
        return pathway.length >= MIN_POOLS_LENGTH;
    }

    /// @notice Returns the number of pools in the path
    /// @param pathway The encoded swap pathway
    /// @return The number of pools in the pathway
    function numberOfPools(bytes memory pathway) internal pure returns (uint256) {
        // Ignore the first token address. From then on every fee and token offset indicates a pool.
        return ((pathway.length - ADDRESS_LENGTH) / NEXT_OFFSET);
    }

    /// @notice Decodes the first pool in path
    /// @param pathway The bytes encoded swap path
    /// @return token0 The first token of the given pool
    /// @return token1 The second token of the given pool
    /// @return fee The fee level of the pool
    function decodeFirstPool(bytes memory pathway)
        internal
        pure
        returns (
            address token0,
            address token1,
            uint24 fee
        )
    {
        token0 = pathway.toAddress(0);
        fee = pathway.toUint24(ADDRESS_LENGTH);
        token1 = pathway.toAddress(NEXT_OFFSET);
    }

    /// @notice Gets the segment corresponding to the first pool in the pathway
    /// @param pathway The bytes encoded swap pathway
    /// @return The segment containing all data necessary to target the first pool in the pathway
    function getFirstPool(bytes memory pathway) internal pure returns (bytes memory) {
        return pathway.slice(0, POP_OFFSET);
    }

    /// @notice Skips a token + fee element from the buffer and returns the remainder
    /// @param pathway The swap pathway
    /// @return The remaining token + fee elements in the pathway
    function skipToken(bytes memory pathway) internal pure returns (bytes memory) {
        return pathway.slice(NEXT_OFFSET, pathway.length - NEXT_OFFSET);
    }
}
