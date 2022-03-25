// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TransferLibrary {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with `TransferLibrary: safe transfer from failed` if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferLibrary: safe transfer from failed");
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with `TransferLibrary: safe transfer failed` if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferLibrary: safe transfer failed");
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with `TransferLibrary: safe approve failed` if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function _safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferLibrary: safe approve failed");
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `TransferLibrary: safe transfer ETH failed`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred

    // Nahmii 2.0 doesn"t support native ETH

    // function _safeTransferETH(address to, uint256 value) internal {
    //     (bool success, ) = to.call{value: value}(new bytes(0));
    //     require(success, "TransferLibrary: safe transfer ETH failed");
    // }
}
