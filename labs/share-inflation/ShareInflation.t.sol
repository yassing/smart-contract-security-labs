// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "../vault-accounting-invariants/ToyToken.sol";
import {ShareVaultBuggy} from "./ShareVaultBuggy.sol";
import {ShareVaultFixed} from "./ShareVaultFixed.sol";

contract ShareActor {
    ToyToken internal immutable token;

    constructor(ToyToken fakeToken) {
        token = fakeToken;
    }

    function depositBuggy(ShareVaultBuggy vault, uint256 assets) external returns (uint256) {
        token.approve(address(vault), assets);
        return vault.deposit(assets);
    }

    function depositFixed(ShareVaultFixed vault, uint256 assets, uint256 minShares) external returns (uint256) {
        token.approve(address(vault), assets);
        return vault.deposit(assets, minShares);
    }

    function donate(address vault, uint256 assets) external {
        require(token.transfer(vault, assets), "donate");
    }

    function redeemAllBuggy(ShareVaultBuggy vault) external returns (uint256) {
        return vault.redeem(vault.balanceOf(address(this)));
    }

    function redeemAllFixed(ShareVaultFixed vault) external returns (uint256) {
        return vault.redeem(vault.balanceOf(address(this)));
    }
}

/// @notice First-depositor donation attack: reproduce, bound the impact, verify the fix.
contract ShareInflationTest {
    ToyToken internal token;
    ShareActor internal attacker;
    ShareActor internal victim;

    function setUp() public {
        token = new ToyToken();
        attacker = new ShareActor(token);
        victim = new ShareActor(token);
    }

    // Full theft: the donation is at least as large as the victim's deposit,
    // so the victim's shares round down to zero and the attacker redeems everything.
    function test_buggyFullTheftWhenDonationCoversDeposit() public {
        ShareVaultBuggy vault = new ShareVaultBuggy(token);
        uint256 donation = 1000 ether;
        uint256 deposit = 1000 ether;
        token.mint(address(attacker), 1 + donation);
        token.mint(address(victim), deposit);

        attacker.depositBuggy(vault, 1);
        attacker.donate(address(vault), donation);
        uint256 victimShares = victim.depositBuggy(vault, deposit);
        attacker.redeemAllBuggy(vault);

        require(victimShares == 0, "victim should receive zero shares");
        require(token.balanceOf(address(attacker)) == 1 + donation + deposit, "attacker should take the deposit");
        require(token.balanceOf(address(vault)) == 0, "vault should be empty");
    }

    // Impact is a range, not a yes/no: with a smaller donation the victim keeps one share,
    // and the attacker still takes a fixed fraction of the deposit.
    function test_buggyPartialTheftBelowFullCapital() public {
        ShareVaultBuggy vault = new ShareVaultBuggy(token);
        uint256 donation = 99 ether;
        uint256 deposit = 150 ether;
        token.mint(address(attacker), 1 + donation);
        token.mint(address(victim), deposit);

        attacker.depositBuggy(vault, 1);
        attacker.donate(address(vault), donation);
        uint256 victimShares = victim.depositBuggy(vault, deposit);
        uint256 attackerOut = attacker.redeemAllBuggy(vault);
        uint256 victimOut = victim.redeemAllBuggy(vault);

        require(victimShares == 1, "victim should receive one share");
        uint256 attackerProfit = attackerOut - (1 + donation);
        uint256 victimLoss = deposit - victimOut;
        require(attackerProfit > 25 ether && attackerProfit < 26 ether, "unexpected profit band");
        // Conservation: what the victim loses is exactly what the attacker gains.
        require(attackerProfit == victimLoss, "value not conserved");
    }

    // Same sequence against the fixed vault: the attacker loses about half the donation,
    // and the victim's rounding loss is negligible.
    function test_fixedSameAttackLosesMoney() public {
        ShareVaultFixed vault = new ShareVaultFixed(token);
        uint256 donation = 1000 ether;
        uint256 deposit = 1000 ether;
        token.mint(address(attacker), 1 + donation);
        token.mint(address(victim), deposit);

        attacker.depositFixed(vault, 1, 1);
        attacker.donate(address(vault), donation);
        uint256 victimShares = victim.depositFixed(vault, deposit, 1);
        uint256 attackerOut = attacker.redeemAllFixed(vault);
        uint256 victimOut = victim.redeemAllFixed(vault);

        require(victimShares > 0, "victim should receive shares");
        require(attackerOut < 1 + donation, "attack must not be profitable");
        uint256 attackerLoss = 1 + donation - attackerOut;
        uint256 victimLoss = deposit > victimOut ? deposit - victimOut : 0;
        require(attackerLoss > 499 ether, "attacker should lose about half the donation");
        require(victimLoss < deposit / 1e5, "victim loss should be below 0.001%");
    }

    // A deposit that would mint zero shares always reverts, whatever minimum the caller passes.
    function test_fixedRejectsZeroShareDeposit() public {
        ShareVaultFixed vault = new ShareVaultFixed(token);
        token.mint(address(attacker), 1 + 1000 ether);
        token.mint(address(victim), 1);

        attacker.depositFixed(vault, 1, 1);
        attacker.donate(address(vault), 1000 ether);
        (bool ok,) = address(victim).call(abi.encodeCall(ShareActor.depositFixed, (vault, 1, 0)));
        require(!ok, "zero-share deposit must revert");
        require(token.balanceOf(address(victim)) == 1, "victim keeps the asset");
    }

    // The realistic use of the guard: the victim quotes shares before sending, the attacker
    // front-runs with a donation, and the deposit reverts instead of filling at a worse price.
    function test_fixedSlippageGuardStopsFrontRunDeposit() public {
        ShareVaultFixed vault = new ShareVaultFixed(token);
        uint256 deposit = 1000 ether;
        token.mint(address(attacker), 1 + 1000 ether);
        token.mint(address(victim), deposit);

        attacker.depositFixed(vault, 1, 1);
        uint256 quoted = vault.previewDeposit(deposit);
        uint256 minShares = quoted - quoted / 100; // accept up to 1% worse
        attacker.donate(address(vault), 1000 ether);
        (bool ok,) = address(victim).call(abi.encodeCall(ShareActor.depositFixed, (vault, deposit, minShares)));
        require(!ok, "front-run deposit must revert");
        require(token.balanceOf(address(victim)) == deposit, "victim keeps the deposit");
    }

    // Across attacker seed deposits, donations of up to four times the victim's deposit and
    // deposit sizes: the attacker never profits, and the victim never loses more than the
    // attacker spends. Much larger donations can round the victim's deposit to zero shares;
    // that case is covered by test_fixedRejectsZeroShareDeposit, not by this fuzz range.
    function testFuzz_fixedDonationAttackNeverProfitable(uint96 rawSeed, uint96 rawDonation, uint96 rawDeposit) public {
        ShareVaultFixed vault = new ShareVaultFixed(token);
        uint256 seed = uint256(rawSeed) % 1e18 + 1;
        uint256 deposit = uint256(rawDeposit) % 1e24 + 1;
        uint256 donation = uint256(rawDonation) % (4 * deposit + 1);
        token.mint(address(attacker), seed + donation);
        token.mint(address(victim), deposit);

        attacker.depositFixed(vault, seed, 1);
        if (donation != 0) attacker.donate(address(vault), donation);
        (bool victimDeposited,) = address(victim).call(abi.encodeCall(ShareActor.depositFixed, (vault, deposit, 1)));
        attacker.redeemAllFixed(vault);

        uint256 attackerOut = token.balanceOf(address(attacker));
        require(attackerOut <= seed + donation, "attack was profitable");
        if (victimDeposited) {
            uint256 victimOut = victim.redeemAllFixed(vault);
            uint256 victimLoss = deposit > victimOut ? deposit - victimOut : 0;
            uint256 attackerLoss = seed + donation - attackerOut;
            // One wei of slack for independent rounding in the two redemptions.
            require(victimLoss <= attackerLoss + 1, "victim lost more than the attack cost");
        }
    }
}
