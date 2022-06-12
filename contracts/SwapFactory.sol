//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import { Swap } from "./Swap.sol";
import { Treasury } from "./Treasury.sol";

import "hardhat/console.sol";

contract SwapFactory {

    address public pendingTreasury;
    address public treasury;

    address public pendingPaymentCurrency;
    address public paymentCurrency;

    uint256 public pendingExecutorCost;
    uint256 public baseExecutorCost;
    uint256 public executorCost;

    uint256 public pendingInteractionCost;
    uint256 public baseInteractionCost;
    uint256 public interactionCost;

    uint256 public pendingTreasuryCut;
    uint256 public treasuryCut;

    uint256 public fundsForTreasury;
    uint256 public startTime;
    uint256 public epochLength;
    uint256 public base;
    
    mapping(address => bool) public claimWhitelist;
    mapping(address => mapping(address => bool)) public swapExistence;
    mapping(address => mapping(address => address)) public swapAddress;
    mapping(address => bool) public accreditedAddresses;
    mapping(address => mapping(uint256 => bool)) public executionPurchased;
    mapping(address => mapping(uint256 => bool)) public interactionPurchased;
    mapping(address => mapping(uint256 => uint256)) public executionVolume;
    mapping(uint256 => bool) public baseAdjusted;
    mapping(uint256 => uint256) public totalExecutionVolume;
    mapping(uint256 => uint256) public paymentsMade;
    mapping(address => mapping(uint256 => uint256)) public totalTokensLocked;
    mapping(address => mapping(address => uint256)) public userTokensLocked;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public userTokensLockedEpoch;

    constructor(address _treasury, address _paymentCurrecy) {
        treasury = _treasury;
        paymentCurrency = _paymentCurrecy;
        startTime = block.timestamp;
    }

    function setTreasury(address _treasury) external {
        require(pendingTreasury == address(0), "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingTreasury = _treasury;
    }

    function approveTreasury() external {
        require(msg.sender == Treasury(treasury).multisig());
        treasury = pendingTreasury;
        delete pendingTreasury;
    }

    function rejectTreasury() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingTreasury;
    }

    function setTreasuryCut(uint256 _treasuryCut) external {
        require(pendingTreasuryCut == 0, "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingTreasuryCut = _treasuryCut;
    }

    function approveTreasuryCut() external {
        require(msg.sender == Treasury(treasury).multisig());
        treasuryCut = pendingTreasuryCut;
        delete pendingTreasuryCut;
    }

    function rejectTreasuryCut() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingTreasuryCut;
    }

    function setPaymentCurrency(address _paymentCurrency) external {
        require(pendingPaymentCurrency == address(0), "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingPaymentCurrency = _paymentCurrency;
    }

    function approvePaymentCurrency() external {
        require(msg.sender == Treasury(treasury).multisig());
        paymentCurrency = pendingPaymentCurrency;
        delete pendingPaymentCurrency;
    }

    function rejectPaymentCurrency() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingPaymentCurrency;
    }

    function setExecutionFee(uint256 _fee) external {
        require(pendingExecutorCost == 0, "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingExecutorCost = _fee;
    }

    function approveExecutionFee() external {
        require(msg.sender == Treasury(treasury).multisig());
        baseExecutorCost = pendingExecutorCost;
        delete pendingExecutorCost;
    }

    function rejectExecutionFee() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingExecutorCost;
    }

    function setInteractionFee(uint256 _fee) external {
        require(pendingInteractionCost == 0, "Must approve or reject first!");
        require(msg.sender == Treasury(treasury).admin());
        pendingInteractionCost = _fee;
    }

    function approveInteractionFee() external {
        require(msg.sender == Treasury(treasury).multisig());
        baseInteractionCost = pendingInteractionCost;
        delete pendingInteractionCost;
    }

    function rejectInteractionFee() external {
        require(msg.sender == Treasury(treasury).multisig());
        delete pendingInteractionCost;
    }

    function adjustBase() external {
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        uint256 prevExecutionVolume = totalExecutionVolume[currentEpoch - 1];
        if(prevExecutionVolume > base) {
            base = 
                base * (10_000 + 1_250) / 10_000;
        } else if(prevExecutionVolume > 50 * base / 100) {
            base = 
                base 
                    * (10_000 + 1_250 * prevExecutionVolume / base) 
                        / 10_000;
        } else if(prevExecutionVolume < 50 * base / 100) {
            base = 
                base 
                    * (10_000 - 1_250 * (1_000 - prevExecutionVolume * 1_000 / base) / 1_000)
                        / 10_000;
        }
        if(base < 100) {
            base = 100;
        }

        executorCost = baseExecutorCost * base / 1000;
        interactionCost = baseInteractionCost * base / 1000;

        baseAdjusted[currentEpoch] = true;
    }

    function createSwap(
        address swapToken1,
        address swapToken2
    ) external {
        require(!swapExistence[swapToken1][swapToken2]);
        require(!swapExistence[swapToken2][swapToken1]);
        Swap newSwapContract = new Swap(swapToken1, swapToken2); 
        swapExistence[swapToken1][swapToken2] = true;
        accreditedAddresses[address(newSwapContract)] = true;
        swapAddress[swapToken1][swapToken2] = address(newSwapContract);
    }

    function purchaseInteractionPermission() external {
        fundsForTreasury += treasuryCut * executorCost / 100;
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        if(!baseAdjusted[currentEpoch]) 
            this.adjustBase();
        paymentsMade[currentEpoch] += (100 - treasuryCut) * interactionCost / 100;
        bool sent = IERC20(paymentCurrency).transferFrom(msg.sender, address(this), interactionCost);
        require(sent);
        interactionPurchased[msg.sender][currentEpoch] = true;
    }

    function purchaseExecutorPermission() external {
        fundsForTreasury += treasuryCut * executorCost / 100;
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        if(!baseAdjusted[currentEpoch]) 
            this.adjustBase();
        paymentsMade[currentEpoch] += (100 - treasuryCut) * executorCost / 100;
        bool sent = IERC20(paymentCurrency).transferFrom(msg.sender, address(this), executorCost);
        require(sent);
        executionPurchased[msg.sender][currentEpoch] = true;
    }

    function updateVolumeTracker(address _token) external {
        require(accreditedAddresses[msg.sender]);
        require(claimWhitelist[_token]);
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        executionVolume[_token][currentEpoch]++;
        totalExecutionVolume[currentEpoch]++;
    }

    function lockCredit(address _token, uint256 _amount) external {
        require(claimWhitelist[_token]);
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        userTokensLocked[msg.sender][_token] += _amount;
        userTokensLockedEpoch[msg.sender][currentEpoch][_token] += _amount;
        totalTokensLocked[_token][currentEpoch] += _amount;
    }

    function unlockCredit(address _token) external {
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        require(userTokensLockedEpoch[msg.sender][currentEpoch][_token] == 0);
        uint256 payout = userTokensLocked[msg.sender][_token];
        delete userTokensLocked[msg.sender][_token];
        IERC20(_token).transferFrom(address(this), msg.sender, payout);
    }

    function claimReward(uint256 _epoch, address _rewardToken) external {
        require(claimWhitelist[_rewardToken]);
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        uint256 payout = 
            userTokensLockedEpoch[msg.sender][currentEpoch][_rewardToken] * paymentsMade[_epoch] 
                * executionVolume[_rewardToken][_epoch] / totalExecutionVolume[_epoch] 
                    / totalTokensLocked[_rewardToken][currentEpoch];
        delete userTokensLockedEpoch[msg.sender][currentEpoch][_rewardToken];
        bool sent = IERC20(paymentCurrency).transferFrom(address(this), msg.sender, payout);
        require(sent);
    }

    function getCurrenEpoch() external view returns(uint256 epoch) {
        epoch = (block.timestamp - startTime) / epochLength;
    }
}
