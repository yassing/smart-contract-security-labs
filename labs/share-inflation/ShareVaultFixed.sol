// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "../vault-accounting-invariants/ToyToken.sol";

/// @notice Toy correction with two independent defences:
/// 1. virtual shares and a virtual asset make a donation mostly accrue to shares
///    nobody can redeem, so the attack costs the attacker more than it takes;
/// 2. the depositor states a minimum share amount, and zero-share deposits revert.
contract ShareVaultFixed {
    uint256 internal constant VIRTUAL_SHARES = 1e6;
    uint256 internal constant VIRTUAL_ASSETS = 1;

    ToyToken public immutable asset;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(ToyToken fakeToken) {
        asset = fakeToken;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return assets * (totalSupply + VIRTUAL_SHARES) / (totalAssets() + VIRTUAL_ASSETS);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return shares * (totalAssets() + VIRTUAL_ASSETS) / (totalSupply + VIRTUAL_SHARES);
    }

    function deposit(uint256 assets, uint256 minShares) external returns (uint256 shares) {
        require(assets != 0, "zero");
        shares = previewDeposit(assets);
        require(shares != 0 && shares >= minShares, "slippage");
        require(asset.transferFrom(msg.sender, address(this), assets), "transfer");
        balanceOf[msg.sender] += shares;
        totalSupply += shares;
    }

    function redeem(uint256 shares) external returns (uint256 assets) {
        require(shares != 0 && balanceOf[msg.sender] >= shares, "shares");
        assets = previewRedeem(shares);
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        require(asset.transfer(msg.sender, assets), "transfer");
    }
}
