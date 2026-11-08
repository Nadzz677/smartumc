---
name: systematic-debugging
description: Reproduce and diagnose Flutter, Dart, Firebase, or tooling failures in SmartUMC before applying a focused fix.
---

# Systematic debugging

- First inspect project instructions, the relevant source, dependency declarations/lockfile, and the complete error output or stack trace.
- Reproduce the failure with the narrowest safe command that does not install packages, alter production services, or destroy user data. If reproduction is not possible, state what evidence is available and what is missing.
- Trace the failing call path and identify the root cause before editing. Distinguish the direct cause from secondary symptoms.
- Propose the smallest fix that addresses the cause. Avoid unrelated cleanup, broad rewrites, dependency changes, or architectural changes.
- Explain the cause and why the fix addresses it. Preserve the approved project scope and security boundaries.
- After an approved fix, run the most relevant verification available (targeted test, analyzer, or platform build); do not install/upgrade dependencies or deploy without approval. Report exact checks and results, including checks that could not run.
- Use synthetic data only; do not expose credentials or secrets.
