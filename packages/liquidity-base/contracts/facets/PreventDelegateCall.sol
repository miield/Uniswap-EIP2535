// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity  =0.7.6; 

abstract contract PreventDelegateCall {

    address private immutable originContract;


    constructor() {
        originContract = address(this);
    } 

    modifier preventDelegateCall {
        require(address(this) == originContract);
        _;
    }
    
} 