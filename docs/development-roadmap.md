# Development Roadmap

This sequence is a **Proposed design** based on confirmed scope and code-verified gaps. It does not claim that any phase is implemented.

## Code-verified starting point

Firebase Core initialization/options, basic authentication abstractions, role constants, route helpers/placeholders, and a starter counter test exist. Concrete authentication, Firestore workflows/rules, dashboards, synthetic DIT data, attendance, geolocation, and QR behavior were not found in the inspected source.

## Mission 05 status

- **Implemented, not yet fully tested:** Node.js 22 TypeScript Functions scaffold and Firebase Admin initialization; module boundaries for authentication, authorization, academics, and attendance; deny-all Firestore rules; Auth/Functions/Firestore emulator configuration with a `demo-smartumc` CLI project alias; and additional local-secret/build-output exclusions in `.gitignore`.
- No authentication or attendance workflow has been implemented. The deny-all rules deliberately block all client Firestore access until reviewed rules are added.
- Local checks could not yet run end-to-end: a Java 11+ runtime for the Firestore/Auth emulators could not be verified (`java` resolves through an Oracle `java8path` launcher), Node.js 24 is installed rather than the configured Node.js 22 runtime, and package installation was not performed.

## Proposed phases

1. **Resolve scope details.** Confirm lecturer web deployment boundary, synthetic semester/course dataset, identity mapping, and location result thresholds. These choices affect data and platform design.
2. **Approve minimal schema and security model.** Define entities, ownership, read/write boundaries, rules, and trusted backend responsibilities before client data flows are built.
3. **Prepare isolated development/test path.** Install/use the approved local Node.js and Java prerequisites, then verify Functions/Auth/Firestore emulators using synthetic data. Do not alter production configuration or deploy without explicit approval.
4. **Implement authentication and role resolution.** Build trusted matric-to-identity flow, staff identity verification, session restoration, and role-aware routing. All subsequent data access depends on trusted identity.
5. **Create limited synthetic DIT data management.** Provision three semesters, courses, offerings, enrollments, and demo users through approved trusted operations. Attendance depends on these records.
6. **Implement lecturer sessions and optional QR.** Add session lifecycle and lecturer control; when enabled, issue protected QR tokens with one-minute refresh/expiry. Student check-in consumes an active session.
7. **Implement student attendance and location verification.** Capture location as mandatory input and validate it through trusted logic. Keep detailed verification separate from the approved green/yellow/red indicators.
8. **Implement lecturer attendance review.** Display the three approved indicators and relevant detailed verification outcomes with appropriate access restrictions.
9. **Verify end-to-end behavior and security.** Test Android and web flows, rules, backend validation, negative cases, QR expiry/replay, and synthetic dataset consistency before any deployment.

## Pending approval

Backend runtime/billing, semester dates and seed dataset, geofence/accuracy thresholds, exact identity mapping, lecturer deployment boundary, and whether password recovery is in scope.
