// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ToyToken} from "./ToyToken.sol";
import {LedgerVaultBuggy} from "./LedgerVaultBuggy.sol";

/// @notice Same random deposit/withdraw sequences as VaultSequenceHandler, but against
/// the deliberately broken vault. Nothing here encodes the bug or its trace.
contract BuggyVaultSequenceHandler {
    ToyToken public immutable token;
    LedgerVaultBuggy public immutable vault;
    address public immutable alice;
    address public immutable bob;

    constructor() {
        token = new ToyToken();
        vault = new LedgerVaultBuggy(token);
        alice = address(new BuggyVaultActor(token));
        bob = address(new BuggyVaultActor(token));
        token.mint(alice, 1e25);
        token.mint(bob, 1e25);
    }

    function deposit(uint256 selector, uint96 rawAmount) external {
        BuggyVaultActor actor = BuggyVaultActor(selector % 2 == 0 ? alice : bob);
        uint256 available = token.balanceOf(address(actor));
        if (available == 0) return;
        actor.deposit(vault, uint256(rawAmount) % available + 1);
    }

    function withdraw(uint256 selector, uint96 rawAmount) external {
        BuggyVaultActor actor = BuggyVaultActor(selector % 2 == 0 ? alice : bob);
        uint256 credit = vault.creditOf(address(actor));
        if (credit == 0) return;
        actor.withdraw(vault, uint256(rawAmount) % credit + 1);
    }
}

contract BuggyVaultActor {
    ToyToken internal immutable token;

    constructor(ToyToken fakeToken) {
        token = fakeToken;
    }

    function deposit(LedgerVaultBuggy vault, uint256 amount) external {
        token.approve(address(vault), amount);
        vault.deposit(amount);
    }

    function withdraw(LedgerVaultBuggy vault, uint256 amount) external {
        vault.withdraw(amount);
    }
}

/// @notice EXPECTED TO FAIL. Run with `FOUNDRY_PROFILE=find-bug forge test`.
/// The default profile excludes this contract so the normal suite stays green.
/// The point: the accounting invariant alone is enough for the fuzzer to find the bug
/// and print a shrunk call sequence; no one has to know the exploit in advance.
contract VaultAccountingBuggyInvariant {
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

    BuggyVaultSequenceHandler internal handler;

    function setUp() public {
        handler = new BuggyVaultSequenceHandler();
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

    function invariant_buggyCreditsEqualAssets() public view {
        LedgerVaultBuggy vault = handler.vault();
        uint256 sum = vault.creditOf(handler.alice()) + vault.creditOf(handler.bob());
        require(sum == vault.totalCredits(), "credit sum mismatch");
        require(handler.token().balanceOf(address(vault)) == sum, "asset mismatch");
    }
}
