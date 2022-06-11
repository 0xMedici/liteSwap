//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISwap {
    function bid(
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _executionOffering
    ) external;

    function fillBid(
        address _token,
        uint256 _amount,
        uint256 _price
    ) external;

    function executeProceedTransfer(
        address _user,
        address _token,
        uint256 _price,
        uint256 _amount
    ) external;

    function claimProceeds(
        address _token
    ) external;
}