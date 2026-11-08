---
name: testing-qa
description: Plan, write, or review SmartUMC unit, widget, integration, Firebase rules, and end-to-end tests.
---

# Testing and QA

- Inspect current tests, architecture, test dependencies, and project instructions before adding tests. Do not assume test infrastructure exists just because a test directory exists.
- Choose test level based on behavior: unit tests for domain rules, widget tests for UI interactions, integration tests for cross-layer flows, and emulator tests for Firebase Auth/Firestore rules and trusted operations.
- Cover authentication and trusted role routing, including invalid credentials, inactive/mismatched roles, and unauthorized access where applicable.
- For attendance, test the approved green/yellow/red display definitions separately from detailed location verification results. Include permission denial, location not opened, traced location, no scan/session closure, duplicates, and session boundaries when implemented.
- For optional dynamic QR, test disabled mode, lecturer control, one-minute refresh/expiry, stale tokens, replay, and server validation as appropriate.
- Include negative, boundary, and regression cases. Use synthetic DIT demonstration data only; never use real student records.
- Keep tests deterministic and avoid external production services. Do not install packages or change Firebase configuration without approval.
- Report the exact tests run, outcomes, and anything that could not be executed with the reason. Do not claim unrun tests passed.
