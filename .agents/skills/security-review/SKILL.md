---
name: security-review
description: Review SmartUMC authentication, authorization, Firebase rules, attendance integrity, QR protection, and location verification risks.
---

# Security review

- Review relevant source, Firebase rules/configuration, trusted backend code, and project instructions. Separate verified vulnerabilities from missing controls and design concerns.
- Trace identity, authentication, role resolution, authorization, and data-write boundaries. Check that clients cannot assign roles or bypass checks through direct Firestore writes.
- Examine Firestore Security Rules for least privilege, field validation, ownership/enrollment scoping, and safe defaults. Rules must not be treated as query filters or replaced by UI restrictions.
- Check for exposed credentials/secrets, password data in Firestore, excessive personal data, and use of non-synthetic records.
- Review attendance manipulation risks: client-forged submissions, duplicates, enrollment/session checks, trusted timestamps, QR replay/expiry, and backend-only QR secrets.
- Evaluate location verification limitations, permission denial, missing/poor accuracy, and whether detailed results remain separate from the approved green/yellow/red display indicators.
- Classify findings by severity (Critical/High/Medium/Low/Informational), cite affected files or flows, explain impact, and recommend a concrete remediation. Clearly mark unverified assumptions.
- Do not change production Firebase configuration or deploy services during a review. Use synthetic data only.
