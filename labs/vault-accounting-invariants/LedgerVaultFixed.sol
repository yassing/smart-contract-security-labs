// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "./ToyToken.sol";

/// @notice Toy correction that keeps per-user and aggregate credits aligned.
contract LedgerVaultFixed {
    ToyToken public immutable token;
    mapping(address => uint256) public creditOf;
    uint256 public totalCredits;

    constructor(ToyToken fakeToken) {
        token = fakeToken;
    }

    function deposit(uint256 amount) external {
        require(amount != 0, "zero");
        require(token.transferFrom(msg.sender, address(this), amount), "transfer");
        creditOf[msg.sender] += amount;
        totalCredits += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount != 0 && creditOf[msg.sender] >= amount, "credit");
        creditOf[msg.sender] -= amount;
        totalCredits -= amount;
        require(token.transfer(msg.sender, amount), "transfer");
    }
}
