// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;

import "./BlockTimestamp.sol";

abstract contract SwapBaseValidator is BlockTimestamp {
  modifier checkDeadline(uint256 deadline) {
    require(_blockTimestamp() <= deadline, "Transaction too old");
    _;
  }
}
