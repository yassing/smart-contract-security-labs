# Share inflation — original educational lab

> Intentionally vulnerable educational code, written from scratch for teaching. It is not production code and does not reproduce any real protocol's code.

A share vault issues shares for deposits and prices them from its own token balance. That makes two things possible: anyone can move the share price by transferring tokens straight to the vault (a donation), and a deposit can round down to zero shares. Together they allow the well-known first-depositor attack.

`ShareVaultBuggy` has both problems. `ShareVaultFixed` adds two independent defences: virtual shares and a virtual asset in the price formula, and a caller-supplied minimum share amount with zero-share deposits rejected.

## What the tests establish

The attack needs two preconditions: the attacker is the vault's first depositor, and the attacker's donation lands before the victim's deposit (front-running, or simply depositing into a fresh vault first).

| Test | Result it pins down |
|---|---|
| `test_buggyFullTheftWhenDonationCoversDeposit` | Attacker deposits 1 wei, donates 1,000 tokens; the victim's 1,000-token deposit mints zero shares and the attacker redeems all of it. |
| `test_buggyPartialTheftBelowFullCapital` | A 99-token donation against a 150-token deposit leaves the victim one share, and about 25.5 tokens (17%) still move from victim to attacker. Value is conserved exactly. |
| `test_fixedSameAttackLosesMoney` | The same sequence against the fixed vault costs the attacker about half the donation; the victim's rounding loss stays below 0.001%. |
| `test_fixedRejectsZeroShareDeposit` | A deposit that would mint zero shares reverts, whatever minimum the caller passes. |
| `test_fixedSlippageGuardStopsFrontRunDeposit` | The victim quotes shares first and accepts at most 1% less; the front-running donation makes the deposit revert instead of filling at a worse price. |
| `testFuzz_fixedDonationAttackNeverProfitable` | For 256 random attacker seed deposits, donations of up to four times the deposit, and deposit sizes: the attacker never profits, and the victim never loses more than the attacker spends. |

## Why this lab exists

It shows the part of the work that decides whether a report is worth sending: impact bounding. Against the buggy vault, full theft needs a donation at least as large as the victim's deposit, but smaller donations still take a share of it, so the impact is a range rather than a yes/no. The fix works by making the attack cost more than it takes, and by letting the depositor refuse a worse price; it does not make the arithmetic exact. Those statements are what the tests pin down.

## Run

From the repository root: `forge test --match-contract ShareInflationTest -vv`.

Prior art: this is a well-documented class. The virtual-shares defence follows the approach OpenZeppelin describes for ERC-4626 vaults (a decimals offset with virtual shares and assets); this lab is a simplified teaching version, not a replacement for it.

Limits: toy token, local VM, one attacker and one victim, no fees, no reentrancy. The fuzz test covers donations up to four times the deposit; larger donations are covered by the zero-share test. Real vault designs differ.
