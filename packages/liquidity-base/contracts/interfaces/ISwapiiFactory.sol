// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0; 

/// @title The interface for the Swapii Factory contract
/// @notice The Swapii Factory facilitates creation of Swapii pools and had an amount of control over the protocol fees
interface ISwapiiFactory {
    /// @notice HolderChange is emitted when the owner of the factory is changed
    /// @param oldOwner: is the owner before changing the owner
    /// @param newOwner: is the owner after changing the owner
    event HolderChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice PoolCreated is emitted when a pool is created.
    /// @param token0: this is the first token of the pool by the address sort order
    /// @param token1: is the second token of the pool by address sort order
    /// @param fee: is the fee that is collected on every swap in the pool, denomination is in hundredths of a bip
    /// @param markSpacing: is the minimum number of marks between the initialized marks
    /// @param pool: is the address of the created pool
    event PoolMade(address indexed token0, address indexed token1, uint24 indexed fee, int24 markSpacing, address pool);

    /// @notice FeeAmountEnabled: is emitted when a new fee amount is enabled for pool creation using the factory
    /// @param fee: is the enabled fee, denominated in hundredths of a bip
    /// @param markSpacing: is the minimum number of marks between initialized marks for pools created with the given fee
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed markSpacing);

    /// @notice holder: this returns the current owner of the factory and holder can be changed by the current owner via setOwner
    /// @return holder returns the address of the factory owner
    // function holder() external view returns (address);

    /// @notice feeAmountMarkSpacing: this returns the mark spacing for a given fee amount, if enabled, or 0 if not enabled
    /// @dev not that the fee amount cannot be removed, reason why the value should be hard coded or cached in the calling context
    /// @param fee: ithis is the enabled fee, denomination is in hundredths of a bip. it returns 0 in case of unenabled fee
    /// @return feeAmountMarkSpacing: returns the mark spacing
    // function feeAmountMarkSpacing(uint24 fee) external view returns (int24);

    /// @notice  ObtainPool: returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist
    /// @dev tokenA and tokenB can be passed in either token0/token1 or token1/token0 order
    /// @param tokenA: is the contract address of either token0 or token1
    /// @param tokenB: the contract address of the other token
    /// @param fee: is the fee collected oN every swap in the pool, denomination in hundredths of a bip
    /// @return pool the pool address
    // function obtainPool(
    //     address tokenA,
    //     address tokenB,
    //     uint24 fee
    // ) external view returns (address pool);

    /// @notice makePool a pool for the given two tokens (tokenA & tokenB) and the fee
    /// @param tokenA: is one of the two tokens in the desired pool
    /// @param tokenB: is the other of the two tokens in the desired pool
    /// @param fee: this is the desired fee for the pool
    /// @dev tokenA and tokenB can be passed in either order: token0/token1 or token1/token0. markSpacing is retrieved
    /// from the fee. The call will revert if the pool already exists, the fee is invalid, or the token arguments
    /// are invalid.
    /// @return pool The address of the newly created pool
    function makePool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /// @notice createOwner: updates the owner of the factory
    /// @dev the function must be called by the current owner
    /// @param _owner: is the new owner of the factory
    function setHolder(address _owner) external;

    /// @notice allowFeeAmount: this enables a fee amount with the given markSpacing
    /// @dev fee: amounts may never be removed once enabled
    /// @param fee: is the fee amount to enable, denomination is in hundredths of a bip (i.e. 1e-6)
    /// @param markSpacing: is the spacing between marks to be enforced on all pools created with the given fee amount
    function allowCostAmount(uint24 fee, int24 markSpacing) external;
}