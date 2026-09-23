# Evaluating a vulnerability hypothesis before reporting it

An anonymised account of one authorized review, September 2026. The target, contract names, addresses, amounts and sequences are deliberately left out; none of them is needed to follow the reasoning.

## Setup

The subject was a set of smart contracts in the scope of a public bug-bounty programme. Before any testing, the programme rules and in-scope assets were saved with a date, the source was pinned to a fixed revision, and the rules for the work were written down: local and pinned-fork execution only, read-only chain queries, no broadcasts, no submission without a separate decision.

## Work

Hypotheses were written as properties that should hold, then traced through the code. Several were reproducible: the behaviour existed and could be triggered in a local or forked environment. That was the easy part.

Each reproducible lead then went through the harder checks:

- **Who can trigger it?** Some paths needed privileges that the programme treats as trusted.
- **What does it cost, and what does it move?** Measured on a fork, the effects that looked serious in source turned out to be much smaller in practice, and in some cases they did not touch user principal at all.
- **Has it been seen before?** Public audits covered related ground.
- **Does it meet the programme's bar?** Severity, eligibility and technical validity were judged separately.

AI-assisted reviews were run independently and frozen before being compared, so one conclusion could not anchor the others. Where they disagreed, the tests decided.

One test run failed because of an error in the test harness itself. It was recorded as a harness failure and corrected; it was not relabelled as a pass.

## Outcome

None of the leads cleared the bar for impact, novelty and eligibility together, so **nothing was submitted**. The leads are kept with their stop reasons and with the conditions that would justify looking again.

No report was filed, and no acknowledgement, award or CVE resulted. The value of the exercise is the method: a plausible hypothesis is where the work starts, and "do not submit" is a legitimate result when the evidence says so.
