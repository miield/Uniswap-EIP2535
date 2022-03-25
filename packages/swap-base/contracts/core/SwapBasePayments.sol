// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "swapii/liquidity/contracts/libraries/LowGasSafeMath.sol";

import "../interfaces/IWETH9.sol";
import "../interfaces/ISwapBasePayments.sol";

import "../libraries/TransferLibrary.sol";


abstract contract SwapBasePayments is ISwapBasePayments {
    using LowGasSafeMath for uint256;

    /// @inheritdoc ISwapBasePayments
    address public immutable override factory;
    /// @inheritdoc ISwapBasePayments
    address public immutable override WETH9;

    constructor(address _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }
    receive() external payable {
        require(msg.sender == WETH9, "Not WETH9");
    }

//No need to unwrap ETH
    /// @inheritdoc ISwapBasePayments
    // function unwrapWETH9(uint256 amountMinimum, address recipient) public payable override {
    //     uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
    //     require(balanceWETH9 >= amountMinimum, "Insufficient WETH9");

    //     if (balanceWETH9 > 0) {
    //         IWETH9(WETH9).withdraw(balanceWETH9);
    //         TransferLibrary._safeTransferETH(recipient, balanceWETH9);
    //     }
    // }

    /// @inheritdoc ISwapBasePayments
    function transferAllToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) public payable override {
        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, "Insufficient token");

        if (balanceToken > 0) {
            TransferLibrary._safeTransfer(token, recipient, balanceToken);
        }
    }

//No need: No ETH Support
    /// @inheritdoc ISwapBasePayments
    // function returnETH() external payable override {
    //     if (address(this).balance > 0) TransferLibrary._safeTransferETH(msg.sender, address(this).balance);
    // }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function _pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && IERC20(WETH9).balanceOf(address(this)) >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferLibrary._safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferLibrary._safeTransferFrom(token, payer, recipient, value);
        }
    }

//  There is no need to unwrapETH because Nahmii doesn't have a native ETH. Withdrawal is done via bridge
// ==========================================
    /// @inheritdoc ISwapBasePayments
    // function unwrapWETH9WithCharge(
    //     uint256 amountMinimum,
    //     address recipient,
    //     uint256 feeBips,
    //     address feeRecipient
    // ) public payable override {
    //     require(feeBips > 0 && feeBips <= 100);

    //     uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
    //     require(balanceWETH9 >= amountMinimum, "Insufficient WETH9");

    //     if (balanceWETH9 > 0) {
    //         IWETH9(WETH9).withdraw(balanceWETH9);
    //         uint256 feeAmount = balanceWETH9.mul(feeBips) / 10_000;
    //         if (feeAmount > 0) TransferLibrary.safeTransferETH(feeRecipient, feeAmount);
    //         TransferLibrary.safeTransferETH(recipient, balanceWETH9 - feeAmount);
    //     }
    // }

    /// @inheritdoc ISwapBasePayments
    function transferAllTokenWithCharge(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) public payable override {
        require(feeBips > 0 && feeBips <= 100);

        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, "Insufficient token");

        if (balanceToken > 0) {
            uint256 feeAmount = balanceToken.mul(feeBips) / 10_000;
            if (feeAmount > 0) TransferLibrary._safeTransfer(token, feeRecipient, feeAmount);
            TransferLibrary._safeTransfer(token, recipient, balanceToken - feeAmount);
        }
    }
}
