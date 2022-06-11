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

    function purchaseExecutorPermission() external;

    function updateVolumeTracker(address _token) external;

    function lockCredit(address _token, uint256 _amount) external;

    function unlockCredit(address _token) external;

    function claimReward(uint256 _epoch, address _rewardToken) external;

    function getCurrenEpoch() external view returns(uint256 epoch);
}