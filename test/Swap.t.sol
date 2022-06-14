// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SampleOwner } from "../src/SampleOwner.sol";
import { Swap } from "../src/Swap.sol";
import { SwapFactory } from "../src/SwapFactory.sol";
import { Treasury } from "../src/Treasury.sol";
import { SampleToken } from "../src/SampleToken.sol";
import "forge-std/Test.sol";

contract SwapTest is Test {

    Treasury treasury;
    SwapFactory factory;
    SampleToken paymentCurrency;
    SampleToken token1;
    SampleToken token2;
    SampleOwner owner;
    Swap swapPool;

    function setUp() public {
        owner = new SampleOwner();
        paymentCurrency = new SampleToken(address(owner));
        treasury = new Treasury(address(paymentCurrency), address(0));
        factory = new SwapFactory(address(treasury), address(paymentCurrency));
        token1 = new SampleToken(address(owner));
        token2 = new SampleToken(address(owner));
        factory.createSwap(address(token1), address(token2));
        swapPool = Swap(factory.swapAddress(address(token1),address(token2)));
        owner.purchase(address(factory));
    }

    function testIndivBroadcast() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastIndiv(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
    }

    function testIndivExecution() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastIndiv(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidIndiv(
            address(swapPool),
            address(owner),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            100e18,
            99e16
        );
    }

    function testIndivReward() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastIndiv(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidIndiv(
            address(swapPool),
            address(owner),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            100e18,
            99e16
        );

        vm.roll(4);
        uint256[10] memory blocks;
        uint256[10] memory prices;
        address[10] memory users;
        blocks[0] = 4;
        prices[0] = 1e18;
        users[0] = address(owner);
        uint256 reward = owner.claimIndivReward(
            address(swapPool),
            address(token1),
            users, 
            blocks, 
            prices
        );
        assertEq(reward, 3e18);
    }

    function testIndivProceeds() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastIndiv(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidIndiv(
            address(swapPool),
            address(owner),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            100e18,
            99e16
        );

        vm.roll(4);
        uint256[10] memory blocks;
        uint256[10] memory prices;
        blocks[0] = 4;
        prices[0] = 1e18;
        uint256 payout = owner.claimProceeds(
            address(swapPool),
            address(token1),
            blocks,
            prices
        );
        assertEq(payout, 97e18);
    }

    function testBlockBroadcast() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastBlock(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
    }

    function testBlockExecution() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastBlock(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidBlock(
            address(swapPool),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            97e18,
            99e16
        );
    }

    function testBlockReward() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastBlock(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidBlock(
            address(swapPool),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            97e18,
            99e16
        );

        vm.roll(4);
        uint256[10] memory blocks;
        uint256[10] memory prices;
        blocks[0] = 4;
        prices[0] = 1e18;
        uint256 reward = owner.claimBlockReward(
            address(swapPool), 
            address(token1), 
            blocks, 
            prices
        );
        assertEq(reward, 3e18);
    }

    function testBlockProceeds() public {
        owner.approveTransfer(address(token1), address(swapPool), 100e18);
        owner.broadcastBlock(
            address(swapPool),
            address(token1),
            100e18,
            1e18,
            3
        );
        owner.approveTransfer(address(token2), address(swapPool), 100e18);
        owner.bidBlock(
            address(swapPool),
            address(token1),
            address(token2),
            block.number + 3,
            1e18,
            97e18,
            99e16
        );

        vm.roll(4);
        uint256[10] memory blocks;
        uint256[10] memory prices;
        blocks[0] = 4;
        prices[0] = 1e18;
        uint256 payout = owner.claimProceeds(
            address(swapPool),
            address(token1),
            blocks,
            prices
        );
        assertEq(payout, 97e18);
    }
}
