# Research methodology

A working method for authorized smart-contract and software security research. It describes how a question becomes a finding, or, more often, does not.

1. **Confirm authorization and scope.** Record the programme rules, assets in scope, exclusions and permitted test methods, with a date. Public source code is not permission to test a live deployment.
2. **Freeze the subject.** Pin the source revision, compiler, dependencies and deployment assumptions so every result can be reproduced.
3. **Model the system.** Write down assets, actors, authority boundaries and the properties that should always hold.
4. **State hypotheses.** Each one is a concrete, falsifiable question about a path through the code. A code smell is not a finding.
5. **Reproduce locally.** Build the smallest witness that shows the behaviour, with explicit expected state changes. Use a pinned fork only where the rules allow it. Never broadcast a transaction.
6. **Try to disprove it.** Test alternative explanations, legitimate controls, revert paths and changed assumptions. Keep the hypotheses that fail, with the reason.
7. **Bound the impact.** Separate "reachable" from "harmful": who can trigger it, what it costs them, how much value is affected, for how long, and what mitigations exist.
8. **Check prior art.** Compare root cause, deployment and impact with public audits and reports. A different title is not novelty.
9. **Verify the fix.** Describe a bounded remediation and show that the original witness fails while expected behaviour still passes.
10. **Decide on disclosure.** Report through the programme's channel only when scope, impact, novelty and eligibility are supported. A documented decision not to submit is a valid outcome.

AI tools assist with reading code, drafting tests and challenging conclusions. Their output is treated as a hypothesis and checked against source and tests; no classification is decided by a model.
