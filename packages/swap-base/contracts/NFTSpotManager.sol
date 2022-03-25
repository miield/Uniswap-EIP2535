// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";
import "swapii/liquidity/contracts/libraries/FixedPoint128.sol";
import "swapii/liquidity/contracts/libraries/FullMath.sol";

import "./interfaces/INFTSpotManager.sol";
import "./interfaces/INFTSpotDescriptor.sol";
import "./libraries/PositionKey.sol";
import "./libraries/PoolAddress.sol";
import "./core/LiquidityGovernor.sol";
import "./core/SwapBasePayments.sol";
import "./core/Multicall.sol";
import "./core/ERC721Permit.sol";
import "./core/SwapBaseValidator.sol";
import "./core/SelfPermit.sol";
import "./core/PoolConfigurator.sol";

/// @title NFT positions
/// @notice Wraps Swapii spots in the ERC721 non-fungible token interface
contract NFTSpotManager is
    INFTSpotManager,
    Multicall,
    ERC721Permit,
    SwapBasePayments,
    PoolConfigurator,
    LiquidityGovernor,
    SwapBaseValidator,
    SelfPermit
{
    // details about the swapii position
    struct Spot {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address spender;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 markLower;
        int24 markUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @dev IDs of pools assigned by this contract
    mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    mapping(uint80 => PoolAddress.Pool) private _poolIdToPool;

    /// @dev The token ID spot data
    mapping(uint256 => Spot) private _spots;

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    uint80 private _nextPoolId = 1;

    /// @dev The address of the token descriptor contract, which handles generating token URIs for position tokens
    address private immutable _tokenDescriptor;

    constructor(
        address _factory,
        address _WETH9,
        address _tokenDescriptor_
    ) ERC721Permit("Swapii NFT", "SWA-Spot", "1") SwapBasePayments(_factory, _WETH9) {
        _tokenDescriptor = _tokenDescriptor_;
    }

    /// @inheritdoc INFTSpotManager
    function spots(uint256 tokenId)
        external
        view
        override
        returns (
            uint96 nonce,
            address spender,
            address token0,
            address token1,
            uint24 fee,
            int24 markLower,
            int24 markUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Spot memory spot = _spots[tokenId];
        require(spot.poolId != 0, "Invalid token ID");
        PoolAddress.Pool memory pool = _poolIdToPool[spot.poolId];
        return (
            spot.nonce,
            spot.spender,
            pool.token0,
            pool.token1,
            pool.fee,
            spot.markLower,
            spot.markUpper,
            spot.liquidity,
            spot.feeGrowthInside0LastX128,
            spot.feeGrowthInside1LastX128,
            spot.tokensOwed0,
            spot.tokensOwed1
        );
    }

    /// @dev Caches a pool key
    function cachePool(address pool, PoolAddress.Pool memory poolKey) private returns (uint80 poolId) {
        poolId = _poolIds[pool];
        if (poolId == 0) {
            _poolIds[pool] = (poolId = _nextPoolId++);
            _poolIdToPool[poolId] = poolKey;
        }
    }

    /// @inheritdoc INFTSpotManager
    function mint(MintParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        ISwapiiPool pool;
        (liquidity, amount0, amount1, pool) = addLiquidity(
            AddLiquidityParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                recipient: address(this),
                markLower: params.markLower,
                markUpper: params.markUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        _mint(params.recipient, (tokenId = _nextId++));

        bytes32 positionKey = PositionKey.calculate(address(this), params.markLower, params.markUpper);
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.spots(positionKey);

        // idempotent set
        uint80 poolId =
            cachePool(
                address(pool),
                PoolAddress.Pool({token0: params.token0, token1: params.token1, fee: params.fee})
            );

        _spots[tokenId] = Spot({
            nonce: 0,
            spender: address(0),
            poolId: poolId,
            markLower: params.markLower,
            markUpper: params.markUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        emit IncrementLiquidity(tokenId, liquidity, amount0, amount1);
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unapproved or Owner");
        _;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        require(_exists(tokenId), "Token Id does not exist");
        return INFTSpotDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
    }

    // save bytecode by removing implementation of unused method
    function baseURI() public pure override returns (string memory) {}

    /// @inheritdoc INFTSpotManager
    function incrementLiquidity(IncrementLiquidityParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        Spot storage spot = _spots[params.tokenId];

        PoolAddress.Pool memory poolKey = _poolIdToPool[spot.poolId];

        ISwapiiPool pool;
        (liquidity, amount0, amount1, pool) = addLiquidity(
            AddLiquidityParams({
                token0: poolKey.token0,
                token1: poolKey.token1,
                fee: poolKey.fee,
                markLower: spot.markLower,
                markUpper: spot.markUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this)
            })
        );

        bytes32 spotKey = PositionKey.calculate(address(this), spot.markLower, spot.markUpper);

        // this is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.spots(spotKey);

        spot.tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - spot.feeGrowthInside0LastX128,
                spot.liquidity,
                FixedPoint128.Q128
            )
        );
        spot.tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - spot.feeGrowthInside1LastX128,
                spot.liquidity,
                FixedPoint128.Q128
            )
        );

        spot.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        spot.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        spot.liquidity += liquidity;

        emit IncrementLiquidity(params.tokenId, liquidity, amount0, amount1);
    }

    /// @inheritdoc INFTSpotManager
    function decrementLiquidity(DecrementLiquidityParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        checkDeadline(params.deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.liquidity > 0);
        Spot storage spot = _spots[params.tokenId];

        uint128 spotLiquidity = spot.liquidity;
        require(spotLiquidity >= params.liquidity);

        PoolAddress.Pool memory poolKey = _poolIdToPool[spot.poolId];
        ISwapiiPool pool = ISwapiiPool(PoolAddress.calculatePoolAddress(factory, poolKey));
        (amount0, amount1) = pool.burnToken(spot.markLower, spot.markUpper, params.liquidity);

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "check Price slippage");

        bytes32 positionKey = PositionKey.calculate(address(this), spot.markLower, spot.markUpper);
        // this is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.spots(positionKey);

        spot.tokensOwed0 +=
            uint128(amount0) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - spot.feeGrowthInside0LastX128,
                    spotLiquidity,
                    FixedPoint128.Q128
                )
            );
        spot.tokensOwed1 +=
            uint128(amount1) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - spot.feeGrowthInside1LastX128,
                    spotLiquidity,
                    FixedPoint128.Q128
                )
            );

        spot.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        spot.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        // subtraction is safe because we checked spotLiquidity is gte params.liquidity
        spot.liquidity = spotLiquidity - params.liquidity;

        emit DecrementLiquidity(params.tokenId, params.liquidity, amount0, amount1);
    }

    /// @inheritdoc INFTSpotManager
    function claim(ClaimParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.amount0Max > 0 || params.amount1Max > 0);
        // allow collecting to the nft spot manager address with address 0
        address recipient = params.recipient == address(0) ? address(this) : params.recipient;

        Spot storage spot = _spots[params.tokenId];

        PoolAddress.Pool memory poolKey = _poolIdToPool[spot.poolId];

        ISwapiiPool pool = ISwapiiPool(PoolAddress.calculatePoolAddress(factory, poolKey));

        (uint128 tokensOwed0, uint128 tokensOwed1) = (spot.tokensOwed0, spot.tokensOwed1);

        // trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
        if (spot.liquidity > 0) {
            pool.burnToken(spot.markLower, spot.markUpper, 0);
            (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) =
                pool.spots(PositionKey.calculate(address(this), spot.markLower, spot.markUpper));

            tokensOwed0 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - spot.feeGrowthInside0LastX128,
                    spot.liquidity,
                    FixedPoint128.Q128
                )
            );
            tokensOwed1 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - spot.feeGrowthInside1LastX128,
                    spot.liquidity,
                    FixedPoint128.Q128
                )
            );

            spot.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            spot.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }

        // calculate the arguments to give to the pool#claim method
        (uint128 amount0Claim, uint128 amount1Claim) =
            (
                params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
                params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
            );

        // the actual amounts collected are returned
        (amount0, amount1) = pool.retrieve(
            recipient,
            spot.markLower,
            spot.markUpper,
            amount0Claim,
            amount1Claim
        );

        // sometimes there will be a few less wei than expected due to rounding down in core, but we just subtract the full amount expected
        // instead of the actual amount so we can burn the token
        (spot.tokensOwed0, spot.tokensOwed1) = (tokensOwed0 - amount0Claim, tokensOwed1 - amount1Claim);

        emit Claim(params.tokenId, recipient, amount0Claim, amount1Claim);
    }

    /// @inheritdoc INFTSpotManager
    function burn(uint256 tokenId) external payable override isAuthorizedForToken(tokenId) {
        Spot storage spot = _spots[tokenId];
        require(spot.liquidity == 0 && spot.tokensOwed0 == 0 && spot.tokensOwed1 == 0, "Not cleared");
        delete _spots[tokenId];
        _burn(tokenId);
    }

    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(_spots[tokenId].nonce++);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
        require(_exists(tokenId), "ERC721: token does not exist");

        return _spots[tokenId].spender;
    }

    /// @dev Overrides _approve to use the spender in the position, which is packed with the position permit nonce
    function _approve(address to, uint256 tokenId) internal override(ERC721) {
        _spots[tokenId].spender = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    //Redundant code
    function swapiiSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
       
    }

    //Redundant code
    function swapiiFlashCallback(
        uint256 amount0Delta,
        uint256 amount1Delta,
        bytes calldata _data
    ) external override{
       
    }
}
