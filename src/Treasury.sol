//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";

contract Treasury {
    address public paymentCurrency;
    address public pendingMultisig;
    address public multisig;
    address public pendingAdmin;
    address public admin;

    Withdrawal public pendingWithdrawal;

    struct Withdrawal {
        address currency;
        uint256 amount;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyMultisig() {
        require(msg.sender == multisig);
        _;
    }

    constructor(address _paymentCurrency, address _multisig) {
        admin = msg.sender;
        paymentCurrency = _paymentCurrency;
        multisig = _multisig;
    }

    function setAdmin(address _admin) external onlyAdmin {
        require(pendingAdmin == address(0), "Must approve or reject first!");
        pendingAdmin = _admin;
    }

    function approveAdmin() external onlyMultisig {
        admin = pendingAdmin;
        delete pendingAdmin;
    }

    function rejectAdmin() external onlyMultisig {
        delete pendingAdmin;
    }

    function setMultisig(address _multisig) external onlyAdmin {
        require(pendingMultisig == address(0), "Must approve or reject first!");
        pendingMultisig = _multisig;
    }

    function approveMultisig() external onlyMultisig {
        multisig = pendingMultisig;
        delete pendingMultisig;
    }

    function rejectMultisig() external onlyMultisig {
        delete pendingMultisig;
    }

    function withdrawCurrency(address _currency, uint256 _amount) external onlyAdmin {
        pendingWithdrawal.currency = _currency;
        pendingWithdrawal.amount = _amount;
    }   

    function confirmWithdrawal() external onlyMultisig {
        IERC20(pendingWithdrawal.currency).transferFrom(
            address(this), 
            multisig, 
            pendingWithdrawal.amount
        );
    }

    function rejectWithdrawal() external onlyMultisig {
        delete pendingWithdrawal;
    }
}