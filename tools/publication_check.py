#!/usr/bin/env python3
"""Fail-closed text scan for a staged public repository. No network access."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


RULES = {
    "ethereum_address": r"\b0x[a-fA-F0-9]{40}\b",
    "commit_hash": r"\b[a-fA-F0-9]{40}\b",
    "run_identifier": r"\b[0-9]{10,12}\b",
    "cve_claim": r"\bCVE-[0-9]{4}-[0-9]{4,}\b",
    "status_language": r"\b(?:critical|high severity|zero.day|accepted|paid|bounty winner|partner|unrestricted|unfiltered)\b",
    "email_address": r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b",
    "private_branch": r"\b(?:security|portfolio|review)/[a-z0-9._/-]+\b",
    "explicit_git_ref": r"\b(?:refs/(?:heads|tags)/|origin/)[a-z0-9._/-]+\b",
    "short_commit_reference": r"\b(?:commit|sha|head|revision)\s*[:=#]?\s*[a-f0-9]{7,39}\b",
    "report_filename": r"\b[A-Z]{2,}(?:-[A-Z0-9]+){2,}\.md\b",
    "credential_assignment": r"\b(?:api[_-]?key|access[_-]?token|private[_-]?key|mnemonic|secret)\s*[:=]\s*['\"]?[A-Za-z0-9_+/=-]{16,}",
    "credential_url": r"https?://[^\s/@]+:[^\s/@]+@[^\s]+|https?://[^\s]+(?:api[_-]?key|access[_-]?token)=[^\s&]+",
    "personal_document": r"\b(?:date of birth|birth date|passport number|national id number|driver.?s license number)\b",
    "phone_number": r"(?<!\w)(?:\+[0-9]{1,3}[ .-]?)?(?:\([0-9]{2,4}\)[ .-]?)?[0-9]{3}[ .-]?[0-9]{3}[ .-]?[0-9]{4}(?!\w)",
    "postal_address": r"\b(?:[0-9]{1,5}\s+[A-Za-z][A-Za-z .'-]{2,50}\s+(?:Street|Road|Avenue|Lane|Boulevard|Drive|Straat|Laan|Weg|Plein)|[A-Za-z][A-Za-z .'-]{2,50}\s+(?:Street|Road|Avenue|Lane|Boulevard|Drive|Straat|Laan|Weg|Plein)\s+[0-9]{1,5}[A-Za-z]?)\b",
}
COMPILED = {name: re.compile(expr, re.IGNORECASE) for name, expr in RULES.items()}
RULE_SOURCE_FILES = {"tools/publication_check.py", ".publication-allowlist.json"}
RULE_SOURCE_EXEMPTIONS = {"commit_hash", "run_identifier", "status_language", "personal_document"}
SKIP_DIRS = {".git", "out", "cache", "broadcast", "__pycache__"}
SENSITIVE_RULES = {
    "ethereum_address", "commit_hash", "email_address", "private_branch",
    "report_filename", "credential_assignment", "credential_url", "personal_document",
    "phone_number", "postal_address", "private_literal", "run_identifier",
    "explicit_git_ref", "short_commit_reference",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--terms", type=Path, help="Private literal terms, one per line")
    parser.add_argument("--report", type=Path, help="Human-readable local report path")
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    allow_path = root / ".publication-allowlist.json"
    allowlist = json.loads(allow_path.read_text(encoding="utf-8")) if allow_path.exists() else []
    for entry in allowlist:
        if not all(entry.get(k) for k in ("path", "pattern", "match", "line", "rationale")):
            raise ValueError("Every allowlist entry needs path, pattern, match, line and rationale")
        if len(entry["rationale"]) < 25:
            raise ValueError("Allowlist rationale is too short")
    terms = []
    if args.terms:
        terms = [line.strip() for line in args.terms.read_text(encoding="utf-8").splitlines()
                 if line.strip() and not line.lstrip().startswith("#")]

    findings: list[str] = []
    allowed: list[str] = []
    scanned = 0
    for path in sorted(root.rglob("*")):
        if any(part in SKIP_DIRS for part in path.relative_to(root).parts):
            continue
        rel = path.relative_to(root).as_posix()
        if path.is_symlink():
            findings.append(f"{rel}: symlink is not allowed in staged public material")
            continue
        if not path.is_file():
            continue
        if path.stat().st_size > 2_000_000:
            findings.append(f"{rel}: oversized file requires manual review")
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeError:
            findings.append(f"{rel}: non-UTF-8/binary file requires manual review")
            continue
        scanned += 1
        for number, line in enumerate(lines, 1):
            active_rules = {name: regex for name, regex in COMPILED.items()
                            if rel not in RULE_SOURCE_FILES or name not in RULE_SOURCE_EXEMPTIONS}
            hits = [(name, match.group(0)) for name, regex in active_rules.items()
                    for match in regex.finditer(line)]
            hits.extend(("private_literal", term) for term in terms if term.casefold() in line.casefold())
            for name, match in hits:
                exception = next((entry for entry in allowlist
                                  if entry["path"] == rel and entry["pattern"] == name
                                  and entry["match"].casefold() == match.casefold()
                                  and entry["line"] == line), None)
                description = f"{rel}:{number}: {name}: "
                description += "<redacted>" if name in SENSITIVE_RULES else repr(match)
                if exception:
                    allowed.append(description + f" — allowed: {exception['rationale']}")
                else:
                    findings.append(description)
    report = [f"Publication scan: {'FAIL' if findings else 'PASS'}", f"Root: {root}",
              f"Text files scanned: {scanned}",
              f"Rule literals: {len(terms)}; allowlisted hits: {len(allowed)}; unresolved hits: {len(findings)}",
              "Scanner and allowlist configuration were scanned for sensitive leaks; generic hashes, run IDs, status words and personal-document keywords were exempt there because they are rule literals. Exact-line allowlist data remains subject to the branch and Git-ref rules.",
              "Generated build folders were excluded; release review must ensure they are not committed."]
    report += ["", "Allowlisted hits:", *(allowed or ["none"]), "", "Unresolved hits:", *(findings or ["none"])]
    output = "\n".join(report) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding="utf-8")
    print(output, end="")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
