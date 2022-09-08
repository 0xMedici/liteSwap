//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import { ERC20 } from "./helpers/ERC20.sol";

import "./helpers/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Swap is ReentrancyGuard {

    address public immutable treasury;
    address public immutable swapToken1;
    address public immutable swapToken2;

    mapping(address => mapping(address => uint256)) public credits;
    mapping(address => mapping(address => uint256)) public creditInUse;
    mapping(address => mapping(address => uint256)) public pendingReturns;

    mapping(uint256 => mapping(address => mapping(uint256 => Bid))) public blockBidInfo;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public openSwapsExecuted;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public openBlockRewardClaimed;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public openSwaps;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public openSwapsExecutorReward;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => uint256)))) public openBlockBids;

    struct Bid {
        address bidder;
        uint256 bid;
    }

    modifier validToken(address _token) {
        require(
            _token == swapToken1
            || _token == swapToken2
        );
        _;
    }

    event BlockBroadcasted(address _buyer, uint256 _block, uint256 _price, uint256 _executorReward, uint256 _amount);
    event BlockBidSubmitted(address _bidder, uint256 _block, uint256 _price, uint256 _bid);

    constructor(address _treasury, address token1, address token2) {
        treasury = _treasury;
        swapToken1 = token1;
        swapToken2 = token2;
    }

    function addCredit(
        address _token,
        uint256 _amount
    ) external nonReentrant validToken(_token) {
        bool sent = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        require(sent);
        credits[msg.sender][_token] += _amount;
    }

    function removeCredit(
        address _token,
        uint256 _amount
    ) external nonReentrant validToken(_token) {
        require(credits[msg.sender][_token] - creditInUse[msg.sender][_token] >= _amount);
        bool sent = IERC20(_token).transfer(msg.sender, _amount);
        require(sent);
        credits[msg.sender][_token] -= _amount;
    }

    function broadcastBlockBid(
        address _token,
        uint256 _amount,
        uint256 _priceNum,
        uint256 _priceDen
    ) external nonReentrant validToken(_token) {
        require(credits[msg.sender][_token] >= creditInUse[msg.sender][_token] + 1003 * (_amount) / 1000);
        uint256 price = _priceNum * 1e18 / _priceDen;
        openBlockBids[block.number + 3][msg.sender][_token][price] += _amount;
        openSwaps[block.number + 3][_token][price] += _amount;
        openSwapsExecutorReward[block.number + 3][_token][price] += 3 * _amount / 1000;
        creditInUse[msg.sender][_token] += 1003 * (_amount) / 1000;

        emit BlockBroadcasted(
            msg.sender,
            block.number + 3,
            _priceNum * 1e18 / _priceDen,
            3 * _amount / 1000,
            _amount
        );
    }

    function bidForBlock(
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _priceNum,
        uint256 _priceDen,
        uint256 _bid
    ) external nonReentrant validToken(_token) {
        uint256 price = _priceNum * 1e18 / _priceDen;
        emit BlockBidSubmitted(msg.sender, _block, price, _bid);
        require(block.number < _block, "IBE 1");
        require(block.number + 3 >= _block, "IBE 2");
        Bid storage bids = blockBidInfo[_block][_token][price];
        if(openSwapsExecuted[_block][_token][price]) {
            require(_bid > bids.bid, "Must outbid");
            pendingReturns[bids.bidder][_swapToken] += bids.bid;
        }
        bids.bid = _bid;
        bids.bidder = msg.sender;
        openSwapsExecuted[_block][_token][price] = true;
        IERC20(_swapToken).transferFrom(
            msg.sender, 
            address(this), 
            _bid * 1e18 / price
        );
    }

    function claimBlockReward(
        address _token,
        uint256[] memory _block,
        uint256[] memory _priceNum,
        uint256[] memory _priceDen
    ) external nonReentrant validToken(_token) returns(uint256) {
        require(_block.length <= 10);
        uint256 length = _block.length;
        uint256 amount;
        uint256 fee;
        for(uint256 i = 0; i < length; i++) {
            if(_block[i] == 0) 
                break;
            uint256 price = _priceNum[i] * 1e18 / _priceDen[i];
            require(_block[i] < block.number);
            require(!openBlockRewardClaimed[_block[i]][_token][price]);
            Bid memory bid = 
                blockBidInfo[_block[i]][_token][price];
            require(bid.bidder == msg.sender);
            if(openSwaps[_block[i]][_token][price] > bid.bid * price * ERC20(_token).decimals() / 1e18) {
                amount += bid.bid * price * ERC20(_token).decimals() / 1e18;
            } else {
                amount += openSwaps[_block[i]][_token][price];
            }
            fee += openSwapsExecutorReward[_block[i]][_token][price];
            openBlockRewardClaimed[_block[i]][_token][price] = true;

            delete openSwapsExecutorReward[_block[i]][_token][price];
        }

        uint256 protocolFee = fee / 6;
        IERC20(_token).transfer(treasury, protocolFee);
        IERC20(_token).transfer(msg.sender, amount + fee - protocolFee);
        return(amount);
    }

    function claimProceeds(
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _priceNum,
        uint256 _priceDen
    ) external nonReentrant validToken(_token) returns(uint256) {
        uint256 amount;
        uint256 tempBlock;
        uint256 _price = _priceNum * 1e18 / _priceDen;
        uint256 blockInfo = openBlockBids[_block][msg.sender][_token][_price];
        if(openSwapsExecuted[_block][_token][_price]) {
            tempBlock = blockInfo * blockBidInfo[_block][_token][_price].bid 
                    / openSwaps[_block][_token][_price];
            amount += tempBlock;
        }
        openBlockBids[_block][msg.sender][_token][_price] -= tempBlock;

        IERC20(_swapToken).transfer(msg.sender, amount);
        return amount;
    }

    function reclaimOrder(
        address _token,
        uint256[] calldata _blocks,
        uint256[] calldata _priceNum,
        uint256[] calldata _priceDen
    ) external nonReentrant validToken(_token) returns(uint256) {
        require(_blocks.length <= 10);
        uint256 length = _blocks.length;
        uint256 amount;
        for(uint256 i = 0; i < length; i++) {
            uint256 price = _priceNum[i] * 1e18 / _priceDen[i];
            if(_blocks[i] == 0) 
                break;
            amount += openBlockBids[_blocks[i]][msg.sender][_token][price];
            delete openBlockBids[_blocks[i]][msg.sender][_token][price];
        }

        creditInUse[msg.sender][_token] -= amount;
        return amount;
    }

    function reclaimFailedBid(
        address _swapToken
    ) external {
        uint256 payout = pendingReturns[msg.sender][_swapToken];
        delete pendingReturns[msg.sender][_swapToken];

        IERC20(_swapToken).transfer(msg.sender, payout);
    }

    function getBlock() external view returns(uint256) {
        return block.number;
    }
}