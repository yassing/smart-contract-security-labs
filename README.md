# Smart-contract security labs

Original, intentionally vulnerable Solidity examples by [Vonkwerk AI](https://vonkwerkai.nl/research/labs/). Each lab has a broken contract, a corrected contract and Foundry tests that reproduce the bug, bound its impact and verify the fix.

These are educational labs. They are not production code, they are written from scratch rather than taken from any real protocol, and they do not describe a vulnerability in a live system.

| Lab | What it shows | Tests |
|---|---|---|
| [Vault accounting invariants](labs/vault-accounting-invariants/README.md) | A missing per-user state update. Unit proof, fuzz test, and an invariant campaign that finds the bug without being told what it is. | 2 unit, 1 fuzz, 1 invariant, plus 1 expected-failure invariant |
| [Share inflation](labs/share-inflation/README.md) | First-depositor donation attack on a share vault: full theft, partial theft, a front-running slippage check, and why the fix makes the attack unprofitable rather than impossible. | 5 unit, 1 fuzz |

## Run it

Requirements: [Foundry](https://book.getfoundry.sh/) 1.8.3 (`foundryup --install v1.8.3`). Solidity 0.8.24 is fetched by Foundry. There are no other dependencies, no RPC endpoints and no network access in the tests.

```sh
forge fmt --check
forge test -vv
```

Expected: `10 tests passed, 0 failed, 0 skipped`.

To watch the invariant campaign find the vault bug on its own:

```sh
FOUNDRY_PROFILE=find-bug forge test
```

Expected: one failing invariant (`credit sum mismatch`) with a shrunk call sequence. This run is meant to fail; CI checks that it does.

## Also in this repository

- [Research methodology](RESEARCH_METHODOLOGY.md): the workflow these labs illustrate.
- [Case study](case-studies/01_EVALUATING_A_HYPOTHESIS.md): how a real, authorized review ended in a decision not to submit. Anonymised; no target details.
- [Ethics and authorization](ETHICS_AND_AUTHORIZATION.md) and [responsible disclosure](RESPONSIBLE_DISCLOSURE.md).
- `tools/publication_check.py`: the offline scan run before every publication of this repository.

## Limits

The labs use a freely mintable toy token in a local test VM. Passing tests show that these toy contracts behave as described under the tested conditions; they are not a security review of anything else. No bounty result, report acceptance or third-party endorsement is claimed.

## License

MIT. See [LICENSE](LICENSE).
