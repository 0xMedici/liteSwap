//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { SwapFactory } from "./SwapFactory.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

import "./helpers/ReentrancyGuard.sol";

contract Swap is ReentrancyGuard {
    
    SwapFactory public immutable factory;
    address public immutable swapToken1;
    address public immutable swapToken2;

    mapping(address => mapping(address => uint256)) public pendingReturns;
    mapping(uint256 => mapping(address => mapping(uint256 => LowestBidder))) public lowestBlockBidInfo;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => LowestBidder)))) public lowestIndivBidInfo;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public openSwaps;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public openSwapsExecuted;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public openBlockRewardClaimed;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public openExecutionRewards;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => uint256)))) public openBlockBids;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => uint256)))) public openIndivBids;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => bool)))) public openIndivExecuted;
    mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => bool)))) public openIndivRewardClaimed;

    struct LowestBidder {
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

    event IndivBroadcasted(address _buyer, uint256 _block, uint256 _price, uint256 _executorReward, uint256 _amount);
    event BlockBroadcasted(address _buyer, uint256 _block, uint256 _price, uint256 _executorReward, uint256 _amount);

    constructor(address token1, address token2) {
        factory = SwapFactory(msg.sender);
        swapToken1 = token1;
        swapToken2 = token2;
    }

    function broadcastBlockBid(
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _executionOffering
    ) external nonReentrant validToken(_token) {
        require(_price < 2**127);
        require(_amount < 2**127);
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(
            size == 0 
            || factory.interactionPurchased(msg.sender, factory.getCurrenEpoch())
        );
        uint256 compInfo;
        compInfo |= _executionOffering;
        compInfo <<= 128;
        compInfo |= (100 - _executionOffering) * _amount / 100;
        openBlockBids[block.number + 3][msg.sender][_token][_price] = compInfo;
        openSwaps[block.number + 3][_token][_price] += (100 - _executionOffering) * _amount / 100;
        openExecutionRewards[block.number + 3][_token][_price] += _executionOffering * _amount / 100;
        IERC20(_token).transferFrom(msg.sender, address(this), (_amount));

        emit BlockBroadcasted(
            msg.sender, 
            block.number + 3, 
            _price, 
            _executionOffering * _amount / 100, 
            (100 - _executionOffering) * _amount / 100
        );
    }

    function bidForBlock(
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _price,
        uint128 _amount,
        uint128 _bid
    ) external nonReentrant validToken(_token) {
        require(block.number < _block, "IBE 1");
        require(block.number + 3 >= _block, "IBE 2");
        require(_amount == openSwaps[_block][_token][_price], "Improper amount");
        require(_bid <= _price, "Improper bid");
        LowestBidder storage lowestBids = lowestBlockBidInfo[_block][_token][_price];
        if(openSwapsExecuted[_block][_token][_price])
            require(lowestBids.bid > _bid, "Must outbid");
        pendingReturns[lowestBids.bidder][_swapToken] += _amount;
        lowestBids.bid = _bid;
        lowestBids.bidder = msg.sender;
        openSwapsExecuted[_block][_token][_price] = true;
        IERC20(_swapToken).transferFrom(msg.sender, address(this), _amount);
    }

    function broadcastIndiv(
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _executionOffering
    ) external nonReentrant validToken(_token) {
        require(_price < 2**127);
        require(_amount < 2**127);
        uint32 size;
        address _addr = msg.sender;
        assembly {
            size := extcodesize(_addr)
        }
        require(
            size == 0 
            || factory.interactionPurchased(msg.sender, factory.getCurrenEpoch())
        );
        uint256 compInfo;
        compInfo |= _executionOffering;
        compInfo <<= 128;
        compInfo |= _amount;
        openIndivBids[block.number + 3][msg.sender][_token][_price] = compInfo;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        emit IndivBroadcasted(msg.sender, block.number + 3, _price, compInfo >> 128, compInfo & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    function bidForIndiv(
        address _holder,
        address _token,
        address _swapToken,
        uint256 _block,
        uint256 _price,
        uint128 _amount,
        uint128 _bid
    ) external nonReentrant validToken(_token) {
        require(block.number < _block, "IBE 1");
        require(block.number + 3 >= _block, "IBE 2");
        require(
            _amount == 
                openIndivBids[_block][_holder][_token][_price] 
                    & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 
                    "Improper amount"
        );
        require(_bid <= _price, "Improper bid");
        LowestBidder storage lowestBids = 
            lowestIndivBidInfo[_block][_holder][_token][_price];
        if(openIndivExecuted[_block][_holder][_token][_price]) 
            require(lowestBids.bid > _bid, "Must outbid");
        pendingReturns[lowestBids.bidder][_swapToken] += _amount;
        lowestBids.bid = _bid;
        lowestBids.bidder = msg.sender;
        openIndivExecuted[_block][_holder][_token][_price] = true;
        IERC20(_swapToken).transferFrom(msg.sender, address(this), _amount * _bid / 1e18);
    }

    function claimBlockReward(
        address _token,
        uint256[10] memory _block,
        uint256[10] memory _price
    ) external nonReentrant validToken(_token) returns(uint256) {
        uint256 length = _block.length;
        uint256 amount;
        for(uint256 i = 0; i < length; i++) {
            if(_block[i] == 0 || _price[i] == 0) 
                break;
            require(!openBlockRewardClaimed[_block[i]][_token][_price[i]]);
            LowestBidder memory lowestBid = 
                lowestBlockBidInfo[_block[i]][_token][_price[i]];
            require(lowestBid.bidder == msg.sender);
            amount += openExecutionRewards[_block[i]][_token][_price[i]];
            openBlockRewardClaimed[_block[i]][_token][_price[i]] = true;
        }

        IERC20(_token).transfer(msg.sender, amount);
        return(amount);
    }

    function claimIndivReward(
        address _token,
        address[10] memory _users,
        uint256[10] memory _block,
        uint256[10] memory _price
    ) external nonReentrant validToken(_token) returns(uint256) {
        uint256 length = _block.length;
        uint256 amount;
        for(uint256 i = 0; i < length; i++) {
            if(_users[i] == address(0)) 
                break;
            require(!openIndivRewardClaimed[_block[i]][_users[i]][_token][_price[i]]);
            LowestBidder memory lowestBid = 
                lowestIndivBidInfo[_block[i]][_users[i]][_token][_price[i]];
            require(lowestBid.bidder == msg.sender);
            amount += (openIndivBids[_block[i]][_users[i]][_token][_price[i]] >> 128) 
                        * (openIndivBids[_block[i]][_users[i]][_token][_price[i]] 
                            & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) / 100;
            openIndivRewardClaimed[_block[i]][_users[i]][_token][_price[i]] = true;
        }

        IERC20(_token).transfer(msg.sender, amount);
        return(amount);
    }

    function claimProceeds(
        address _token,
        uint256[10] memory blocks,
        uint256[10] memory prices
    ) external nonReentrant validToken(_token) returns(uint256) {
        uint256 length = blocks.length;
        uint256 amount;
        for(uint256 i = 0; i < length; i++) {
            if(openSwapsExecuted[blocks[i]][_token][prices[i]])
                amount += openBlockBids[blocks[i]][msg.sender][_token][prices[i]] 
                    & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            if(openIndivExecuted[blocks[i]][msg.sender][_token][prices[i]])
                amount += (100 - (openIndivBids[blocks[i]][msg.sender][_token][prices[i]] >> 128)) 
                        * (openIndivBids[blocks[i]][msg.sender][_token][prices[i]] 
                            & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) / 100;
            
            delete openBlockBids[blocks[i]][msg.sender][_token][prices[i]];
            delete openIndivBids[blocks[i]][msg.sender][_token][prices[i]];
        }

        IERC20(_token).transfer(msg.sender, amount);
        return amount;
    }
}

