---
name: firebase-development
description: Design or implement SmartUMC Firebase Authentication, Cloud Firestore, security rules, and trusted backend integrations.
---

# Firebase development

- Inspect `firebase.json`, platform options, dependencies, existing rules/backend code, and project instructions before making changes. Configuration or a package alone does not prove a Firebase feature works.
- Use Firebase Authentication for identity and Cloud Firestore as the primary application database. Never store plaintext, hashed, or encrypted passwords in Firestore.
- Student sign-in must accept matric number and password while mapping to a canonical trusted Firebase identity. Staff authentication and role assignment require trusted identity verification. Never trust a role supplied by the client.
- Enforce least-privilege access in Firestore Security Rules and validate privileged operations in trusted backend code. Client routing and hidden controls are not authorization.
- Keep client data operations separate from trusted operations. Use trusted backend execution for operations whose integrity depends on role assignment, enrollment, attendance validation, session ownership, or QR secrets.
- Design the smallest maintainable Firestore model that satisfies approved requirements. Do not automatically adopt historical schemas or create speculative collections; document each proposed collection's purpose, ownership, access, and lifecycle for approval.
- Protect attendance records against unauthorized reads/writes, forged submissions, duplicates/replayed check-ins, and invalid session state. Keep QR secrets backend-only and enforce server-trusted expiry/rotation.
- Preserve the approved attendance display indicators and store detailed location verification results separately. Do not let a broad Firestore write bypass the approved semantics.
- Use synthetic data only. Do not expose service-account credentials, private keys, or secrets. Client Firebase identifiers are not authorization controls.
- Test rules and trusted operations with appropriate Firebase Emulator tests before deployment. Do not alter production configuration or deploy without explicit project director approval; clearly report unrun tests.
