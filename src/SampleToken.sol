//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ERC20 } from "./helpers/ERC20.sol";

contract SampleToken is ERC20 {

    constructor(address _caller) ERC20("SampleToken", "STK") {
        _mint(_caller, 10000e18);
        require(totalSupply() == 10000e18);
    }
}