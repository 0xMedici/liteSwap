//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import { Swap } from "./Swap.sol";
import { Treasury } from "./Treasury.sol";

import "hardhat/console.sol";

contract SwapFactory {

    address public pendingTreasury;
    address public treasury;
    address public paymentCurrency;

    uint256 public executorCost;
    uint256 public fundsForTreasury;
    uint256 public treasuryCut;
    uint256 public startTime;
    uint256 public epochLength;

    mapping(address => bool) public claimWhitelist;
    mapping(address => mapping(address => bool)) public swapExistence;
    mapping(address => mapping(address => address)) public swapAddress;
    mapping(address => bool) public accreditedAddresses;
    mapping(address => mapping(uint256 => bool)) public executionPurchased;
    mapping(address => mapping(uint256 => uint256)) public executionVolume;
    mapping(uint256 => uint256) public totalExecutionVolume;
    mapping(uint256 => uint256) public paymentsMadePerEpoch;
    mapping(address => mapping(uint256 => uint256)) public totalTokensLocked;
    mapping(address => mapping(address => uint256)) public userTokensLocked;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public userTokensLockedEpoch;

    constructor(address _treasury, address _paymentCurrecy) {
        treasury = _treasury;
        paymentCurrency = _paymentCurrecy;
        startTime = block.timestamp;
    }

    function setTreasury(address _treasury) external {
        require(msg.sender == Treasury(treasury).admin());
        pendingTreasury = _treasury;
    }

    function approveTreasury() external {
        require(msg.sender == Treasury(treasury).multisig());
        treasury = pendingTreasury;
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
        Swap newSwapContract = new Swap(swapToken1, swapToken2); 
        swapExistence[swapToken1][swapToken2] = true;
        accreditedAddresses[address(newSwapContract)] = true;
        swapAddress[swapToken1][swapToken2] = address(newSwapContract);
    }

    function purchaseExecutorPermission() external {
        fundsForTreasury += treasuryCut * executorCost / 100;
        uint256 currentEpoch = (block.timestamp - startTime) / epochLength;
        paymentsMadePerEpoch[currentEpoch] += (100 - treasuryCut) * executorCost / 100;
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
            userTokensLockedEpoch[msg.sender][currentEpoch][_rewardToken] * paymentsMadePerEpoch[_epoch] 
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
