// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {LibDiamond} from "./LibDiamond.sol";
import "./Mark.sol";
import "./Spot.sol";
import "./OracleLib.sol";

// SwapiiPoolDeployer
struct Variables {
    address factory;
    address token0;
    address token1;
    uint24 fee;
    int24 markSpacing;
}

struct Slit0 {
    // the current price
    uint160 sqrtPriceX96;
    // the current mark
    int24 mark;
    // the most-recently updated index of the observations array
    uint16 observationIndex;
    // the current maximum number of observations that are being stored
    uint16 observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 observationCardinalityNext;
    // the current protocol fee as a percentage of the swap fee taken on withdrawal
    // represented as an integer denominator (1/x)%
    uint8 feeProtocol;
    // whether the pool is locked
    bool unlocked;
}

struct ProtocolFees {
    uint128 token0;
    uint128 token1;
}

struct AppStorage {

    // preventDelegateCall
    address originContract;

   // SwapiiFactory
    address holder;

    mapping(uint24 => int24) feeAmountMarkSpacing;

    mapping(address => mapping(address => mapping(uint24 => address))) obtainPool;

    // SwapiiPool vars
    address factoryAddress;
    
    address tokenA;
    
    address tokenB;
    
    uint24 charge;

    int24 markSpacing;

    uint128 maxLiquidityPerMark;

    Slit0 slit0;
    
    uint256 feeGrowthGlobal0X128;
   
    uint256 feeGrowthGlobal1X128;

    ProtocolFees protocolFees;

    uint128 liquidity;
    
    mapping(int24 => Mark.Detail) marks;
    
    mapping(int16 => uint256) markBitmap;
    
    mapping(bytes32 => Spot.Detail) spots;
   
    OracleLib.Observation[65535] observations;

    // swapiipooldeployer
    Variables variables;

}

library LibAppStorage {
  function diamondStorage() internal pure returns (AppStorage storage ds) {
    assembly {
      ds.slot := 0
    }
  }
}

contract check{
AppStorage s;
function getVars() internal pure returns(address a,address b,address c,uint24 d,int24 e){
a=s.variables.factory;
b=s.variables.token0;
c=s.variables.token1;
d=s.variables.fee;
e= s.variables.markSpacing
}

}

// uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;
// AppStorage storage s = LibAppStorage.diamondStorage();
