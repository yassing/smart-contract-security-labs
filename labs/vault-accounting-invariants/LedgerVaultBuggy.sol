// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "./ToyToken.sol";

/// @notice Deliberately broken toy: withdrawal leaves caller credit unchanged.
contract LedgerVaultBuggy {
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
        require(totalCredits >= amount, "aggregate");
        // BUG: creditOf[msg.sender] is not decreased.
        totalCredits -= amount;
        require(token.transfer(msg.sender, amount), "transfer");
    }
}
