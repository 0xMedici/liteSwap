//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { SwapFactory } from "./SwapFactory.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Swap is ReentrancyGuard {
    
    SwapFactory public immutable factory;
    address public immutable swapToken1;
    address public immutable swapToken2;

    mapping(address => mapping(address => uint256)) public outstandingSaleProceeds;
    mapping(address => mapping(uint256 => uint256)) public openSwaps;
    mapping(address => mapping(uint256 => uint256)) public trancheSaleProceeds;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public tranchePosition;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public trancheExecutionOffering;

    modifier validToken(address _token) {
        require(
            _token == swapToken1
            || _token == swapToken2
        );
        _;
    }

    constructor(address token1, address token2) {
        factory = SwapFactory(msg.sender);
        swapToken1 = token1;
        swapToken2 = token2;
    }

    function bid(
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _executionOffering
    ) external nonReentrant validToken(_token) {
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(
            size == 0 
            || factory.interactionPurchased(msg.sender, factory.getCurrenEpoch())
        );
        openSwaps[_token][_price] += _amount; 
        tranchePosition[msg.sender][_token][_price] += _amount;
        trancheExecutionOffering[msg.sender][_token][_price] = _executionOffering;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function fillBid(
        address _token,
        uint256 _amount,
        uint256 _price
    ) external nonReentrant validToken(_token) {
        require(openSwaps[_token][_price] >= _amount);
        uint256 cost = _amount * _price / 1e18;
        openSwaps[_token][_price] += _amount;
        trancheSaleProceeds[_token][_price] += cost;
        address swapToken;
        if(_token == swapToken1) {
            swapToken = swapToken2;
        } else {
            swapToken = swapToken1;
        }
        bool sent = IERC20(swapToken).transferFrom(msg.sender, address(this), cost);
        require(sent);
        sent = IERC20(_token).transferFrom(address(this), msg.sender, _amount);
        require(sent);
    }

    function executeProceedTransfer(
        address _user,
        address _token,
        uint256 _price,
        uint256 _amount
    ) external nonReentrant validToken(_token) {
        if(msg.sender != _user) {
            require(factory.executionPurchased(msg.sender, factory.getCurrenEpoch()));
            if(factory.claimWhitelist(_token)) {
                factory.updateVolumeTracker(_token);
            }
        }
        require(tranchePosition[_user][_token][_price] >= _amount);
        require(trancheSaleProceeds[_token][_price] >= _amount * _price / 1e18);
        tranchePosition[_user][_token][_price] -= _amount;
        trancheSaleProceeds[_token][_price] -= _amount * _price / 1e18;
        outstandingSaleProceeds[_user][_token] += (100 - trancheExecutionOffering[_user][_token][_price]) * (_amount * _price / 1e18) / 100;
        outstandingSaleProceeds[msg.sender][_token] += trancheExecutionOffering[_user][_token][_price] * (_amount * _price / 1e18) / 100;
    }

    function claimProceeds(
        address _token
    ) external nonReentrant validToken(_token) {
        uint256 payout = outstandingSaleProceeds[msg.sender][_token];
        delete outstandingSaleProceeds[msg.sender][_token];
        bool sent = IERC20(_token).transferFrom(address(this), msg.sender, payout);
        require(sent);
    }
}