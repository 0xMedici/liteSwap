//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Swap } from "./Swap.sol";
import { SwapFactory } from "./SwapFactory.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

contract SampleOwner {

    function purchase(address factory) external {
        SwapFactory(factory).purchaseExecutorPermission();
        SwapFactory(factory).purchaseInteractionPermission();
    }

    function approveTransfer(address token, address receiver, uint256 amount) external {
        IERC20(token).approve(receiver, amount);
    }

    function broadcastIndiv(
        address swapPool, 
        address token, 
        uint256 amount, 
        uint256 price, 
        uint256 executionReward
    ) external {
        Swap(swapPool).broadcastIndiv(token, amount, price, executionReward);
    }

    function bidIndiv(
        address swapPool,
        address _holder,
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _price,
        uint128 _amount,
        uint128 _bid
    ) external {
        Swap(swapPool).bidForIndiv(
            _holder,
            _token,
            _swapToken,
            _block,
            _price,
            _amount,
            _bid
        );
    }

    function claimIndivReward(
        address swapPool,
        address _token,
        address[10] memory _users,
        uint256[10] memory _blocks,
        uint256[10] memory _prices
    ) external returns(uint256) {
        return Swap(swapPool).claimIndivReward(_token, _users, _blocks, _prices);
    }

    function broadcastBlock(
        address swapPool,
        address token,
        uint256 amount,
        uint256 price,
        uint256 executionOffering
    ) external {
        Swap(swapPool).broadcastBlockBid(token, amount, price, executionOffering);
    }

    function bidBlock(
        address swapPool,
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _price,
        uint128 _amount,
        uint128 _bid
    ) external {
        Swap(swapPool).bidForBlock(
            _token,
            _swapToken,
            _block,
            _price,
            _amount,
            _bid
        );
    }

    function claimBlockReward(
        address swapPool,
        address _token,
        uint256[10] memory blocks,
        uint256[10] memory prices
    ) external returns(uint256) {
        return Swap(swapPool).claimBlockReward(_token, blocks, prices);
    }

    function claimProceeds(
        address swapPool,
        address _token,
        uint256[10] memory blocks,
        uint256[10] memory prices
    ) external returns(uint256) {
        return Swap(swapPool).claimProceeds(_token, blocks, prices);
    }
}