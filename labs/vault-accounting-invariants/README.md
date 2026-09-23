# Vault accounting invariants — original educational lab

> Intentionally vulnerable educational code, written from scratch for teaching. It is not production code and does not reproduce any real protocol's code.

`LedgerVaultBuggy` lowers the vault's total credit on withdrawal but forgets to lower the caller's own credit. The caller can withdraw again and again while the vault still holds tokens, until another depositor can no longer redeem. The root cause is a single missing state transition.

`LedgerVaultFixed` updates the caller's credit and the total before transferring.

## What the tests establish

| Test | Result it pins down |
|---|---|
| `test_buggyRepeatWithdrawalConsumesAnotherDepositorsAssets` | Alice withdraws twice, the vault is empty, and Bob's withdrawal fails. |
| `test_fixedBlocksRepeatWithdrawalAndPreservesBob` | The repeat withdrawal reverts and Bob withdraws in full. |
| `testFuzz_fixedLedgerTracksUserCredits` | For 256 random deposit sizes, user credits sum to the total and to the vault's balance. |
| `invariant_fixedCreditsEqualAssets` | For 128 random sequences of deposits and withdrawals (8,192 calls), the same two equalities hold after every call. |
| `invariant_buggyCreditsEqualAssets` (find-bug profile) | The same invariant against the buggy vault. The fuzzer breaks it and shrinks the failing run to a short call sequence, typically a deposit followed by a withdrawal. |

The last row is the point of the lab. The handler only makes random deposits and withdrawals, and the invariant only states the accounting rule. Neither encodes the bug, yet the fuzzer finds a counterexample within a few calls. That is the value of stating properties instead of scripting attacks: the tool searches for the sequence. (Here the property is the textbook one and the bug is simple; in real reviews the hard part is choosing the right properties.)

## Run

From the repository root:

```sh
forge test --match-path 'labs/vault-accounting-invariants/*' -vv
FOUNDRY_PROFILE=find-bug forge test   # expected to fail
```

Limits: two actors, a freely mintable toy token, a local VM. No external asset, fork or RPC.
