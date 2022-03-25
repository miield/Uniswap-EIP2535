// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

library PositionKey {
    /// @dev Returns the key of the position in the core library
    function calculate(
        address owner,
        int24 markLower,
        int24 markUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, markLower, markUpper));
    }
}
