//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { ERC20 } from "./helpers/ERC20.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { Swap } from "./Swap.sol";
import { Treasury } from "./Treasury.sol";

contract SwapFactory {

    address public pendingTreasury;
    Treasury public treasury;
    
    mapping(address => mapping(address => bool)) public swapExistence;
    mapping(address => mapping(address => address)) public swapAddress;

    constructor(address _treasury) {
        treasury = Treasury(_treasury);
    }

    function setTreasury(address _treasury) external {
        require(pendingTreasury == address(0), "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingTreasury = _treasury;
    }

    function approveTreasury() external {
        require(msg.sender == Treasury(treasury).multisig());
        treasury = Treasury(pendingTreasury);
        delete pendingTreasury;
    }

    function rejectTreasury() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingTreasury;
    }

    function createSwap(
        address swapToken1,
        address swapToken2
    ) external {
        require(!swapExistence[swapToken1][swapToken2]);
        require(!swapExistence[swapToken2][swapToken1]);
        Swap newSwapContract = new Swap(address(treasury), swapToken1, swapToken2); 
        swapExistence[swapToken1][swapToken2] = true;
        swapAddress[swapToken1][swapToken2] = address(newSwapContract);
    }
}
