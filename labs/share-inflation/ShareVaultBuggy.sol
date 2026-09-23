// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "../vault-accounting-invariants/ToyToken.sol";

/// @notice Deliberately broken toy share vault.
/// Share price is read from the live token balance, so a direct token transfer
/// (a "donation") moves the price, and deposits may round down to zero shares.
contract ShareVaultBuggy {
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
        uint256 supply = totalSupply;
        return supply == 0 ? assets : assets * supply / totalAssets();
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        require(assets != 0, "zero");
        // BUG: no lower bound on shares; a deposit that mints zero shares still succeeds.
        shares = previewDeposit(assets);
        require(asset.transferFrom(msg.sender, address(this), assets), "transfer");
        balanceOf[msg.sender] += shares;
        totalSupply += shares;
    }

    function redeem(uint256 shares) external returns (uint256 assets) {
        require(shares != 0 && balanceOf[msg.sender] >= shares, "shares");
        assets = shares * totalAssets() / totalSupply;
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        require(asset.transfer(msg.sender, assets), "transfer");
    }
}
