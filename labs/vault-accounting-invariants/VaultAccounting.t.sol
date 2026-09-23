// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "./ToyToken.sol";
import {LedgerVaultBuggy} from "./LedgerVaultBuggy.sol";
import {LedgerVaultFixed} from "./LedgerVaultFixed.sol";

contract VaultActor {
    ToyToken internal immutable token;

    constructor(ToyToken fakeToken) {
        token = fakeToken;
    }

    function depositBuggy(LedgerVaultBuggy vault, uint256 amount) external {
        token.approve(address(vault), amount);
        vault.deposit(amount);
    }

    function withdrawBuggy(LedgerVaultBuggy vault, uint256 amount) external {
        vault.withdraw(amount);
    }

    function depositFixed(LedgerVaultFixed vault, uint256 amount) external {
        token.approve(address(vault), amount);
        vault.deposit(amount);
    }

    function withdrawFixed(LedgerVaultFixed vault, uint256 amount) external {
        vault.withdraw(amount);
    }
}

contract VaultAccountingTest {
    function test_buggyRepeatWithdrawalConsumesAnotherDepositorsAssets() public {
        ToyToken token = new ToyToken();
        LedgerVaultBuggy vault = new LedgerVaultBuggy(token);
        VaultActor alice = new VaultActor(token);
        VaultActor bob = new VaultActor(token);
        token.mint(address(alice), 10);
        token.mint(address(bob), 10);
        alice.depositBuggy(vault, 10);
        bob.depositBuggy(vault, 10);

        alice.withdrawBuggy(vault, 10);
        require(vault.creditOf(address(alice)) == 10, "bug not demonstrated");
        alice.withdrawBuggy(vault, 10);
        require(token.balanceOf(address(vault)) == 0, "pool not drained");
        (bool bobCanWithdraw,) = address(bob).call(abi.encodeCall(VaultActor.withdrawBuggy, (vault, 10)));
        require(!bobCanWithdraw, "negative control failed");
    }

    function test_fixedBlocksRepeatWithdrawalAndPreservesBob() public {
        ToyToken token = new ToyToken();
        LedgerVaultFixed vault = new LedgerVaultFixed(token);
        VaultActor alice = new VaultActor(token);
        VaultActor bob = new VaultActor(token);
        token.mint(address(alice), 10);
        token.mint(address(bob), 10);
        alice.depositFixed(vault, 10);
        bob.depositFixed(vault, 10);

        alice.withdrawFixed(vault, 10);
        (bool repeated,) = address(alice).call(abi.encodeCall(VaultActor.withdrawFixed, (vault, 10)));
        require(!repeated, "repeat should fail");
        bob.withdrawFixed(vault, 10);
        require(token.balanceOf(address(bob)) == 10, "Bob lost fake tokens");
        require(vault.totalCredits() == 0, "aggregate not cleared");
    }

    function testFuzz_fixedLedgerTracksUserCredits(uint96 rawAlice, uint96 rawBob) public {
        uint256 aliceAmount = uint256(rawAlice) % 1e24 + 1;
        uint256 bobAmount = uint256(rawBob) % 1e24 + 1;
        ToyToken token = new ToyToken();
        LedgerVaultFixed vault = new LedgerVaultFixed(token);
        VaultActor alice = new VaultActor(token);
        VaultActor bob = new VaultActor(token);
        token.mint(address(alice), aliceAmount);
        token.mint(address(bob), bobAmount);
        alice.depositFixed(vault, aliceAmount);
        bob.depositFixed(vault, bobAmount);
        uint256 withdrawal = aliceAmount / 2;
        if (withdrawal != 0) alice.withdrawFixed(vault, withdrawal);
        uint256 sum = vault.creditOf(address(alice)) + vault.creditOf(address(bob));
        require(sum == vault.totalCredits(), "credit sum mismatch");
        require(token.balanceOf(address(vault)) == sum, "asset mismatch");
    }
}

contract VaultSequenceHandler {
    ToyToken public immutable token;
    LedgerVaultFixed public immutable vault;
    VaultActor public immutable alice;
    VaultActor public immutable bob;

    constructor() {
        token = new ToyToken();
        vault = new LedgerVaultFixed(token);
        alice = new VaultActor(token);
        bob = new VaultActor(token);
        token.mint(address(alice), 1e25);
        token.mint(address(bob), 1e25);
    }

    function deposit(uint256 selector, uint96 rawAmount) external {
        VaultActor actor = selector % 2 == 0 ? alice : bob;
        uint256 available = token.balanceOf(address(actor));
        if (available == 0) return;
        uint256 amount = uint256(rawAmount) % available + 1;
        actor.depositFixed(vault, amount);
    }

    function withdraw(uint256 selector, uint96 rawAmount) external {
        VaultActor actor = selector % 2 == 0 ? alice : bob;
        uint256 credit = vault.creditOf(address(actor));
        if (credit == 0) return;
        uint256 amount = uint256(rawAmount) % credit + 1;
        actor.withdrawFixed(vault, amount);
    }
}

contract VaultAccountingInvariantTest {
    // Forge discovers these view methods when configuring invariant targets.
    struct SelectorGroup {
        address addr;
        bytes4[] selectors;
    }

    struct ArtifactSelectorGroup {
        string artifact;
        bytes4[] selectors;
    }

    struct InterfaceGroup {
        address addr;
        string[] artifacts;
    }

    VaultSequenceHandler internal handler;

    function setUp() public {
        handler = new VaultSequenceHandler();
    }

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function excludeContracts() public pure returns (address[] memory) {
        return new address[](0);
    }

    function targetSenders() public pure returns (address[] memory) {
        return new address[](0);
    }

    function excludeSenders() public pure returns (address[] memory) {
        return new address[](0);
    }

    function targetArtifacts() public pure returns (string[] memory) {
        return new string[](0);
    }

    function excludeArtifacts() public pure returns (string[] memory) {
        return new string[](0);
    }

    function targetSelectors() public pure returns (SelectorGroup[] memory) {
        return new SelectorGroup[](0);
    }

    function excludeSelectors() public pure returns (SelectorGroup[] memory) {
        return new SelectorGroup[](0);
    }

    function targetArtifactSelectors() public pure returns (ArtifactSelectorGroup[] memory) {
        return new ArtifactSelectorGroup[](0);
    }

    function targetInterfaces() public pure returns (InterfaceGroup[] memory) {
        return new InterfaceGroup[](0);
    }

    function invariant_fixedCreditsEqualAssets() public view {
        LedgerVaultFixed vault = handler.vault();
        ToyToken token = handler.token();
        uint256 sum = vault.creditOf(address(handler.alice())) + vault.creditOf(address(handler.bob()));
        require(sum == vault.totalCredits(), "credit sum mismatch");
        require(token.balanceOf(address(vault)) == sum, "asset mismatch");
    }
}
