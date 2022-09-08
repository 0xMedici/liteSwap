//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISwapFactory {
    
    function setTreasury(address _treasury) external;

    function approveTreasury() external;

    function rejectTreasury() external;

    function createSwap(
        address swapToken1,
        address swapToken2
    ) external;
}