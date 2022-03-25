// // SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import './PreventDelegateCall.sol';

import '../libraries/LowGasSafeMath.sol';
import '../libraries/SafeCast.sol';
import '../libraries/Mark.sol';
import '../libraries/MarkBitmap.sol';
import '../libraries/Spot.sol';
import '../libraries/OracleLib.sol';

import '../libraries/FullMath.sol';
import '../libraries/FixedPoint128.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/MarkMath.sol';
import '../libraries/LiquidityMath.sol';
import '../libraries/SRValMath.sol';
import '../libraries/SwapArithmetic.sol';

import '../interfaces/ISwapiiPoolDeployer.sol';
import '../interfaces/ISwapiiFactory.sol';
import '../interfaces/IERC20Minimal.sol';
import '../interfaces/ISwapiiCallback.sol';

import "../libraries/LibAppStorage.sol";

// import { AppStorage } from "../libraries/LibAppStorage.sol";
contract SwapiiPool is PreventDelegateCall {

    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Mark for mapping(int24 => Mark.Detail);
    using MarkBitmap for mapping(int16 => uint256);
    using Spot for mapping(bytes32 => Spot.Detail);
    using Spot for Spot.Detail;
    using OracleLib for OracleLib.Observation[65535];

    AppStorage internal s;

    event Initialize(uint160 sqrtPriceX96, int24 mark);

// still to change a couple comments and event names
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed markLower,
        int24 indexed markUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Retrieve(
        address indexed owner,
        address recipient,
        int24 indexed markLower,
        int24 indexed markUpper,
        uint128 amount0,
        uint128 amount1
    );

    event BurnToken(
        address indexed owner,
        int24 indexed markLower,
        int24 indexed markUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

     event SwapToken(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 mark
    );

     event Surge(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    event IncreaseRecognizationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    event SetProtocolCharge(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    event RetrieveProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);


    
    // address public immutable factoryAddress;
    
    // address public immutable tokenA;
    
    // address public immutable tokenB;
    
    // uint24 public immutable charge;

    
    // int24 public immutable markSpacing;

    
    // uint128 public immutable maxLiquidityPerMark;

    // struct Slit0 {
    //     // the current price
    //     uint160 sqrtPriceX96;
    //     // the current mark
    //     int24 mark;
    //     // the most-recently updated index of the observations array
    //     uint16 observationIndex;
    //     // the current maximum number of observations that are being stored
    //     uint16 observationCardinality;
    //     // the next maximum number of observations to store, triggered in observations.write
    //     uint16 observationCardinalityNext;
    //     // the current protocol fee as a percentage of the swap fee taken on withdrawal
    //     // represented as an integer denominator (1/x)%
    //     uint8 feeProtocol;
    //     // whether the pool is locked
    //     bool unlocked;
    // }
    
    // Slit0 public slit0;

    
    // uint256 public feeGrowthGlobal0X128;
   
    // uint256 public feeGrowthGlobal1X128;

    // // accumulated protocol fees in token0/token1 units
    // struct ProtocolFees {
    //     uint128 token0;
    //     uint128 token1;
    // }
    
    // ProtocolFees public protocolFees;

    
    // uint128 public liquidity;

    
    // mapping(int24 => Mark.Detail) public marks;
    
    // mapping(int16 => uint256) public markBitmap;
    
    // mapping(bytes32 => Spot.Detail) public spots;
   
    // OracleLib.Observation[65535] public observations;

    /// @dev Mutually exclusive reentrancy protection into the pool to/from a method. This method also prevents entrance
    /// to a function before the pool is initialized. The reentrancy guard is required throughout the contract because
    /// we use balance checks to determine the payment status of interactions such as mint, swap and flash.
    modifier lock() {
        require(s.slit0.unlocked, 'LOK');
        s.slit0.unlocked = false;
        _;
        s.slit0.unlocked = true;
    }

    /// @dev Prevents calling a function from anyone except the address returned by IUniswapV3Factory#owner()
    modifier onlyFactoryOwner() {
        require(msg.sender == s.holder);
        _;
    }

    constructor() {
        int24 _markSpacing;
        (s.factoryAddress, s.tokenA, s.tokenB, s.charge, _markSpacing) = s.variables();
        s.markSpacing = _markSpacing;

        s.maxLiquidityPerMark = Mark.markSpacingToMaxLiquidityPerMark(_markSpacing);
    }

    /// @dev Common checks for valid mark inputs.
    function checkMarks(int24 markLower, int24 markUpper) private pure {
        require(markLower < markUpper, 'MLU');
        require(markLower >= MarkMath.MIN_MARK, 'MLM');
        require(markUpper <= MarkMath.MAX_MARK, 'MUM');
    }

    /// @dev Returns the block timestamp truncated to 32 bits, i.e. mod 2**32. This method is overridden in tests.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balanceA() private view returns (uint256) {
        (bool success, bytes memory data) =
            s.tokenA.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token1
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balanceB() private view returns (uint256) {
        (bool success, bytes memory data) =
            s.tokenB.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }
    
    function snapshotTotalInside(int24 markLower, int24 markUpper)
        external
        view
        preventDelegateCall
        returns (
            int56 markCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        )
    {
        checkMarks(markLower, markUpper);

        int56 markCumulativeLower;
        int56 markCumulativeUpper;
        uint160 secondsPerLiquidityOutsideLowerX128;
        uint160 secondsPerLiquidityOutsideUpperX128;
        uint32 secondsOutsideLower;
        uint32 secondsOutsideUpper;

        {
            Mark.Detail storage lower = s.marks[markLower];
            Mark.Detail storage upper = s.marks[markUpper];
            bool initializedLower;
            (markCumulativeLower, secondsPerLiquidityOutsideLowerX128, secondsOutsideLower, initializedLower) = (
                lower.markCumulativeOutside,
                lower.secondsPerLiquidityOutsideX128,
                lower.secondsOutside,
                lower.initialized
            ); 
            require(initializedLower);

            bool initializedUpper;
            (markCumulativeUpper, secondsPerLiquidityOutsideUpperX128, secondsOutsideUpper, initializedUpper) = (
                upper.markCumulativeOutside,
                upper.secondsPerLiquidityOutsideX128,
                upper.secondsOutside,
                upper.initialized
            );
            require(initializedUpper);
        }

        Slit0 memory _slot0 = s.slit0;

        if (_slot0.mark < markLower) {
            return (
                markCumulativeLower - markCumulativeUpper,
                secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
                secondsOutsideLower - secondsOutsideUpper
            );
        } else if (_slot0.mark < markUpper) {
            uint32 time = _blockTimestamp();
            (int56 markCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                s.observations.recognizeSingle(
                    time,
                    0,
                    _slot0.mark,
                    _slot0.observationIndex,
                    s.liquidity,
                    _slot0.observationCardinality
                );
            return (
                markCumulative - markCumulativeLower - markCumulativeUpper,
                secondsPerLiquidityCumulativeX128 -
                    secondsPerLiquidityOutsideLowerX128 -
                    secondsPerLiquidityOutsideUpperX128,
                time - secondsOutsideLower - secondsOutsideUpper
            );
        } else {
            return (
                markCumulativeUpper - markCumulativeLower,
                secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
                secondsOutsideUpper - secondsOutsideLower
            );
        }
    }



    
    function recognize(uint32[] calldata secondsAgos)
        external
        view
        preventDelegateCall
        returns (int56[] memory markCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        return
            s.observations.recognize(
                _blockTimestamp(),
                secondsAgos,
                s.slit0.mark,
                s.slit0.observationIndex,
                s.liquidity,
                s.slit0.observationCardinality
            );
    }

    
    function increaseRecognizationCardinalityNext(uint16 observationCardinalityNext)
        external
        lock
        preventDelegateCall
    {
        uint16 observationCardinalityNextOld = s.slit0.observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew =
            s.observations.enlarge(observationCardinalityNextOld, observationCardinalityNext);
        s.slit0.observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew)
            emit IncreaseRecognizationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    
    /// @dev not locked because it initializes unlocked
    function configure(uint160 sqrtPriceX96) external {
        require(s.slit0.sqrtPriceX96 == 0, 'AI');

        int24 mark = MarkMath.getMarkAtSqrtRatio(sqrtPriceX96);

        (uint16 cardinality, uint16 cardinalityNext) = s.observations.configure(_blockTimestamp());

        s.slit0 = Slit0({
            sqrtPriceX96: sqrtPriceX96,
            mark: mark,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });

        emit Initialize(sqrtPriceX96, mark);
    }

    struct ChangePositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper mark of the position
        int24 markLower;
        int24 markUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    /// @dev Effect some changes to a position
    /// @param params the position details and the change to the position's liquidity to effect
    /// @return position a storage pointer referencing the position with the given owner and mark range
    /// @return amount0 the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount1 the amount of token1 owed to the pool, negative if the pool should pay the recipient
    function _changePosition(ChangePositionParams memory params)
        private
        preventDelegateCall
        returns (
            Spot.Detail storage position,
            int256 amount0,
            int256 amount1
        )
    {
        checkMarks(params.markLower, params.markUpper);

        Slit0 memory _slit0 = s.slit0; // SLOAD for gas optimization

        position = _upgradePosition(
            params.owner,
            params.markLower,
            params.markUpper,
            params.liquidityDelta,
            _slit0.mark
        );

        if (params.liquidityDelta != 0) {
            if (_slit0.mark < params.markLower) {
                // current mark is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SRValMath.returnAmount0Increase(
                    MarkMath.getSqrtRatioAtMark(params.markLower),
                    MarkMath.getSqrtRatioAtMark(params.markUpper),
                    params.liquidityDelta
                );
            } else if (_slit0.mark < params.markUpper) {
                // current mark is inside the passed range
                uint128 liquidityBefore = s.liquidity; // SLOAD for gas optimization

                // write an oracle entry
                (s.slit0.observationIndex, s.slit0.observationCardinality) = s.observations.update(
                    _slit0.observationIndex,
                    _blockTimestamp(),
                    _slit0.mark,
                    liquidityBefore,
                    _slit0.observationCardinality,
                    _slit0.observationCardinalityNext
                );

                amount0 = SRValMath.returnAmount0Increase(
                    _slit0.sqrtPriceX96,
                    MarkMath.getSqrtRatioAtMark(params.markUpper),
                    params.liquidityDelta
                );
                amount1 = SRValMath.returnAmount1Increase(
                    MarkMath.getSqrtRatioAtMark(params.markLower),
                    _slit0.sqrtPriceX96,
                    params.liquidityDelta
                );

                s.liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // current mark is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SRValMath.returnAmount1Increase(
                    MarkMath.getSqrtRatioAtMark(params.markLower),
                    MarkMath.getSqrtRatioAtMark(params.markUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    /// @dev Gets and updates a position with the given liquidity delta
    /// @param owner the owner of the position
    /// @param markLower the lower mark of the position's mark range
    /// @param markUpper the upper mark of the position's mark range
    /// @param mark the current mark, passed to avoid sloads
    function _upgradePosition(
        address owner,
        int24 markLower,
        int24 markUpper,
        int128 liquidityDelta,
        int24 mark
    ) private returns (Spot.Detail storage spot) {
        spot = s.spots.obtain(owner, markLower, markUpper);

        uint256 _feeGrowthGlobal0X128 = s.feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = s.feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the marks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            (int56 markCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                s.observations.recognizeSingle(
                    time,
                    0,
                    s.slit0.mark,
                    s.slit0.observationIndex,
                    s.liquidity,
                    s.slit0.observationCardinality
                );

            flippedLower = s.marks.latest(
                markLower,
                mark,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                markCumulative,
                time,
                false,
                s.maxLiquidityPerMark
            );
            flippedUpper = s.marks.latest(
                markUpper,
                mark,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                markCumulative,
                time,
                true,
                s.maxLiquidityPerMark
            );

            if (flippedLower) {
                s.markBitmap.turnOverMark(markLower, s.markSpacing);
            }
            if (flippedUpper) {
                s.markBitmap.turnOverMark(markUpper, s.markSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            s.marks.obtainFeeGrowthInside(markLower, markUpper, mark, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        spot.latest(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any mark data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                s.marks.remove(markLower);
            }
            if (flippedUpper) {
                s.marks.remove(markUpper);
            }
        }
    }

  
    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function mint(
        address recipient,
        int24 markLower,
        int24 markUpper,
        uint128 amount,
        bytes calldata data
    ) external lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0);
        (, int256 amount0Int, int256 amount1Int) =
            _changePosition(
                ChangePositionParams({
                    owner: recipient,
                    markLower: markLower,
                    markUpper: markUpper,
                    liquidityDelta: int256(amount).toInt128()
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balanceA();
        if (amount1 > 0) balance1Before = balanceB();
        ISwapiiCallback(msg.sender).swapiiMintCallback(amount0, amount1, data);
        if (amount0 > 0) require(balance0Before.add(amount0) <= balanceA(), 'M0');
        if (amount1 > 0) require(balance1Before.add(amount1) <= balanceB(), 'M1');

        emit Mint(msg.sender, recipient, markLower, markUpper, amount, amount0, amount1);
    }

    
    function retrieve(
        address recipient,
        int24 markLower,
        int24 markUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external lock returns (uint128 amount0, uint128 amount1) {
        // we don't need to checkMarks here, because invalid positions will never have non-zero tokensOwed{0,1}
        Spot.Detail storage spot = s.spots.obtain(msg.sender, markLower, markUpper);

        amount0 = amount0Requested > spot.tokensOwed0 ? spot.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > spot.tokensOwed1 ? spot.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            spot.tokensOwed0 -= amount0;
            TransferHelper.safeTransfer(s.tokenA, recipient, amount0);
        }
        if (amount1 > 0) {
            spot.tokensOwed1 -= amount1;
            TransferHelper.safeTransfer(s.tokenB, recipient, amount1);
        }

        emit Retrieve(msg.sender, recipient, markLower, markUpper, amount0, amount1);
    }

   
    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function burnToken(
        int24 markLower,
        int24 markUpper,
        uint128 amount
    ) external lock returns (uint256 amount0, uint256 amount1) {
        (Spot.Detail storage spot, int256 amount0Int, int256 amount1Int) =
            _changePosition(
                ChangePositionParams({
                    owner: msg.sender,
                    markLower: markLower,
                    markUpper: markUpper,
                    liquidityDelta: -int256(amount).toInt128()
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (spot.tokensOwed0, spot.tokensOwed1) = (
                spot.tokensOwed0 + uint128(amount0),
                spot.tokensOwed1 + uint128(amount1)
            );
        }

        emit BurnToken(msg.sender, markLower, markUpper, amount, amount0, amount1);
    }

    struct SwapStore {
        // the protocol fee for the input token
        uint8 feeProtocol;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the timestamp of the current block
        uint32 blockTimestamp;
        // the current value of the mark accumulator, computed only if we cross an initialized mark
        int56 markCumulative;
        // the current value of seconds per liquidity accumulator, computed only if we cross an initialized mark
        uint160 secondsPerLiquidityCumulativeX128;
        // whether we've computed and cached the above two accumulators
        bool computedLatestObservation;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapCondition {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the mark associated with the current price
        int24 mark;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // amount of input token paid as protocol fee
        uint128 protocolFee;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepCalculations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next mark to swap to from the current mark in the swap direction
        int24 markNext;
        // whether markNext is initialized or not
        bool initialized;
        // sqrt(price) for the next mark (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    
    function swapToken(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external preventDelegateCall returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0, 'AS');

        Slit0 memory slot0Start = s.slit0;

        require(slot0Start.unlocked, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MarkMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MarkMath.MAX_SQRT_RATIO,
            'SPL'
        );

        s.slit0.unlocked = false;

        SwapStore memory cache =
            SwapStore({
                liquidityStart: s.liquidity,
                blockTimestamp: _blockTimestamp(),
                feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
                secondsPerLiquidityCumulativeX128: 0,
                markCumulative: 0,
                computedLatestObservation: false
            });

        bool exactInput = amountSpecified > 0;

        SwapCondition memory state =
            SwapCondition({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: slot0Start.sqrtPriceX96,
                mark: slot0Start.mark,
                feeGrowthGlobalX128: zeroForOne ? s.feeGrowthGlobal0X128 : s.feeGrowthGlobal1X128,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepCalculations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.markNext, step.initialized) = s.markBitmap.anotherProcessedMarkInAWord(
                state.mark,
                s.markSpacing,
                zeroForOne
            );

            // ensure that we do not overshoot the min/max mark, as the mark bitmap is not aware of these bounds
            if (step.markNext < MarkMath.MIN_MARK) {
                step.markNext = MarkMath.MIN_MARK;
            } else if (step.markNext > MarkMath.MAX_MARK) {
                step.markNext = MarkMath.MAX_MARK;
            }

            // get the price for the next mark
            step.sqrtPriceNextX96 = MarkMath.getSqrtRatioAtMark(step.markNext);

            // compute values to swap to the target mark, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapArithmetic.calSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                s.charge
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            // update global fee tracker
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // shift mark if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the mark is initialized, run the mark transition
                if (step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized mark
                    if (!cache.computedLatestObservation) {
                        (cache.markCumulative, cache.secondsPerLiquidityCumulativeX128) = s.observations.recognizeSingle(
                            cache.blockTimestamp,
                            0,
                            slot0Start.mark,
                            slot0Start.observationIndex,
                            cache.liquidityStart,
                            slot0Start.observationCardinality
                        );
                        cache.computedLatestObservation = true;
                    }
                    int128 liquidityNet =
                        s.marks.move(
                            step.markNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : s.feeGrowthGlobal0X128),
                            (zeroForOne ? s.feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulativeX128,
                            cache.markCumulative,
                            cache.blockTimestamp
                        );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }

                state.mark = zeroForOne ? step.markNext - 1 : step.markNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower mark boundary (i.e. already transitioned marks), and haven't moved
                state.mark = MarkMath.getMarkAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // update mark and write an oracle entry if the mark change
        if (state.mark != slot0Start.mark) {
            (uint16 observationIndex, uint16 observationCardinality) =
                s.observations.update(
                    slot0Start.observationIndex,
                    cache.blockTimestamp,
                    slot0Start.mark,
                    cache.liquidityStart,
                    slot0Start.observationCardinality,
                    slot0Start.observationCardinalityNext
                );
            (s.slit0.sqrtPriceX96, s.slit0.mark, s.slit0.observationIndex, s.slit0.observationCardinality) = (
                state.sqrtPriceX96,
                state.mark,
                observationIndex,
                observationCardinality
            );
        } else {
            // otherwise just update the price
            s.slit0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // update liquidity if it changed
        if (cache.liquidityStart != state.liquidity) s.liquidity = state.liquidity;

        // update fee growth global and, if necessary, protocol fees
        // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
        if (zeroForOne) {
            s.feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) s.protocolFees.token0 += state.protocolFee;
        } else {
            s.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) s.protocolFees.token1 += state.protocolFee;
        }

        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        // do the transfers and collect payment
        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(s.tokenB, recipient, uint256(-amount1));

            uint256 balance0Before = balanceA();
            ISwapiiCallback(msg.sender).swapiiSwapCallback(amount0, amount1, data);
            require(balance0Before.add(uint256(amount0)) <= balanceA(), 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(s.tokenA, recipient, uint256(-amount0));

            uint256 balance1Before = balanceB();
            ISwapiiCallback(msg.sender).swapiiSwapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balanceB(), 'IIA');
        }

        emit SwapToken(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.mark);
        s.slit0.unlocked = true;
    }

    
    function surge(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external lock preventDelegateCall {
        uint128 _liquidity = s.liquidity;
        require(_liquidity > 0, 'L');

        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, s.charge, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, s.charge, 1e6);
        uint256 balance0Before = balanceA();
        uint256 balance1Before = balanceB();

        if (amount0 > 0) TransferHelper.safeTransfer(s.tokenA, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(s.tokenB, recipient, amount1);

        ISwapiiCallback(msg.sender).swapiiFlashCallback(fee0, fee1, data);

        uint256 balance0After = balanceA();
        uint256 balance1After = balanceB();

        require(balance0Before.add(fee0) <= balance0After, 'F0');
        require(balance1Before.add(fee1) <= balance1After, 'F1');

        // sub is safe because we know balanceAfter is gt balanceBefore by at least fee
        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;

        if (paid0 > 0) {
            uint8 feeProtocol0 = s.slit0.feeProtocol % 16;
            uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 / feeProtocol0;
            if (uint128(fees0) > 0) s.protocolFees.token0 += uint128(fees0);
            s.feeGrowthGlobal0X128 += FullMath.mulDiv(paid0 - fees0, FixedPoint128.Q128, _liquidity);
        }
        if (paid1 > 0) {
            uint8 feeProtocol1 = s.slit0.feeProtocol >> 4;
            uint256 fees1 = feeProtocol1 == 0 ? 0 : paid1 / feeProtocol1;
            if (uint128(fees1) > 0) s.protocolFees.token1 += uint128(fees1);
            s.feeGrowthGlobal1X128 += FullMath.mulDiv(paid1 - fees1, FixedPoint128.Q128, _liquidity);
        }

        emit Surge(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }
        
    function setProtocolCharge(uint8 feeProtocol0, uint8 feeProtocol1) external lock onlyFactoryOwner {
        require(
            (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
                (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10))
        );
        uint8 feeProtocolOld = s.slit0.feeProtocol;
        s.slit0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
        emit SetProtocolCharge(feeProtocolOld % 16, feeProtocolOld >> 4, feeProtocol0, feeProtocol1);
    }

    
    function retrieveProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external lock onlyFactoryOwner returns (uint128 amount0, uint128 amount1) {
        amount0 = amount0Requested > s.protocolFees.token0 ? s.protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > s.protocolFees.token1 ? s.protocolFees.token1 : amount1Requested;

        if (amount0 > 0) {
            if (amount0 == s.protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
            s.protocolFees.token0 -= amount0;
            TransferHelper.safeTransfer(s.tokenA, recipient, amount0);
        }
        if (amount1 > 0) {
            if (amount1 == s.protocolFees.token1) amount1--; // ensure that the slot is not cleared, for gas savings
            s.protocolFees.token1 -= amount1;
            TransferHelper.safeTransfer(s.tokenB, recipient, amount1);
        }

        emit RetrieveProtocol(msg.sender, recipient, amount0, amount1);
    }
}
