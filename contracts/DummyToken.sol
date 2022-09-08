//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import { ERC20 } from "./helpers/ERC20.sol";

import "./helpers/ReentrancyGuard.sol";

contract DummyToken is ERC20, ReentrancyGuard {

    constructor() ERC20("Test Token", "TT"){}


    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }
}