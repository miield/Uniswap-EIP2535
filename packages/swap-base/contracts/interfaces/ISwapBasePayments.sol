// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title SwapBase Payments
/// @notice Functions to ease deposits and withdrawals of ETH
interface ISwapBasePayments {
    /// @return Returns the address of the Swapii factory
    function factory() external view returns (address);

    /// @return Returns the address of WETH9
    function WETH9() external view returns (address);
    /// @notice Unwraps the contract's WETH9 balance and sends it to recipient as ETH.
    /// @dev The minAmount parameter prevents malicious contracts from stealing WETH9 from users.
    /// @param minAmount The minimum amount of WETH9 to unwrap
    /// @param recipient The address receiving ETH
    // function unwrapWETH9(uint256 minAmount, address recipient) external payable;

    /// @notice Refunds any ETH balance held by this contract to the `msg.sender`
    /// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
    /// that use ether for the input amount
    // function returnETH() external payable;

    /// @notice Transfers the full amount of a token held by this contract to recipient
    /// @dev The minAmount parameter prevents malicious contracts from stealing the token from users
    /// @param token The contract address of the token which will be transferred to `recipient`
    /// @param minAmount The minimum amount of token required for a transfer
    /// @param recipient The destination address of the token
    function transferAllToken(
        address token,
        uint256 minAmount,
        address recipient
    ) external payable;

    /// @notice Unwraps the contract's WETH balance and sends it to recipient as ETH, with a percentage between
    /// 0 (exclusive), and 1 (inclusive) going to feeRecipient
    /// @dev The minAmount parameter prevents malicious contracts from stealing WETH from users.

    //  There is no need to unwrapETH because Nahmii doesn't have a native ETH. Withdrawal is done via bridge
// 
    // function unwrapWETH9WithCharge(
    //     uint256 minAmount,
    //     address recipient,
    //     uint256 feeBips,
    //     address feeRecipient
    // ) external payable;

    /// @notice Transfers the full amount of a token held by this contract to recipient, with a percentage between
    /// 0 (exclusive) and 1 (inclusive) going to feeRecipient
    /// @dev The minAmount parameter prevents malicious contracts from stealing the token from users
    function transferAllTokenWithCharge(
        address token,
        uint256 minAmount,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;
}
