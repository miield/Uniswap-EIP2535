// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import "swapii/liquidity/contracts/interfaces/ISwapiiPool.sol";
import "./libraries/SafeERC20Namer.sol";

import "./libraries/ChainId.sol";
import "./interfaces/INFTSpotManager.sol";
import "./interfaces/INFTSpotDescriptor.sol";
import "./interfaces/IERC20Metadata.sol";
import "./libraries/PoolAddress.sol";
import "./libraries/NFTDescriptor.sol";
import "./libraries/TokenRatioSortOrder.sol";

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract NFTSpotDescriptor is INFTSpotDescriptor {
    // Testnet addresses
    // address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant NUSD = 	0xab151cD390C6b0eB41A4a45E1E372972C3067b1a;
    address private constant NEURO = 0xB59C984a529490fde6698702342b292840743bb8;

    address public immutable WETH9;
    /// @dev A null-terminated string
    bytes32 public immutable nativeCurrencyLabelBytes;

    constructor(address _WETH9, bytes32 _nativeCurrencyLabelBytes) {
        WETH9 = _WETH9;
        nativeCurrencyLabelBytes = _nativeCurrencyLabelBytes;
    }

    /// @notice Returns the native currency label as a string
    function nativeCurrencyLabel() public view returns (string memory) {
        uint256 len = 0;
        while (len < 32 && nativeCurrencyLabelBytes[len] != 0) {
            len++;
        }
        bytes memory b = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            b[i] = nativeCurrencyLabelBytes[i];
        }
        return string(b);
    }

    /// @inheritdoc INFTSpotDescriptor
    function tokenURI(INFTSpotManager spotManager, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        (, , address token0, address token1, uint24 fee, int24 markLower, int24 markUpper, , , , , ) =
            spotManager.spots(tokenId);

        ISwapiiPool pool =
            ISwapiiPool(
                PoolAddress.calculatePoolAddress(
                    spotManager.factory(),
                    PoolAddress.Pool({token0: token0, token1: token1, fee: fee})
                )
            );

        bool _flipRatio = flipRatio(token0, token1, ChainId.get());
        address quoteTokenAddress = !_flipRatio ? token1 : token0;
        address baseTokenAddress = !_flipRatio ? token0 : token1;
        (, int24 tick, , , , , ) = pool.slit0();

        return
            NFTDescriptor.constructTokenURI(
                NFTDescriptor.ConstructTokenURIParams({
                    tokenId: tokenId,
                    quoteTokenAddress: quoteTokenAddress,
                    baseTokenAddress: baseTokenAddress,
                    quoteTokenSymbol: quoteTokenAddress == WETH9
                        ? nativeCurrencyLabel()
                        : SafeERC20Namer.tokenSymbol(quoteTokenAddress),
                    baseTokenSymbol: baseTokenAddress == WETH9
                        ? nativeCurrencyLabel()
                        : SafeERC20Namer.tokenSymbol(baseTokenAddress),
                    quoteTokenDecimals: IERC20Metadata(quoteTokenAddress).decimals(),
                    baseTokenDecimals: IERC20Metadata(baseTokenAddress).decimals(),
                    flipRatio: _flipRatio,
                    tickLower: markLower,
                    tickUpper: markUpper,
                    tickCurrent: tick,
                    tickSpacing: pool.markSpacing(),
                    fee: fee,
                    poolAddress: address(pool)
                })
            );
    }

    function flipRatio(
        address token0,
        address token1,
        uint256 chainId
    ) public view returns (bool) {
        return tokenRatioPriority(token0, chainId) > tokenRatioPriority(token1, chainId);
    }

    function tokenRatioPriority(address token, uint256 chainId) public view returns (int256) {
        if (token == WETH9) {
            return TokenRatioSortOrder.DENOMINATOR;
        }
        //ChainId for Nahmii Testnet
        if (chainId == 5553) {
            if (token == NUSD) {
                return TokenRatioSortOrder.NUMERATOR_MOST;
            } else if (token == NEURO) {
                return TokenRatioSortOrder.NUMERATOR_MORE;
             } 
            // else if (token == DAI) {
            //     return TokenRatioSortOrder.NUMERATOR;
            // } 
            // else if (token == TBTC) {
            //     return TokenRatioSortOrder.DENOMINATOR_MORE;
            // } 
            // else if (token == WBTC) {
            //     return TokenRatioSortOrder.DENOMINATOR_MOST;
            // } 
            else {
                return 0;
            }
        }
        return 0;
    }
}
