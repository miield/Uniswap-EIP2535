// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISwapiiPool {

    event Initialize(uint160 sqrtPriceX96, int24 tick);
    
    event Mint(address sender, address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);

    event Retrieve(address indexed owner, address recipient, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount0, uint128 amount1);

    event BurnToken(address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);

    event SwapToken(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);

    event Surge(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1);

    event IncreaseRecognizationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);

    event SetProtocolCharge(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    event RetrieveProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);

    function factoryAddress() external view returns (address);

    function tokenA() external view returns (address);

    function tokenB() external view returns (address);

    function charge() external view returns (uint24);

    function markSpacing() external view returns (int24);

    function maxLiquidityPerMark() external view returns (uint128);

    function slit0() external view returns (        
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );

    function feeGrowthGlobal0X128() external view returns (uint256);

    function feeGrowthGlobal1X128() external view returns (uint256);

    function protocolFees() external view returns (
        uint128 token0,
        uint128 token1
    );

    function liquidity() external view returns (uint128);
    
    function marks(int24) external view returns (
        uint128 liquidityGross,
        int128 liquidityNet,
        uint256 feeGrowthOutside0X128,
        uint256 feeGrowthOutside1X128,
        int56 markCumulativeOutside,
        uint160 secondsPerLiquidityOutsideX128,
        uint32 secondsOutside,
        bool initialized
    );

    function markBitmap(int16 wordPos) external view returns (uint256);

    function spots(bytes32 spot) external view returns (
        uint128 liquidity, 
        uint256 feeGrowthInside0LastX128, 
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );

    // OracleLib.Observation[65535] public observations;

    function checkMarks(int24 tickLower, int24 tickUpper) external pure; 
    function _blockTimestamp() external view returns (uint32);

    //          PRIVATE FUNCTIONS
    // function balanceA() external view returns (uint256); 
    // function balanceB() external view returns (uint256);

    function snapshotTotalInside(int24 tickLower, int24 tickUpper) external view returns (
        int56 tickCumulativeInside,
        uint160 secondsPerLiquidityInsideX128,
        uint32 secondsInside
    );

    function recognize(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    function increaseRecognizationCardinalityNext(uint16 observationCardinalityNext) external;

    function configure(uint160 sqrtPriceX96) external;

//          PRIVATE FUNCTIONs
    // function _changePosition(ChangePositionParams memory params) external returns (
    //     Spot.Detail storage position,
    //     int256 amount0,
    //     int256 amount1
    // );

    // function _upgradePosition(
    //     address owner,
    //     int24 tickLower,
    //     int24 tickUpper,
    //     int128 liquidityDelta,
    //     int24 tick
    // ) external returns (Spot.Detail storage spot);

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function retrieve(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1); 

    function burnToken(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function swapToken(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function surge(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    
    function setProtocolCharge(uint8 feeProtocol0, uint8 feeProtocol1) external;
    
    function retrieveProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);


}